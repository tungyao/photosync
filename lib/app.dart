import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'presentation/pages/backup_page.dart';
import 'presentation/pages/album_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/settings_page.dart';
import 'presentation/pages/smb_setup_page.dart';

class PhotoSyncApp extends StatelessWidget {
  const PhotoSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      initialRoute: AppRoutes.album,
      routes: {
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.smbSetup: (_) => const SmbSetupPage(),
        AppRoutes.album: (_) => const AlbumPage(),
        AppRoutes.backup: (_) => const BackupPage(),
        AppRoutes.settings: (_) => const SettingsPage(),
      },
    );
  }
}
