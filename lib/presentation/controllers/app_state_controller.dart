import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/models/backup_job.dart';
import '../../data/models/smb_config.dart';
import '../../domain/services/backup_engine.dart';
import '../../platform/channels/media_channel.dart';
import '../../platform/channels/smb_channel.dart';

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

  void update(SmbConfig config) {
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

class AlbumItem {
  const AlbumItem({
    required this.id,
    required this.mimeType,
    required this.mediaType,
    required this.createTimeMs,
  });

  final String id;
  final String mimeType;
  final String mediaType;
  final int createTimeMs;
}

class AlbumState {
  const AlbumState({
    required this.items,
    required this.selectedIds,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    this.nextCursor,
    this.error,
  });

  final List<AlbumItem> items;
  final Set<String> selectedIds;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  AlbumState copyWith({
    List<AlbumItem>? items,
    Set<String>? selectedIds,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) {
    return AlbumState(
      items: items ?? this.items,
      selectedIds: selectedIds ?? this.selectedIds,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AlbumController extends StateNotifier<AlbumState> {
  AlbumController(this._mediaChannel)
      : super(
          const AlbumState(
            items: <AlbumItem>[],
            selectedIds: <String>{},
            isLoading: false,
            isLoadingMore: false,
            hasMore: true,
          ),
        );

  final MediaChannel _mediaChannel;
  static const int _pageSize = 120;

  Future<void> loadInitial() async {
    state = state.copyWith(
      isLoading: true,
      hasMore: true,
      nextCursor: null,
      items: <AlbumItem>[],
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
    final visible = state.items.map((e) => e.id).toSet();
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
          .map(_toAlbumItem)
          .whereType<AlbumItem>()
          .toList(growable: false);

      state = state.copyWith(
        items: reset ? parsed : [...state.items, ...parsed],
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

  AlbumItem? _toAlbumItem(Map<String, dynamic> raw) {
    final id = raw['id']?.toString();
    if (id == null || id.isEmpty) return null;

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return AlbumItem(
      id: id,
      mimeType: raw['mimeType']?.toString() ?? '',
      mediaType: raw['mediaType']?.toString() ?? '',
      createTimeMs: toInt(raw['createTimeMs']),
    );
  }
}

final albumControllerProvider =
    StateNotifierProvider<AlbumController, AlbumState>((ref) {
  return AlbumController(ref.read(mediaChannelProvider));
});

class BackupRunnerState {
  const BackupRunnerState({
    required this.mode,
    required this.startTimeMs,
    required this.isRunning,
    required this.isPaused,
    required this.progress,
    required this.failedAssetIds,
    this.error,
  });

  final BackupMode mode;
  final int startTimeMs;
  final bool isRunning;
  final bool isPaused;
  final BackupProgress progress;
  final List<String> failedAssetIds;
  final String? error;

  BackupRunnerState copyWith({
    BackupMode? mode,
    int? startTimeMs,
    bool? isRunning,
    bool? isPaused,
    BackupProgress? progress,
    List<String>? failedAssetIds,
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
              currentAssetId: null,
            ),
            failedAssetIds: const <String>[],
          ),
        );

  final Ref ref;
  BackupEngine? _engine;
  StreamSubscription<BackupProgress>? _sub;

  void setMode(BackupMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setStartTime(DateTime date) {
    state = state.copyWith(startTimeMs: date.millisecondsSinceEpoch);
  }

  Future<void> start() async {
    if (state.isRunning) return;
    state = state.copyWith(
      isRunning: true,
      isPaused: false,
      failedAssetIds: <String>[],
      progress: const BackupProgress(
        total: 0,
        done: 0,
        failed: 0,
        skipped: 0,
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
      state = state.copyWith(progress: p, failedAssetIds: failedIds);
    });

    try {
      await _engine!.start(
        BackupJob(
          jobId: DateTime.now().millisecondsSinceEpoch.toString(),
          mode: state.mode,
          startTimeMs: state.startTimeMs,
          skipIfRemoteExists: settings.skipIfRemoteExists,
          concurrency: settings.concurrency,
        ),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isRunning: false, isPaused: false);
    }
  }

  void pause() {
    _engine?.pause();
    state = state.copyWith(isPaused: true);
  }

  void resume() {
    _engine?.resume();
    state = state.copyWith(isPaused: false);
  }

  void cancel() {
    _engine?.cancel();
    state = state.copyWith(isRunning: false, isPaused: false);
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
