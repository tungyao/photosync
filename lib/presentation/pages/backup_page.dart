import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/backup_job.dart';
import '../controllers/app_state_controller.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupRunnerProvider);
    final controller = ref.read(backupRunnerProvider.notifier);
    final total = state.progress.total <= 0 ? 1 : state.progress.total;
    final ratio = (state.progress.done + state.progress.skipped) / total;

    return Scaffold(
      appBar: AppBar(title: const Text('增量备份')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<BackupMode>(
              segments: const [
                ButtonSegment(
                  value: BackupMode.latestOnly,
                  label: Text('latestOnly'),
                ),
                ButtonSegment(
                  value: BackupMode.all,
                  label: Text('all'),
                ),
              ],
              selected: {state.mode},
              onSelectionChanged: (set) => controller.setMode(set.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final initial = DateTime.fromMillisecondsSinceEpoch(state.startTimeMs);
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDate: initial,
                );
                if (date != null) {
                  controller.setStartTime(date);
                }
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                '起始时间: ${DateTime.fromMillisecondsSinceEpoch(state.startTimeMs).toLocal().toString().split(' ').first}',
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: ratio.clamp(0, 1)),
            const SizedBox(height: 8),
            Text(
              'done ${state.progress.done} / total ${state.progress.total}  '
              'skipped ${state.progress.skipped}  failed ${state.progress.failed}',
            ),
            if (state.progress.currentAssetId != null)
              Text('当前: ${state.progress.currentAssetId}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isRunning ? null : controller.start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始备份'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: !state.isRunning
                        ? null
                        : (state.isPaused ? controller.resume : controller.pause),
                    icon: Icon(state.isPaused ? Icons.play_circle : Icons.pause_circle),
                    label: Text(state.isPaused ? '继续' : '暂停'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isRunning ? controller.cancel : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('取消'),
                  ),
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text('错误: ${state.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Text('失败列表 (${state.failedAssetIds.length})'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: state.failedAssetIds.length,
                itemBuilder: (context, index) {
                  final id = state.failedAssetIds[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.error_outline),
                    title: Text(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
