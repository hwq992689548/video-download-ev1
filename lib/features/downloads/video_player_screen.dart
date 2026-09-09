import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/reveal_in_file_manager.dart';
import '../../data/database.dart';
import '../../data/repositories/repositories.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.video});

  final VideoRecord video;

  static Future<void> playWithSystemPlayer(
    BuildContext context,
    VideoRecord video,
  ) async {
    final file = File(video.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在，可能已被删除')),
        );
      }
      return;
    }

    final result = await OpenFilex.open(file.path, type: _mimeType(file.path));
    if (result.type == ResultType.done || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: video),
      ),
    );
  }

  static String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    return 'video/*';
  }

  static Future<void> shareVideo(BuildContext context, VideoRecord video) async {
    final file = File(video.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在，可能已被删除')),
        );
      }
      return;
    }
    await Share.shareXFiles(
      [XFile(video.filePath, name: video.displayName)],
      subject: video.displayName,
    );
  }

  static Future<void> revealInFileManager(
    BuildContext context,
    VideoRecord video,
  ) async {
    final file = File(video.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在，可能已被删除')),
        );
      }
      return;
    }

    final ok = await RevealInFileManager.reveal(video.filePath);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开文件所在目录')),
      );
    }
  }

  static Future<void> deleteVideo(
    VideoRecord video,
    VideoRepository repo,
  ) async {
    final file = File(video.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await repo.deleteById(video.id);
  }

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.video.filePath), play: true);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.displayName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => VideoPlayerScreen.shareVideo(context, widget.video),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '打开所在目录',
            onPressed: () =>
                VideoPlayerScreen.revealInFileManager(context, widget.video),
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Video(
            controller: _controller,
            controls: AdaptiveVideoControls,
          ),
        ),
      ),
    );
  }
}
