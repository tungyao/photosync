import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/models/backup_job.dart';
import '../../data/models/media_asset.dart';
import '../../data/models/smb_config.dart';
import '../../domain/services/backup_engine.dart';
import '../../platform/channels/media_changes_channel.dart';
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

final mediaChangesChannelProvider = Provider<MediaChangesChannel>((ref) {
  return MediaChangesChannel();
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
    _prependStreamController = StreamController<List<MediaAsset>>.broadcast();
  }

  final Ref ref;
  final MediaChannel _mediaChannel;
  final ThumbnailLruCache _thumbnailCache;
  static const int _thumbSize = 256;
  static const int _pageSize = 120;
  static const int _thumbPrefetchCount = 24;
  late final StreamController<List<MediaAsset>> _assetsStreamController;
  late final StreamController<List<MediaAsset>> _prependStreamController;
  final List<List<MediaAsset>> _pages = <List<MediaAsset>>[];

  Stream<List<MediaAsset>> get assetsStream => _assetsStreamController.stream;
  Stream<List<MediaAsset>> get prependStream => _prependStreamController.stream;

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

  Future<void> refreshFirstPageIncremental({int? changedAfterMs}) async {
    if (state.isLoading) return;
    try {
      final page = await _mediaChannel.listAssets(
        startTimeMs: 0,
        limit: _pageSize,
        cursor: '0',
        ascending: false,
      );
      final firstPage = page.items
          .map(_toMediaAsset)
          .whereType<MediaAsset>()
          .toList(growable: false);
      if (firstPage.isEmpty) return;

      final existingIds = _pages.expand((chunk) => chunk).map((item) => item.id).toSet();
      final newItems = firstPage
          .where((item) => !existingIds.contains(item.id))
          .toList(growable: false);

      unawaited(
        ref
            .read(syncedIdsControllerProvider.notifier)
            .resolveForPage(firstPage.map((item) => item.id)),
      );

      if (newItems.isEmpty) return;

      if (_pages.isEmpty) {
        _pages.add(newItems);
      } else {
        _pages[0] = [...newItems, ..._pages[0]];
      }

      if (!_prependStreamController.isClosed) {
        _prependStreamController.add(newItems);
      }

      _prefetchThumbnails(newItems);
      state = state.copyWith(
        loadedCount: _pages.fold<int>(0, (sum, chunk) => sum + chunk.length),
      );
    } catch (_) {
      // Keep pull-to-refresh as fallback if event refresh fails.
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
    _prependStreamController.close();
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

enum ReceiveTaskStatus {
  idle,
  browsing,
  restoring,
  paused,
  completed,
  cancelled,
  failed,
}

class RemoteBrowserState {
  const RemoteBrowserState({
    required this.currentDir,
    required this.entries,
    required this.selectedPaths,
    required this.importedKeys,
    required this.selectionMode,
    required this.latestFirst,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.nextCursor,
    this.error,
  });

  final String currentDir;
  final List<SmbRemoteEntry> entries;
  final Set<String> selectedPaths;
  final Set<String> importedKeys;
  final bool selectionMode;
  final bool latestFirst;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  RemoteBrowserState copyWith({
    String? currentDir,
    List<SmbRemoteEntry>? entries,
    Set<String>? selectedPaths,
    Set<String>? importedKeys,
    bool? selectionMode,
    bool? latestFirst,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) {
    return RemoteBrowserState(
      currentDir: currentDir ?? this.currentDir,
      entries: entries ?? this.entries,
      selectedPaths: selectedPaths ?? this.selectedPaths,
      importedKeys: importedKeys ?? this.importedKeys,
      selectionMode: selectionMode ?? this.selectionMode,
      latestFirst: latestFirst ?? this.latestFirst,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RemoteBrowserController extends StateNotifier<RemoteBrowserState> {
  RemoteBrowserController(this.ref)
      : super(
          const RemoteBrowserState(
            currentDir: '',
            entries: <SmbRemoteEntry>[],
            selectedPaths: <String>{},
            importedKeys: <String>{},
            selectionMode: false,
            latestFirst: true,
            isLoading: false,
            isLoadingMore: false,
            hasMore: true,
          ),
        );

  final Ref ref;
  static const int _pageSize = 200;

  Future<void> loadInitial([String? dir]) async {
    final targetDir = dir ?? state.currentDir;
    state = state.copyWith(
      currentDir: targetDir,
      entries: <SmbRemoteEntry>[],
      selectedPaths: <String>{},
      importedKeys: <String>{},
      selectionMode: false,
      isLoading: true,
      isLoadingMore: false,
      hasMore: true,
      nextCursor: null,
      clearError: true,
    );
    await _loadPage(reset: true);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _loadPage(reset: false);
  }

  Future<void> enterDir(String path) async {
    await loadInitial(path);
  }

  Future<void> backToParent() async {
    if (state.currentDir.isEmpty) return;
    final normalized =
        state.currentDir.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
    final idx = normalized.lastIndexOf('/');
    final parent = idx <= 0 ? '' : normalized.substring(0, idx);
    await loadInitial(parent);
  }

  void toggleSelect(SmbRemoteEntry entry) {
    if (entry.isDir || !entry.isImage) return;
    final next = {...state.selectedPaths};
    if (next.contains(entry.path)) {
      next.remove(entry.path);
    } else {
      next.add(entry.path);
    }
    state = state.copyWith(
      selectedPaths: next,
      selectionMode: next.isNotEmpty || state.selectionMode,
    );
  }

  void longPressSelect(SmbRemoteEntry entry) {
    if (entry.isDir || !entry.isImage) return;
    if (!state.selectionMode) {
      state = state.copyWith(selectionMode: true);
    }
    toggleSelect(entry);
  }

  void clearSelectionMode() {
    state = state.copyWith(selectionMode: false, selectedPaths: <String>{});
  }

  void selectAllVisible() {
    final mediaPaths = state.entries
        .where((e) => !e.isDir && e.isImage)
        .map((e) => e.path)
        .toSet();
    if (mediaPaths.isEmpty) return;
    final next = {...state.selectedPaths};
    final allSelected = mediaPaths.every(next.contains);
    if (allSelected) {
      next.removeAll(mediaPaths);
    } else {
      next.addAll(mediaPaths);
    }
    state = state.copyWith(selectedPaths: next, selectionMode: true);
  }

  Future<void> toggleLatestFirst() async {
    state = state.copyWith(latestFirst: true);
    await loadInitial(state.currentDir);
  }

  List<SmbRemoteEntry> selectedMediaEntries() {
    final selected = state.selectedPaths;
    return state.entries
        .where((e) => !e.isDir && e.isImage && selected.contains(e.path))
        .toList(growable: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    try {
      state = state.copyWith(
        isLoading: reset,
        isLoadingMore: !reset,
        clearError: true,
      );
      final config = await ref.read(smbConfigProvider.future);
      final result = await ref.read(smbChannelProvider).listRemote(
            config: config,
            dir: state.currentDir,
            limit: _pageSize,
            cursor: reset ? null : state.nextCursor,
            latestFirst: state.latestFirst,
          );
      final nextEntries = reset ? result.items : [...state.entries, ...result.items];
      final importedKeys = await _resolveImportedKeys(nextEntries);
      state = state.copyWith(
        entries: nextEntries,
        importedKeys: importedKeys,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
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

  Future<Set<String>> _resolveImportedKeys(List<SmbRemoteEntry> entries) async {
    final media = entries.where((e) => !e.isDir && e.isImage).toList(growable: false);
    if (media.isEmpty) return <String>{};
    final payload = media
        .map((e) => <String, Object?>{'name': e.name, 'size': e.size})
        .toList(growable: false);
    return ref.read(mediaChannelProvider).findImportedByNameSize(payload);
  }

  void markImported(SmbRemoteEntry entry) {
    if (entry.isDir || !entry.isImage) return;
    final next = {...state.importedKeys, entry.localMatchKey};
    state = state.copyWith(importedKeys: next);
  }
}

final remoteBrowserProvider =
    StateNotifierProvider<RemoteBrowserController, RemoteBrowserState>((ref) {
  return RemoteBrowserController(ref);
});

class ReceiveRunnerState {
  const ReceiveRunnerState({
    required this.isRunning,
    required this.status,
    required this.total,
    required this.done,
    required this.failed,
    required this.skipped,
    required this.currentPath,
    required this.speedBytesPerSec,
    required this.failedPaths,
    this.error,
  });

  final bool isRunning;
  final ReceiveTaskStatus status;
  final int total;
  final int done;
  final int failed;
  final int skipped;
  final String? currentPath;
  final double speedBytesPerSec;
  final List<String> failedPaths;
  final String? error;

  ReceiveRunnerState copyWith({
    bool? isRunning,
    ReceiveTaskStatus? status,
    int? total,
    int? done,
    int? failed,
    int? skipped,
    String? currentPath,
    bool clearCurrentPath = false,
    double? speedBytesPerSec,
    List<String>? failedPaths,
    String? error,
    bool clearError = false,
  }) {
    return ReceiveRunnerState(
      isRunning: isRunning ?? this.isRunning,
      status: status ?? this.status,
      total: total ?? this.total,
      done: done ?? this.done,
      failed: failed ?? this.failed,
      skipped: skipped ?? this.skipped,
      currentPath: clearCurrentPath ? null : (currentPath ?? this.currentPath),
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      failedPaths: failedPaths ?? this.failedPaths,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReceiveRunnerController extends StateNotifier<ReceiveRunnerState> {
  ReceiveRunnerController(this.ref)
      : super(
          const ReceiveRunnerState(
            isRunning: false,
            status: ReceiveTaskStatus.idle,
            total: 0,
            done: 0,
            failed: 0,
            skipped: 0,
            currentPath: null,
            speedBytesPerSec: 0,
            failedPaths: <String>[],
          ),
        );

  final Ref ref;
  bool _cancelled = false;
  int _bytesWritten = 0;
  int _sampleMs = 0;
  int _sampleBytes = 0;
  final Map<String, SmbRemoteEntry> _lastEntriesByPath = <String, SmbRemoteEntry>{};

  Future<void> startRestore({
    required List<SmbRemoteEntry> selected,
    bool skipDuplicates = true,
  }) async {
    if (state.isRunning) return;
    final mediaEntries = selected.where((e) => !e.isDir && e.isMedia).toList(growable: false);
    if (mediaEntries.isEmpty) return;

    _cancelled = false;
    _bytesWritten = 0;
    _sampleMs = DateTime.now().millisecondsSinceEpoch;
    _sampleBytes = 0;
    _lastEntriesByPath
      ..clear()
      ..addEntries(mediaEntries.map((e) => MapEntry(e.path, e)));

    state = state.copyWith(
      isRunning: true,
      status: ReceiveTaskStatus.restoring,
      total: mediaEntries.length,
      done: 0,
      failed: 0,
      skipped: 0,
      failedPaths: <String>[],
      speedBytesPerSec: 0,
      clearCurrentPath: true,
      clearError: true,
    );

    try {
      final config = await ref.read(smbConfigProvider.future);
      final settings = await ref.read(appSettingsProvider.future);
      final smb = ref.read(smbChannelProvider);
      final queue = [...mediaEntries];
      var index = 0;
      final failedPaths = <String>[];
      final workerCount = settings.concurrency <= 0 ? 1 : settings.concurrency;

      Future<void> worker() async {
        while (!_cancelled) {
          if (index >= queue.length) return;
          final entry = queue[index];
          index += 1;

          state = state.copyWith(currentPath: entry.path);
          try {
            final downloaded = await smb.downloadRemoteToTemp(
              config: config,
              remotePath: entry.path,
            );
            if (_cancelled) return;
            final saved = await smb.saveTempToAlbum(
              localPath: downloaded.localPath,
              fileName: downloaded.fileName,
              mimeType: downloaded.mimeType,
              skipDuplicates: skipDuplicates,
            );

            if (saved.duplicateSkipped) {
              state = state.copyWith(skipped: state.skipped + 1);
              ref.read(remoteBrowserProvider.notifier).markImported(entry);
            } else {
              _bytesWritten += saved.bytesWritten;
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              final dt = nowMs - _sampleMs;
              final deltaBytes = _bytesWritten - _sampleBytes;
              final speed = dt <= 0 ? state.speedBytesPerSec : (deltaBytes * 1000 / dt);
              _sampleMs = nowMs;
              _sampleBytes = _bytesWritten;
              state = state.copyWith(
                done: state.done + 1,
                speedBytesPerSec: speed.toDouble(),
              );
              ref.read(remoteBrowserProvider.notifier).markImported(entry);
            }
          } catch (_) {
            failedPaths.add(entry.path);
            state = state.copyWith(
              failed: state.failed + 1,
              failedPaths: [...state.failedPaths, entry.path],
            );
          }
        }
      }

      await Future.wait(List<Future<void>>.generate(workerCount, (_) => worker()));

      if (_cancelled) {
        state = state.copyWith(
          isRunning: false,
          status: ReceiveTaskStatus.cancelled,
          clearCurrentPath: true,
        );
      } else if (failedPaths.isNotEmpty) {
        state = state.copyWith(
          isRunning: false,
          status: ReceiveTaskStatus.failed,
          clearCurrentPath: true,
        );
      } else {
        state = state.copyWith(
          isRunning: false,
          status: ReceiveTaskStatus.completed,
          clearCurrentPath: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        status: ReceiveTaskStatus.failed,
        error: e.toString(),
        clearCurrentPath: true,
      );
    }
  }

  Future<void> retryFailed() async {
    final retryEntries = state.failedPaths
        .map((path) => _lastEntriesByPath[path])
        .whereType<SmbRemoteEntry>()
        .toList(growable: false);
    if (retryEntries.isEmpty) return;
    await startRestore(selected: retryEntries);
  }

  void cancel() {
    _cancelled = true;
    state = state.copyWith(
      isRunning: false,
      status: ReceiveTaskStatus.cancelled,
      clearCurrentPath: true,
    );
  }
}

final receiveRunnerProvider =
    StateNotifierProvider<ReceiveRunnerController, ReceiveRunnerState>((ref) {
  return ReceiveRunnerController(ref);
});
