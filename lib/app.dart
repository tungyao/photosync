import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'presentation/pages/backup_page.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/media_selection_page.dart';

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
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomePage(),
        AppRoutes.selection: (_) => const MediaSelectionPage(),
        AppRoutes.backup: (_) => const BackupPage(),
      },
    );
  }
}
