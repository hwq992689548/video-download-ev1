import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'features/browser/browser_tab.dart';
import 'features/downloads/downloads_tab.dart';
import 'features/settings/settings_tab.dart';
import 'theme/app_theme.dart';

class VideoDownloadEv1App extends ConsumerStatefulWidget {
  const VideoDownloadEv1App({super.key});

  @override
  ConsumerState<VideoDownloadEv1App> createState() => _VideoDownloadEv1AppState();
}

class _VideoDownloadEv1AppState extends ConsumerState<VideoDownloadEv1App> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(videoLibrarySyncProvider);
    ref.watch(downloadManagerProvider);
    return MaterialApp(
      title: 'video_download_ev1',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            DownloadsTab(),
            BrowserTabScreen(),
            SettingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppColors.surface,
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            if (i == 0) {
              ref.invalidate(videoLibrarySyncProvider);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: '视频列表',
            ),
            NavigationDestination(
              icon: Icon(Icons.language_outlined),
              selectedIcon: Icon(Icons.language),
              label: '浏览器',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
