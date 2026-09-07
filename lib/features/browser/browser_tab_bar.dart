import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_tab_state.dart';
import 'mobile_browser_config.dart';

final browserTabStoreProvider =
    ChangeNotifierProvider<BrowserTabStore>((ref) => BrowserTabStore());

class BrowserTabBar extends ConsumerWidget {
  const BrowserTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(browserTabStoreProvider);
    final tabs = store.tabs;
    final compact = shouldUseMobileBrowserMode(context);

    return SizedBox(
      height: compact ? 40 : 44,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = index == store.activeIndex;
                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 2 : 4,
                    vertical: compact ? 4 : 6,
                  ),
                  child: InputChip(
                    label: Text(
                      tab.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 12 : 14),
                    ),
                    labelStyle: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                    visualDensity:
                        compact ? VisualDensity.compact : VisualDensity.standard,
                    materialTapTargetSize: compact
                        ? MaterialTapTargetSize.shrinkWrap
                        : MaterialTapTargetSize.padded,
                    selected: selected,
                    onPressed: () =>
                        ref.read(browserTabStoreProvider.notifier).selectTab(index),
                    onDeleted: tabs.length > 1
                        ? () => ref
                            .read(browserTabStoreProvider.notifier)
                            .closeTab(index)
                        : null,
                    deleteIcon: Icon(Icons.close, size: compact ? 14 : 16),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: '新标签页',
            icon: const Icon(Icons.add),
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
            onPressed: () => ref.read(browserTabStoreProvider.notifier).addTab(),
          ),
        ],
      ),
    );
  }
}
