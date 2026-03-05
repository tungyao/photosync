import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/models/backup_job.dart';
import '../../data/models/media_asset.dart';
import '../../data/models/smb_config.dart';
import '../../domain/services/backup_engine.dart';
import '../../platform/channels/media_channel.dart';
import '../../platform/channels/smb_channel.dart';
import 'thumbnail_lru_cache.dart';

const _kHost = 'smb.host';
const _kPort = 'smb.port';
const _kShare = 'smb.share';
const _kUsername = 'smb.username';
const _kPassword = 'smb.password';
const _kDomain = 'smb.domain';
const _kBaseDir = 'smb.baseDir';
const _kTimeoutMs = 'smb.timeoutMs';
const _kUseSmb1 = 'smb.useSMB1';
const _kConcurrency = 'backup.concurrency';
const _kSkipRemoteExists = 'backup.skipIfRemoteExists';

enum BackupUiStatus {
  idle,
  running,
  paused,
  completed,
  cancelled,
  failed,
}

enum SyncTarget {
  latestOnly,
  all,
  selected,
}

final syncDialogVisibleProvider = StateProvider<bool>((ref) => false);
final syncTargetProvider = StateProvider<SyncTarget>((ref) => SyncTarget.latestOnly);

class SyncedIdsState {
  const SyncedIdsState({
    required this.syncedIds,
    required this.resolvedIds,
  });

  final Set<String> syncedIds;
  final Set<String> resolvedIds;

  SyncedIdsState copyWith({
    Set<String>? syncedIds,
    Set<String>? resolvedIds,
  }) {
    return SyncedIdsState(
      syncedIds: syncedIds ?? this.syncedIds,
      resolvedIds: resolvedIds ?? this.resolvedIds,
    );
  }
}

class SyncedIdsController extends StateNotifier<SyncedIdsState> {
  SyncedIdsController(this._dao)
      : super(
          const SyncedIdsState(
            syncedIds: <String>{},
            resolvedIds: <String>{},
          ),
        );

  final BackupDao _dao;

  Future<void> resolveForPage(Iterable<String> assetIds) async {
    final ids = assetIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;

    final unresolved = ids.difference(state.resolvedIds);
    if (unresolved.isEmpty) return;

    final existing = await _dao.findExistingIds(unresolved);
    state = state.copyWith(
      syncedIds: {...state.syncedIds, ...existing},
      resolvedIds: {...state.resolvedIds, ...unresolved},
    );
  }

  void markSynced(Iterable<String> ids) {
    final valid = ids.where((id) => id.isNotEmpty).toSet();
    if (valid.isEmpty) return;
    state = state.copyWith(
      syncedIds: {...state.syncedIds, ...valid},
      resolvedIds: {...state.resolvedIds, ...valid},
    );
  }

  void clear() {
    state = const SyncedIdsState(syncedIds: <String>{}, resolvedIds: <String>{});
  }
}

final syncedIdsControllerProvider =
    StateNotifierProvider<SyncedIdsController, SyncedIdsState>((ref) {
  return SyncedIdsController(ref.read(backupDaoProvider));
});

final syncedIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(syncedIdsControllerProvider.select((s) => s.syncedIds));
});

final backupDaoProvider = Provider<BackupDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.backupDao;
});

final mediaChannelProvider = Provider<MediaChannel>((ref) {
  return MediaChannel();
});

final smbChannelProvider = Provider<SmbChannel>((ref) {
  return SmbChannel();
});

class AppSettings {
  const AppSettings({
    required this.concurrency,
    required this.skipIfRemoteExists,
  });

  final int concurrency;
  final bool skipIfRemoteExists;

  AppSettings copyWith({
    int? concurrency,
    bool? skipIfRemoteExists,
  }) {
    return AppSettings(
      concurrency: concurrency ?? this.concurrency,
      skipIfRemoteExists: skipIfRemoteExists ?? this.skipIfRemoteExists,
    );
  }
}

class SmbConfigController extends AsyncNotifier<SmbConfig> {
  @override
  Future<SmbConfig> build() async {
    final dao = ref.read(backupDaoProvider);
    final host = await dao.getSetting(_kHost) ?? '';
    final port = int.tryParse(await dao.getSetting(_kPort) ?? '') ?? 445;
    final share = await dao.getSetting(_kShare) ?? '';
    final username = await dao.getSetting(_kUsername) ?? '';
    final password = await dao.getSetting(_kPassword) ?? '';
    final domain = await dao.getSetting(_kDomain) ?? '';
    final baseDir = await dao.getSetting(_kBaseDir) ?? '/photosync';
    final timeoutMs = int.tryParse(await dao.getSetting(_kTimeoutMs) ?? '') ?? 15000;
    final useSMB1 = (await dao.getSetting(_kUseSmb1) ?? 'false') == 'true';

    return SmbConfig(
      host: host,
      port: port,
      share: share,
      username: username,
      password: password,
      domain: domain,
      baseDir: baseDir,
      timeoutMs: timeoutMs,
      useSMB1: useSMB1,
    );
  }

