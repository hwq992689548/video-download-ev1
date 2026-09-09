import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

Future<bool> confirmDeleteSelected(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('确认删除'),
      content: Text(count == 1 ? '删除选中的 1 项？' : '删除选中的 $count 项？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result == true;
}

class SelectionModeButtons extends StatelessWidget {
  const SelectionModeButtons({
    super.key,
    required this.selecting,
    required this.canSelect,
    required this.allSelected,
    required this.hasSelection,
    required this.onEnter,
    required this.onSelectAll,
    required this.onDelete,
  });

  final bool selecting;
  final bool canSelect;
  final bool allSelected;
  final bool hasSelection;
  final VoidCallback onEnter;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final compact = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minimumSize: const Size(0, 40),
    );
    if (!selecting) {
      return TextButton(
        onPressed: canSelect ? onEnter : null,
        style: compact,
        child: const Text('选择'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: canSelect ? onSelectAll : null,
          style: compact,
          child: Text(allSelected ? '取消全选' : '全选'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: hasSelection ? onDelete : null,
          style: compact.copyWith(
            foregroundColor: WidgetStateProperty.all(AppColors.error),
          ),
          child: const Text('删除'),
        ),
      ],
    );
  }
}
