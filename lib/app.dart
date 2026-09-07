import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/browser/browser_tab.dart';
import 'features/downloads/downloads_tab.dart';
import 'features/test/test_download_page.dart';

class VideoDownloadEv1App extends ConsumerStatefulWidget {
  const VideoDownloadEv1App({super.key});

  @override
  ConsumerState<VideoDownloadEv1App> createState() => _VideoDownloadEv1AppState();
}

class _VideoDownloadEv1AppState extends ConsumerState<VideoDownloadEv1App> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'video_download_ev1',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: switch (_index) {
          0 => const DownloadsTab(),
          1 => const BrowserTabScreen(),
          _ => const TestDownloadPage(),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.download_outlined),
              selectedIcon: Icon(Icons.download),
              label: '下载',
            ),
            NavigationDestination(
              icon: Icon(Icons.language_outlined),
              selectedIcon: Icon(Icons.language),
              label: '浏览器',
            ),
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: '测试',
            ),
          ],
        ),
      ),
    );
  }
}
