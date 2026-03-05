import 'package:flutter/material.dart';

import '../../core/constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PhotoSync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('SMB 配置'),
              subtitle: const Text('配置 NAS 地址、账号、共享目录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.smbSetup),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('相册浏览'),
              subtitle: const Text('网格分页加载，支持多选与全选'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.album),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('备份任务'),
              subtitle: const Text('选择模式、起始时间并执行备份'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('设置'),
              subtitle: const Text('并发数与远端存在跳过策略'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
            ),
          ),
        ],
      ),
    );
  }
}
