import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_state_controller.dart';

class ReceiveProgressDialog extends ConsumerWidget {
  const ReceiveProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiveRunnerProvider);
    final controller = ref.read(receiveRunnerProvider.notifier);
    final total = state.total <= 0 ? 1 : state.total;
    final ratio = (state.done + state.skipped + state.failed) / total;
    final speedMb = state.speedBytesPerSec / (1024 * 1024);

    return PopScope(
      canPop: !state.isRunning,
      child: AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Restore Progress')),
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
              Text('done ${state.done} / total ${state.total}'),
              Text('failed ${state.failed}'),
              Text('skipped ${state.skipped}'),
              Text('speed ${speedMb.toStringAsFixed(2)} MB/s'),
              Text(
                'current ${state.currentPath ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('status: ${state.status.name}'),
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
            onPressed: (!state.isRunning && state.failedPaths.isNotEmpty)
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
}
