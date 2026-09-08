import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';

class BookmarksSheet extends ConsumerWidget {
  const BookmarksSheet({
    super.key,
    required this.currentUrl,
    required this.currentTitle,
    required this.onNavigate,
  });

  final String currentUrl;
  final String currentTitle;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(bookmarkRepositoryProvider);
    const uuid = Uuid();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Column(
          children: [
            ListTile(
              title: Text(
                '书签',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('添加当前页'),
                onPressed: () async {
                  if (currentUrl.isEmpty || currentUrl == 'about:blank') return;
                  await repo.insert(
                    BookmarksCompanion.insert(
                      id: uuid.v4(),
                      title: currentTitle.isEmpty ? currentUrl : currentTitle,
                      url: currentUrl,
                      createdAt: DateTime.now(),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已添加书签')),
                    );
                  }
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Bookmark>>(
                stream: repo.watchAll(),
                builder: (context, snapshot) {
                  final bookmarks = snapshot.data ?? [];
                  if (bookmarks.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无书签',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = bookmarks[index];
                      return ListTile(
                        title: Text(bookmark.title),
                        subtitle: Text(
                          bookmark.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onNavigate(bookmark.url);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => repo.deleteById(bookmark.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
