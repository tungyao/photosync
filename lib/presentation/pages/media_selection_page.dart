import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/selection_controller.dart';
import '../widgets/media_tile.dart';

class MediaSelectionPage extends ConsumerWidget {
  const MediaSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsState = ref.watch(galleryAssetsProvider);
    final selectedIds = ref.watch(selectedIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择媒体'),
      ),
      body: assetsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
        data: (assets) {
          if (assets.isEmpty) {
            return const Center(child: Text('未找到可备份媒体或权限未授予'));
          }
          return ListView.builder(
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              final selected = selectedIds.contains(asset.id);
              return MediaTile(
                asset: asset,
                selected: selected,
                onTap: () {
                  final next = {...selectedIds};
                  if (selected) {
                    next.remove(asset.id);
                  } else {
                    next.add(asset.id);
                  }
                  ref.read(selectedIdsProvider.notifier).state = next;
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text('已选择 ${selectedIds.length} 项'),
        ),
      ),
    );
  }
}
