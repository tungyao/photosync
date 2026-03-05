import 'dart:async';

import 'package:drift/drift.dart';

import '../../data/db/app_database.dart';
import '../../data/models/backup_job.dart';
import '../../data/models/media_asset.dart';
import '../../data/models/smb_config.dart';
import '../../platform/channels/media_channel.dart';
import '../../platform/channels/smb_channel.dart';

class BackupProgress {
  const BackupProgress({
    required this.total,
    required this.done,
    required this.failed,
    required this.skipped,
    required this.currentAssetId,
  });

  final int total;
  final int done;
  final int failed;
  final int skipped;
  final String? currentAssetId;

  BackupProgress copyWith({
    int? total,
    int? done,
    int? failed,
    int? skipped,
    String? currentAssetId,
    bool clearCurrentAssetId = false,
  }) {
    return BackupProgress(
      total: total ?? this.total,
      done: done ?? this.done,
      failed: failed ?? this.failed,
      skipped: skipped ?? this.skipped,
      currentAssetId:
          clearCurrentAssetId ? null : (currentAssetId ?? this.currentAssetId),
    );
  }
}

class BackupEngine {
  BackupEngine({
    required MediaChannel mediaChannel,
    required SmbChannel smbChannel,
    required BackupDao backupDao,
    required SmbConfig smbConfig,
    int pageSize = 200,
    int chunkSize = 256 * 1024,
  })  : _mediaChannel = mediaChannel,
        _smbChannel = smbChannel,
        _backupDao = backupDao,
        _smbConfig = smbConfig,
        _pageSize = pageSize,
        _chunkSize = chunkSize;

  final MediaChannel _mediaChannel;
  final SmbChannel _smbChannel;
  final BackupDao _backupDao;
  final SmbConfig _smbConfig;
  final int _pageSize;
  final int _chunkSize;

  final StreamController<BackupProgress> _progressController =
      StreamController<BackupProgress>.broadcast();

  BackupProgress _progress = const BackupProgress(
    total: 0,
    done: 0,
    failed: 0,
    skipped: 0,
    currentAssetId: null,
  );

  bool _cancelled = false;
  bool _running = false;
  Completer<void>? _pauseCompleter;

  Stream<BackupProgress> get progressStream => _progressController.stream;

  Future<void> start(BackupJob job) async {
    if (_running) {
      throw StateError('BackupEngine is already running');
    }
    _running = true;
    _cancelled = false;
    _progress = const BackupProgress(
      total: 0,
      done: 0,
      failed: 0,
      skipped: 0,
      currentAssetId: null,
    );
    _emitProgress();

    try {
      final assets = await _scanAssets(job);
      final queue = await _buildUploadQueue(assets, job);
      if (_cancelled) return;

      await _runConcurrentUpload(queue, job);
      _progress = _progress.copyWith(clearCurrentAssetId: true);
      _emitProgress();
    } finally {
      _running = false;
    }
  }

  void pause() {
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      return;
    }
    _pauseCompleter = Completer<void>();
  }

  void resume() {
    final completer = _pauseCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _pauseCompleter = null;
  }

  void cancel() {
    _cancelled = true;
    resume();
  }

  Future<void> dispose() async {
    cancel();
    await _progressController.close();
  }

  Future<List<MediaAsset>> _scanAssets(BackupJob job) async {
    final granted = await _mediaChannel.requestPermission();
    if (!granted) {
      throw StateError('Media permission denied');
    }

    final all = <MediaAsset>[];
    String? cursor;
    var hasMore = true;

    while (hasMore && !_cancelled) {
      await _waitIfPaused();

      final page = await _mediaChannel.listAssets(
        startTimeMs: job.startTimeMs,
        limit: _pageSize,
        cursor: cursor,
        ascending: true,
      );

      for (final raw in page.items) {
        final asset = _parseAsset(raw);
        if (asset != null) {
          all.add(asset);
        }
      }

      cursor = page.nextCursor;
      hasMore = page.hasMore;
    }

    return all;
  }

  Future<List<MediaAsset>> _buildUploadQueue(
    List<MediaAsset> assets,
    BackupJob job,
  ) async {
    _progress = _progress.copyWith(total: assets.length);
    _emitProgress();

    if (job.mode == BackupMode.all) {
      return assets;
    }

    final queue = <MediaAsset>[];
    for (final asset in assets) {
      if (_cancelled) break;
      await _waitIfPaused();

      final exists = await _backupDao.exists(asset.id);
      if (exists) {
        _progress = _progress.copyWith(
          skipped: _progress.skipped + 1,
          currentAssetId: asset.id,
        );
        _emitProgress();
      } else {
        queue.add(asset);
      }
    }
    return queue;
  }

  Future<void> _runConcurrentUpload(List<MediaAsset> queue, BackupJob job) async {
    var nextIndex = 0;
    final workerCount = job.concurrency <= 0 ? 1 : job.concurrency;

    Future<void> worker() async {
      while (!_cancelled) {
        await _waitIfPaused();
        if (_cancelled) return;

        if (nextIndex >= queue.length) return;
        final asset = queue[nextIndex];
        nextIndex += 1;

        _progress = _progress.copyWith(currentAssetId: asset.id);
        _emitProgress();

        try {
          final exported = await _mediaChannel.exportToTempFile(asset.id);
          if (_cancelled) return;

          final remotePath = _buildRemotePath(
            baseDir: _smbConfig.baseDir,
            assetId: asset.id,
            fileName: exported.fileName,
          );

          if (job.skipIfRemoteExists) {
            final remoteExists = await _smbChannel.exists(
              config: _smbConfig,
              remotePath: remotePath,
            );
            if (remoteExists) {
              _progress = _progress.copyWith(skipped: _progress.skipped + 1);
              _emitProgress();
              continue;
            }
          }

          await _smbChannel.uploadFile(
            config: _smbConfig,
            localPath: exported.localPath,
            remotePath: remotePath,
            overwrite: !job.skipIfRemoteExists,
            createParentDirs: true,
            chunkSize: _chunkSize,
          );

          await _backupDao.upsert(
            BackupRecordsCompanion(
              assetId: Value(asset.id),
              remotePath: Value(remotePath),
              uploadedAt: Value(DateTime.now().millisecondsSinceEpoch),
              size: Value(exported.fileSize),
              sha1: const Value(''),
            ),
          );

          _progress = _progress.copyWith(done: _progress.done + 1);
          _emitProgress();
        } catch (_) {
          _progress = _progress.copyWith(failed: _progress.failed + 1);
          _emitProgress();
        }
      }
    }

    final futures = List<Future<void>>.generate(workerCount, (_) => worker());
    await Future.wait(futures);
  }

  Future<void> _waitIfPaused() async {
    final completer = _pauseCompleter;
    if (completer != null && !completer.isCompleted) {
      await completer.future;
    }
  }

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(_progress);
    }
  }

  MediaAsset? _parseAsset(Map<String, dynamic> map) {
    final id = map['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return MediaAsset(
      id: id,
      createTimeMs: asInt(map['createTimeMs']),
      mimeType: map['mimeType']?.toString() ?? '',
      mediaType: map['mediaType']?.toString() ?? '',
      width: asInt(map['width']),
      height: asInt(map['height']),
      durationMs: asInt(map['durationMs']),
      fileSize: asInt(map['fileSize']),
    );
  }

  String _buildRemotePath({
    required String baseDir,
    required String assetId,
    required String fileName,
  }) {
    final normalizedBase = baseDir.endsWith('/') ? baseDir : '$baseDir/';
    return '$normalizedBase$assetId-$fileName';
  }
}
