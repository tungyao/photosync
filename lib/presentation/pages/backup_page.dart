import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/backup_controller.dart';
import '../widgets/progress_card.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(backupProgressProvider);
    final backupState = ref.watch(backupActionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('增量备份')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            backupState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('备份失败: $e'),
              data: (synced) => ProgressCard(progress: progress, synced: synced),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.refresh(backupActionProvider),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('开始备份'),
            ),
          ],
        ),
      ),
    );
  }
}
