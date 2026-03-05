import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_state_controller.dart';

class AlbumPage extends ConsumerStatefulWidget {
  const AlbumPage({super.key});

  @override
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(albumControllerProvider.notifier).loadInitial(),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 500) {
      ref.read(albumControllerProvider.notifier).loadMore();
    }
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
            child: const Text('全选'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text('已选 ${state.selectedIds.length}'),
                const Spacer(),
                if (state.isLoadingMore) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('加载失败: ${state.error}'))
                    : RefreshIndicator(
                        onRefresh: controller.loadInitial,
                        child: GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: state.items.length,
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            final selected = state.selectedIds.contains(item.id);
                            return _AlbumGridCell(
                              id: item.id,
                              subtitle: item.mediaType,
                              selected: selected,
                              onTap: () => controller.toggleSelect(item.id),
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

class _AlbumGridCell extends StatelessWidget {
  const _AlbumGridCell({
    required this.id,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                subtitle.toLowerCase().contains('video')
                    ? Icons.videocam
                    : Icons.image,
              ),
              const SizedBox(height: 8),
              Text(
                id,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
