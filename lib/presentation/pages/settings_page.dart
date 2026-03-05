import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_state_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsState.when(
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('并发数: ${settings.concurrency}'),
              Slider(
                min: 1,
                max: 8,
                divisions: 7,
                value: settings.concurrency.toDouble(),
                label: settings.concurrency.toString(),
                onChanged: (v) => notifier.setConcurrency(v.round()),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: settings.skipIfRemoteExists,
                title: const Text('skipIfRemoteExists'),
                subtitle: const Text('远端已存在同名文件时跳过'),
                onChanged: notifier.setSkipIfRemoteExists,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}
