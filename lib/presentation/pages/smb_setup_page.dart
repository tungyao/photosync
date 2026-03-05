import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/smb_config.dart';
import '../controllers/app_state_controller.dart';

class SmbSetupPage extends ConsumerStatefulWidget {
  const SmbSetupPage({super.key});

  @override
  ConsumerState<SmbSetupPage> createState() => _SmbSetupPageState();
}

class _SmbSetupPageState extends ConsumerState<SmbSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController();
  final _shareCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _baseDirCtrl = TextEditingController();

  @override
  void dispose() {
    _hostCtrl.dispose();
    _shareCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _baseDirCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(smbConfigProvider);
    final notifier = ref.read(smbConfigProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('SMB 配置')),
      body: configState.when(
        data: (cfg) {
          _syncTextControllers(cfg);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _hostCtrl,
                  decoration: const InputDecoration(labelText: 'host'),
                  validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _shareCtrl,
                  decoration: const InputDecoration(labelText: 'share'),
                  validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(labelText: 'username'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(labelText: 'password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _baseDirCtrl,
                  decoration: const InputDecoration(labelText: 'baseDir'),
                  validator: (v) => (v == null || v.isEmpty) ? '必填' : null,
                ),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: () async {
                    if (!_validateAndUpdate(notifier, cfg)) return;
                    final ok = await notifier.testConnection();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '连接成功' : '连接失败')),
                    );
                  },
                  child: const Text('测试连接'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (!_validateAndUpdate(notifier, cfg)) return;
                    await notifier.save();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('配置已保存')),
                    );
                  },
                  child: const Text('保存配置'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  void _syncTextControllers(SmbConfig cfg) {
    if (_hostCtrl.text != cfg.host) _hostCtrl.text = cfg.host;
    if (_shareCtrl.text != cfg.share) _shareCtrl.text = cfg.share;
    if (_userCtrl.text != cfg.username) _userCtrl.text = cfg.username;
    if (_passCtrl.text != cfg.password) _passCtrl.text = cfg.password;
    if (_baseDirCtrl.text != cfg.baseDir) _baseDirCtrl.text = cfg.baseDir;
  }

  bool _validateAndUpdate(SmbConfigController notifier, SmbConfig old) {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return false;
    notifier.update(
      old.copyWith(
        host: _hostCtrl.text.trim(),
        share: _shareCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        baseDir: _baseDirCtrl.text.trim(),
      ),
    );
    return true;
  }
}
