import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'browser_tab_state.dart';
import 'mobile_browser_config.dart';

final browserTabStoreProvider =
    ChangeNotifierProvider<BrowserTabStore>((ref) => BrowserTabStore());

class BrowserTabBar extends ConsumerWidget {
  const BrowserTabBar({
    super.key,
    this.onSniff,
    this.sniffCount = 0,
  });

  final VoidCallback? onSniff;
  final int sniffCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(browserTabStoreProvider);
    final tabs = store.tabs;
    final compact = shouldUseMobileBrowserMode(context);
    final showSniff = compact && onSniff != null;

    return SizedBox(
      height: compact ? 40 : 44,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: showSniff ? 12 : 0),
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < tabs.length; index++)
                        _TabChip(
                          tab: tabs[index],
                          compact: compact,
                          selected: index == store.activeIndex,
                          onPressed: () => ref
                              .read(browserTabStoreProvider.notifier)
                              .selectTab(index),
                          onDeleted: tabs.length > 1
                              ? () => ref
                                  .read(browserTabStoreProvider.notifier)
                                  .closeTab(index)
                              : null,
                        ),
                      IconButton(
                        tooltip: '新标签页',
                        icon: const Icon(Icons.add),
                        visualDensity: compact
                            ? VisualDensity.compact
                            : VisualDensity.standard,
                        onPressed: () =>
                            ref.read(browserTabStoreProvider.notifier).addTab(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showSniff)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Badge(
                isLabelVisible: sniffCount > 0,
                backgroundColor: AppColors.error,
                label: Text('$sniffCount'),
                child: FilledButton(
                  onPressed: onSniff,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '探测链接',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.compact,
    required this.selected,
    required this.onPressed,
    required this.onDeleted,
  });

  final BrowserTabState tab;
  final bool compact;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 4,
        vertical: compact ? 4 : 6,
      ),
      child: InputChip(
        label: Text(
          tab.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.fillRegular,
        selectedColor: AppColors.theme.withValues(alpha: 0.55),
        checkmarkColor: AppColors.textPrimary,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        materialTapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        selected: selected,
        onPressed: onPressed,
        onDeleted: onDeleted,
        deleteIcon: Icon(Icons.close, size: compact ? 14 : 16),
      ),
    );
  }
}