  void setConfig(SmbConfig config) {
    state = AsyncData(config);
  }

  Future<void> save() async {
    final dao = ref.read(backupDaoProvider);
    final config = await future;
    await dao.setSetting(_kHost, config.host);
    await dao.setSetting(_kPort, config.port.toString());
    await dao.setSetting(_kShare, config.share);
    await dao.setSetting(_kUsername, config.username);
    await dao.setSetting(_kPassword, config.password);
    await dao.setSetting(_kDomain, config.domain);
    await dao.setSetting(_kBaseDir, config.baseDir);
    await dao.setSetting(_kTimeoutMs, config.timeoutMs.toString());
    await dao.setSetting(_kUseSmb1, config.useSMB1.toString());
  }

  Future<bool> testConnection() async {
    final config = await future;
    final smb = ref.read(smbChannelProvider);
    return smb.testConnection(config);
  }
}

final smbConfigProvider = AsyncNotifierProvider<SmbConfigController, SmbConfig>(
  SmbConfigController.new,
);

class AppSettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final dao = ref.read(backupDaoProvider);
    final concurrency =
        int.tryParse(await dao.getSetting(_kConcurrency) ?? '') ?? 3;
    final skip = (await dao.getSetting(_kSkipRemoteExists) ?? 'true') == 'true';
    return AppSettings(concurrency: concurrency, skipIfRemoteExists: skip);
  }

  Future<void> setConcurrency(int value) async {
    final safe = value <= 0 ? 1 : value;
    final current = await future;
    state = AsyncData(current.copyWith(concurrency: safe));
    await ref.read(backupDaoProvider).setSetting(_kConcurrency, safe.toString());
  }

  Future<void> setSkipIfRemoteExists(bool value) async {
    final current = await future;
    state = AsyncData(current.copyWith(skipIfRemoteExists: value));
    await ref
        .read(backupDaoProvider)
        .setSetting(_kSkipRemoteExists, value.toString());
  }
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);

class AlbumState {
  const AlbumState({
    required this.selectedIds,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.loadedCount,
    this.nextCursor,
    this.error,
  });

  final Set<String> selectedIds;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int loadedCount;
  final String? nextCursor;
  final String? error;

