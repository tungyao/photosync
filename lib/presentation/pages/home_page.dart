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
              title: const Text('1. 选择照片'),
              subtitle: const Text('浏览手机相册并选择需要备份的媒体'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.selection),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('2. 执行增量备份'),
              subtitle: const Text('仅上传新增或修改过的文件到 NAS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.backup),
            ),
          ),
        ],
      ),
    );
  }
}
