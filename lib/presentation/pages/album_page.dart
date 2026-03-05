import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/backup_job.dart';
import '../../data/models/media_asset.dart';
import '../controllers/app_state_controller.dart';

class AlbumPage extends HomeAlbumPage {
  const AlbumPage({super.key});
}

class HomeAlbumPage extends ConsumerStatefulWidget {
  const HomeAlbumPage({super.key});

  @override
  ConsumerState<HomeAlbumPage> createState() => _HomeAlbumPageState();
}

class _HomeAlbumPageState extends ConsumerState<HomeAlbumPage> {
  final ScrollController _scrollController = ScrollController();
  final List<List<MediaAsset>> _chunks = <List<MediaAsset>>[];
  int _loadedCount = 0;
  StreamSubscription<List<MediaAsset>>? _assetsSub;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(albumControllerProvider.notifier);
    _assetsSub = controller.assetsStream.listen((chunk) {
      if (!mounted) return;
      setState(() {
        if (chunk.isEmpty) {
          _chunks.clear();
          _loadedCount = 0;
          return;
        }
        _chunks.add(chunk);
        _loadedCount += chunk.length;
      });
    });
    Future.microtask(controller.loadInitial);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _assetsSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 800) {
      ref.read(albumControllerProvider.notifier).loadMore();
    }
  }

  MediaAsset _assetAt(int index) {
    var remaining = index;
    for (final chunk in _chunks) {
      if (remaining < chunk.length) return chunk[remaining];
      remaining -= chunk.length;
    }
    return _chunks.last.last;
  }

  Future<void> _openSyncDialogAndStart() async {
    final target = ref.read(syncTargetProvider);
    final albumState = ref.read(albumControllerProvider);
    final backupState = ref.read(backupRunnerProvider);
    final backup = ref.read(backupRunnerProvider.notifier);

    BackupMode mode;
    Set<String>? selected;

    switch (target) {
      case SyncTarget.latestOnly:
        mode = BackupMode.latestOnly;
        selected = null;
        break;
      case SyncTarget.all:
        mode = BackupMode.all;
        selected = null;
        break;
      case SyncTarget.selected:
        if (albumState.selectedIds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select items first.')),
          );
          return;
        }
        mode = BackupMode.all;
        selected = albumState.selectedIds;
        break;
    }

    if (!backupState.isRunning) {
      unawaited(backup.start(mode: mode, selectedIds: selected));
    }

    if (ref.read(syncDialogVisibleProvider)) return;
    ref.read(syncDialogVisibleProvider.notifier).state = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const SyncProgressDialog(),
    );
    if (mounted) {
      ref.read(syncDialogVisibleProvider.notifier).state = false;
    }
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _SettingsBottomSheetContent(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final albumState = ref.watch(albumControllerProvider);
    final syncedIds = ref.watch(syncedIdsProvider);
    final backupState = ref.watch(backupRunnerProvider);
    final controller = ref.read(albumControllerProvider.notifier);
    final visible =
        _chunks.expand((chunk) => chunk).map((item) => item.id).toSet();
    final allSelected =
        visible.isNotEmpty && visible.every(albumState.selectedIds.contains);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoSync'),
        actions: [
          PopupMenuButton<SyncTarget>(
            initialValue: ref.watch(syncTargetProvider),
            tooltip: 'Sync target',
            onSelected: (value) =>
                ref.read(syncTargetProvider.notifier).state = value,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: SyncTarget.latestOnly,
                child: Text('Sync New'),
              ),
              PopupMenuItem(
                value: SyncTarget.all,
                child: Text('Sync All'),
              ),
              PopupMenuItem(
                value: SyncTarget.selected,
                child: Text('Sync Selected'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.tune),
            ),
          ),
          TextButton(
            onPressed: controller.selectAll,
            child: Text(allSelected ? 'Unselect All' : 'Select All'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text('Selected ${albumState.selectedIds.length}'),
                    const SizedBox(width: 12),
                    Text('Loaded $_loadedCount'),
                    const SizedBox(width: 12),
                    Text(backupState.isRunning ? 'Syncing' : 'Idle'),
                    const Spacer(),
                    if (albumState.isLoadingMore)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: albumState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : albumState.error != null
                        ? Center(child: Text('Load failed: ${albumState.error}'))
                        : RefreshIndicator(
                            onRefresh: controller.loadInitial,
                            child: GridView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 96),
                              cacheExtent: 1400,
                              addAutomaticKeepAlives: false,
                              addRepaintBoundaries: true,
                              addSemanticIndexes: false,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: _loadedCount,
                              itemBuilder: (context, index) {
                                final item = _assetAt(index);
                                final selected =
                                    albumState.selectedIds.contains(item.id);
                                final synced = syncedIds.contains(item.id);
                                return _AlbumGridCell(
                                  key: ValueKey<String>(item.id),
                                  id: item.id,
                                  mediaType: item.mediaType,
                                  isSelected: selected,
                                  isSynced: synced,
                                  onTap: () => controller.toggleSelect(item.id),
                                  thumbLoader: () =>
                                      controller.loadThumbnail(item.id),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'sync_fab',
              onPressed: _openSyncDialogAndStart,
              child: const Icon(Icons.sync),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'settings_fab',
              onPressed: _showSettingsBottomSheet,
              child: const Icon(Icons.settings),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumGridCell extends StatefulWidget {
  const _AlbumGridCell({
    super.key,
    required this.id,
    required this.mediaType,
    required this.isSelected,
    required this.isSynced,
    required this.onTap,
    required this.thumbLoader,
  });

  final String id;
  final String mediaType;
  final bool isSelected;
  final bool isSynced;
  final VoidCallback onTap;
  final Future<Uint8List?> Function() thumbLoader;

  @override
  State<_AlbumGridCell> createState() => _AlbumGridCellState();
}

class _AlbumGridCellState extends State<_AlbumGridCell> {
  late Future<Uint8List?> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = widget.thumbLoader();
  }

  @override
  void didUpdateWidget(covariant _AlbumGridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _thumbFuture = widget.thumbLoader();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSynced ? Colors.blue : Colors.transparent,
            width: widget.isSynced ? 3 : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: _thumbFuture,
                builder: (context, snapshot) {
                  final bytes = snapshot.data;
                  if (bytes != null && bytes.isNotEmpty) {
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.low,
                    );
                  }
                  return ColoredBox(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      widget.mediaType.toLowerCase().contains('video')
                          ? Icons.videocam
                          : Icons.image,
                      color: cs.onSurfaceVariant,
                    ),
                  );
                },
              ),
              if (widget.isSelected)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.28),
                  ),
                ),
              if (widget.isSelected)
                const Positioned(
                  left: 6,
                  top: 6,
                  child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
              if (widget.isSynced)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: _SyncedBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncedBadge extends StatelessWidget {
  const _SyncedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: const Padding(
        padding: EdgeInsets.all(3),
        child: Icon(Icons.check, color: Colors.white, size: 14),
      ),
    );
  }
}

