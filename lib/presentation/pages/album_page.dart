import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/media_asset.dart';
import '../controllers/app_state_controller.dart';

class AlbumPage extends ConsumerStatefulWidget {
  const AlbumPage({super.key});

  @override
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(albumControllerProvider);
    final controller = ref.read(albumControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Album'),
        actions: [
          TextButton(
            onPressed: controller.selectAll,
            child: const Text('Select All'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text('Selected ${state.selectedIds.length}'),
                const SizedBox(width: 12),
                Text('Loaded $_loadedCount'),
                const Spacer(),
                if (state.isLoadingMore)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Load failed: ${state.error}'))
                    : RefreshIndicator(
                        onRefresh: controller.loadInitial,
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
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
                            final selected = state.selectedIds.contains(item.id);
                            return _AlbumGridCell(
                              key: ValueKey<String>(item.id),
                              id: item.id,
                              mediaType: item.mediaType,
                              selected: selected,
                              onTap: () => controller.toggleSelect(item.id),
                              thumbLoader: () => controller.loadThumbnail(item.id),
                            );
                          },
                        ),
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
    required this.selected,
    required this.onTap,
    required this.thumbLoader,
  });

  final String id;
  final String mediaType;
  final bool selected;
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
            color: widget.selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
              if (widget.selected)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.check_circle, color: cs.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