  AlbumState copyWith({
    Set<String>? selectedIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? loadedCount,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) {
    return AlbumState(
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      loadedCount: loadedCount ?? this.loadedCount,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final thumbnailCacheProvider = Provider<ThumbnailLruCache>((ref) {
  final cache = ThumbnailLruCache(maxEntries: 300);
  ref.onDispose(cache.clear);
  return cache;
});

class AlbumController extends StateNotifier<AlbumState> {
  AlbumController(this.ref, this._mediaChannel, this._thumbnailCache)
      : super(
          const AlbumState(
            selectedIds: <String>{},
            isLoading: false,
            isLoadingMore: false,
            hasMore: true,
            loadedCount: 0,
          ),
        ) {
    _assetsStreamController = StreamController<List<MediaAsset>>.broadcast();
  }

  final Ref ref;
  final MediaChannel _mediaChannel;
  final ThumbnailLruCache _thumbnailCache;
  static const int _thumbSize = 256;
  static const int _pageSize = 120;
  static const int _thumbPrefetchCount = 24;
  late final StreamController<List<MediaAsset>> _assetsStreamController;
  final List<List<MediaAsset>> _pages = <List<MediaAsset>>[];

  Stream<List<MediaAsset>> get assetsStream => _assetsStreamController.stream;

  Future<void> loadInitial() async {
    final granted = await _mediaChannel.requestPermission();
    ref.read(syncedIdsControllerProvider.notifier).clear();
    if (!granted) {
      _pages.clear();
      if (!_assetsStreamController.isClosed) {
        _assetsStreamController.add(const <MediaAsset>[]);
      }
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        loadedCount: 0,
        nextCursor: null,
        error: 'Media permission denied',
      );
      return;
    }

    _pages.clear();
    if (!_assetsStreamController.isClosed) {
      _assetsStreamController.add(const <MediaAsset>[]);
    }
    state = state.copyWith(
      isLoading: true,
      hasMore: true,
      loadedCount: 0,
      nextCursor: null,
      clearError: true,
    );
    await _loadPage(reset: true);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _loadPage(reset: false);
  }

  void toggleSelect(String id) {
    final next = {...state.selectedIds};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedIds: next);
  }

  void selectAll() {
    final visible = _pages.expand((e) => e).map((e) => e.id).toSet();
    final next = {...state.selectedIds};
    final allSelected = visible.isNotEmpty && visible.every(next.contains);
    if (allSelected) {
      next.removeAll(visible);
    } else {
      next.addAll(visible);
    }
    state = state.copyWith(selectedIds: next);
  }

  Future<void> _loadPage({required bool reset}) async {
    try {
      state = state.copyWith(
        isLoading: reset,
        isLoadingMore: !reset,
        clearError: true,
      );
      final page = await _mediaChannel.listAssets(
        limit: _pageSize,
        cursor: reset ? null : state.nextCursor,
        ascending: false,
      );
      final parsed = page.items
          .map(_toMediaAsset)
          .whereType<MediaAsset>()
          .toList(growable: false);

      if (reset) {
        _pages.clear();
      }
      if (parsed.isNotEmpty) {
        _pages.add(parsed);
        if (!_assetsStreamController.isClosed) {
          _assetsStreamController.add(parsed);
        }
        unawaited(
          ref
              .read(syncedIdsControllerProvider.notifier)
              .resolveForPage(parsed.map((item) => item.id)),
        );
      }
      _prefetchThumbnails(parsed);

      state = state.copyWith(
        loadedCount: _pages.fold<int>(0, (sum, page) => sum + page.length),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  void _prefetchThumbnails(List<MediaAsset> assets) {
    if (assets.isEmpty) return;
    for (final asset in assets.take(_thumbPrefetchCount)) {
      unawaited(loadThumbnail(asset.id));
    }
  }

  Future<Uint8List?> loadThumbnail(String assetId) {
    return _thumbnailCache.getOrLoad(
      assetId,
      () => _mediaChannel.getThumbnail(
        assetId: assetId,
        width: _thumbSize,
        height: _thumbSize,
      ),
    );
  }

  MediaAsset? _toMediaAsset(Map<String, dynamic> raw) {
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return MediaAsset(
      id: id,
      mimeType: raw['mimeType']?.toString() ?? '',
      mediaType: raw['mediaType']?.toString() ?? '',
      createTimeMs: toInt(raw['dateTakenMs']),
      width: toInt(raw['width']),
      height: toInt(raw['height']),
      durationMs: toInt(raw['durationMs']),
      fileSize: toInt(raw['fileSize']),
    );
  }

  @override
  void dispose() {
    _assetsStreamController.close();
    super.dispose();
  }
}

final albumControllerProvider =
    StateNotifierProvider<AlbumController, AlbumState>((ref) {
  return AlbumController(
    ref,
    ref.read(mediaChannelProvider),
    ref.read(thumbnailCacheProvider),
  );
});

class BackupRunnerState {
  const BackupRunnerState({
    required this.mode,
    required this.startTimeMs,
    required this.isRunning,
    required this.isPaused,
    required this.progress,
    required this.failedAssetIds,
    required this.speedBytesPerSec,
    required this.status,
    this.error,
  });

  final BackupMode mode;
  final int startTimeMs;
  final bool isRunning;
  final bool isPaused;
  final BackupProgress progress;
  final List<String> failedAssetIds;
  final double speedBytesPerSec;
  final BackupUiStatus status;
  final String? error;

  BackupRunnerState copyWith({
    BackupMode? mode,
    int? startTimeMs,
    bool? isRunning,
    bool? isPaused,
    BackupProgress? progress,
    List<String>? failedAssetIds,
    double? speedBytesPerSec,
    BackupUiStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return BackupRunnerState(
      mode: mode ?? this.mode,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      progress: progress ?? this.progress,
      failedAssetIds: failedAssetIds ?? this.failedAssetIds,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BackupRunnerController extends StateNotifier<BackupRunnerState> {
  BackupRunnerController(this.ref)
      : super(
          BackupRunnerState(
            mode: BackupMode.latestOnly,
            startTimeMs: DateTime.now()
                .subtract(const Duration(days: 30))
                .millisecondsSinceEpoch,
            isRunning: false,
            isPaused: false,
            progress: const BackupProgress(
              total: 0,
              done: 0,
              failed: 0,
              skipped: 0,
              bytesUploaded: 0,
              currentAssetId: null,
            ),
            failedAssetIds: const <String>[],
            speedBytesPerSec: 0,
            status: BackupUiStatus.idle,
          ),
        );

  final Ref ref;
  BackupEngine? _engine;
  StreamSubscription<BackupProgress>? _sub;
  int _speedSampleMs = 0;
  int _speedSampleBytes = 0;
  String? _lastRecordedUploadedId;

  void setMode(BackupMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setStartTime(DateTime date) {
    state = state.copyWith(startTimeMs: date.millisecondsSinceEpoch);
  }

  Future<void> start({BackupMode? mode, Set<String>? selectedIds}) async {
    if (state.isRunning) return;

    final effectiveMode = mode ?? state.mode;
    final selected = (selectedIds ?? <String>{}).where((id) => id.isNotEmpty).toSet();
    final useSelected = selected.isNotEmpty;

    _speedSampleMs = DateTime.now().millisecondsSinceEpoch;
    _speedSampleBytes = 0;
    _lastRecordedUploadedId = null;

    state = state.copyWith(
      mode: effectiveMode,
      isRunning: true,
      isPaused: false,
      failedAssetIds: <String>[],
      speedBytesPerSec: 0,
      status: BackupUiStatus.running,
      progress: const BackupProgress(
        total: 0,
        done: 0,
        failed: 0,
        skipped: 0,
        bytesUploaded: 0,
        currentAssetId: null,
      ),
      clearError: true,
    );

    final config = await ref.read(smbConfigProvider.future);
    final settings = await ref.read(appSettingsProvider.future);

    _engine = BackupEngine(
      mediaChannel: ref.read(mediaChannelProvider),
      smbChannel: ref.read(smbChannelProvider),
      backupDao: ref.read(backupDaoProvider),
      smbConfig: config,
    );

    _sub?.cancel();
    _sub = _engine!.progressStream.listen((p) {
      final failedIds = <String>[...state.failedAssetIds];
      if (p.failed > state.progress.failed && p.currentAssetId != null) {
        failedIds.add(p.currentAssetId!);
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dt = nowMs - _speedSampleMs;
      final deltaBytes = p.bytesUploaded - _speedSampleBytes;
      final speed = dt <= 0
          ? state.speedBytesPerSec
          : (deltaBytes * 1000 / dt)
              .toDouble()
              .clamp(0, double.infinity)
              .toDouble();

      _speedSampleMs = nowMs;
      _speedSampleBytes = p.bytesUploaded;

      if (p.lastUploadedAssetId != null &&
          p.lastUploadedAssetId != _lastRecordedUploadedId) {
        _lastRecordedUploadedId = p.lastUploadedAssetId;
        ref
            .read(syncedIdsControllerProvider.notifier)
            .markSynced({p.lastUploadedAssetId!});
      }

      state = state.copyWith(
        progress: p,
        failedAssetIds: failedIds,
        speedBytesPerSec: speed,
      );
    });

    try {
      await _engine!.start(
        BackupJob(
          jobId: DateTime.now().millisecondsSinceEpoch.toString(),
          mode: effectiveMode,
          startTimeMs: useSelected ? 0 : state.startTimeMs,
          skipIfRemoteExists: settings.skipIfRemoteExists,
          concurrency: settings.concurrency,
          selectedAssetIds: useSelected ? selected : null,
        ),
      );

      if (state.status != BackupUiStatus.cancelled) {
        state = state.copyWith(status: BackupUiStatus.completed);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString(), status: BackupUiStatus.failed);
    } finally {
      state = state.copyWith(isRunning: false, isPaused: false);
    }
  }

  Future<void> retryFailed() {
    return start(mode: BackupMode.all, selectedIds: state.failedAssetIds.toSet());
  }

  void pause() {
    _engine?.pause();
    state = state.copyWith(isPaused: true, status: BackupUiStatus.paused);
  }

  void resume() {
    _engine?.resume();
    state = state.copyWith(isPaused: false, status: BackupUiStatus.running);
  }

  void cancel() {
    _engine?.cancel();
    state = state.copyWith(
      isRunning: false,
      isPaused: false,
      status: BackupUiStatus.cancelled,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine?.dispose();
    super.dispose();
  }
}

final backupRunnerProvider =
    StateNotifierProvider<BackupRunnerController, BackupRunnerState>((ref) {
  return BackupRunnerController(ref);
});