class _SettingsBottomSheetContent extends ConsumerWidget {
  const _SettingsBottomSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return settingsState.when(
      data: (settings) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sync Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Concurrency ${settings.concurrency}'),
            Slider(
              min: 1,
              max: 8,
              divisions: 7,
              value: settings.concurrency.toDouble(),
              label: settings.concurrency.toString(),
              onChanged: (v) => notifier.setConcurrency(v.round()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.skipIfRemoteExists,
              title: const Text('Skip when file exists remotely'),
              onChanged: notifier.setSkipIfRemoteExists,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open full settings'),
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Load settings failed: $e'),
      ),
    );
  }
}

class SyncProgressDialog extends ConsumerWidget {
  const SyncProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupRunnerProvider);
    final controller = ref.read(backupRunnerProvider.notifier);
    final total = state.progress.total <= 0 ? 1 : state.progress.total;
    final ratio = (state.progress.done + state.progress.skipped) / total;
    final currentId = state.progress.currentAssetId ?? '-';
    final speedMb = state.speedBytesPerSec / (1024 * 1024);

    return PopScope(
      canPop: !state.isRunning,
      child: AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Sync Progress')),
            if (!state.isRunning)
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: ratio.clamp(0, 1)),
              const SizedBox(height: 10),
              Text('done ${state.progress.done} / total ${state.progress.total}'),
              Text('failed ${state.progress.failed}'),
              Text('speed ${speedMb.toStringAsFixed(2)} MB/s'),
              Text(
                'current $currentId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('status: ${_statusText(state.status)}'),
              if (state.error != null)
                Text(
                  'error: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: state.isRunning ? controller.cancel : null,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Run in Background'),
          ),
          FilledButton(
            onPressed: (!state.isRunning && state.failedAssetIds.isNotEmpty)
                ? controller.retryFailed
                : null,
            child: const Text('Retry Failed'),
          ),
          if (!state.isRunning)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  static String _statusText(BackupUiStatus status) {
    switch (status) {
      case BackupUiStatus.idle:
        return 'idle';
      case BackupUiStatus.running:
        return 'running';
      case BackupUiStatus.paused:
        return 'paused';
      case BackupUiStatus.completed:
        return 'completed';
      case BackupUiStatus.cancelled:
        return 'cancelled';
      case BackupUiStatus.failed:
        return 'failed';
    }
  }
}
