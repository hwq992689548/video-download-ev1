import 'package:flutter/material.dart';

import 'mobile_browser_config.dart';

const _defaultUrl = 'https://www.beegoedu.com/';

class AddressBar extends StatefulWidget {
  const AddressBar({
    super.key,
    required this.currentUrl,
    required this.onSubmit,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onRefresh,
    required this.onBookmarks,
    required this.onSniff,
    required this.sniffCount,
  });

  final String currentUrl;
  final ValueChanged<String> onSubmit;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onRefresh;
  final VoidCallback onBookmarks;
  final VoidCallback onSniff;
  final int sniffCount;

  @override
  State<AddressBar> createState() => _AddressBarState();
}

class _AddressBarState extends State<AddressBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUrl);
  }

  @override
  void didUpdateWidget(covariant AddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUrl != widget.currentUrl &&
        _controller.text != widget.currentUrl) {
      _controller.text = widget.currentUrl;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    var text = _controller.text.trim();
    if (text.isEmpty) {
      text = _defaultUrl;
    } else if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    widget.onSubmit(text);
    FocusScope.of(context).unfocus();
  }

  Widget _navButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed,
    );
  }

  Widget _urlField({bool compact = false}) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.go,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: _defaultUrl,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
        ),
        isDense: true,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 20 : 8),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 12,
          vertical: compact ? 8 : 10,
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _sniffButton({bool compact = false}) {
    final button = FilledButton.tonal(
      onPressed: widget.onSniff,
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 6 : 8,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '探测链接',
        style: TextStyle(fontSize: compact ? 12 : 14),
      ),
    );

    return Badge(
      isLabelVisible: widget.sniffCount > 0,
      label: Text('${widget.sniffCount}'),
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = shouldUseMobileBrowserMode(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 4 : 8, 8, compact ? 4 : 8, 4),
      child: compact ? _buildCompactLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildCompactLayout() {
    return Row(
      children: [
        _navButton(
          icon: Icons.arrow_back,
          tooltip: '后退',
          onPressed: widget.canGoBack ? widget.onBack : null,
        ),
        _navButton(
          icon: Icons.arrow_forward,
          tooltip: '前进',
          onPressed: widget.canGoForward ? widget.onForward : null,
        ),
        _navButton(
          icon: Icons.refresh,
          tooltip: '刷新',
          onPressed: widget.onRefresh,
        ),
        Expanded(child: _urlField(compact: true)),
        _sniffButton(compact: true),
        PopupMenuButton<String>(
          tooltip: '更多',
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'bookmarks',
              child: ListTile(
                leading: Icon(Icons.bookmarks_outlined),
                title: Text('书签'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'go',
              child: ListTile(
                leading: Icon(Icons.arrow_forward),
                title: Text('前往'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'bookmarks':
                widget.onBookmarks();
              case 'go':
                _submit();
            }
          },
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Row(
          children: [
            _navButton(
              icon: Icons.arrow_back,
              onPressed: widget.canGoBack ? widget.onBack : null,
            ),
            _navButton(
              icon: Icons.arrow_forward,
              onPressed: widget.canGoForward ? widget.onForward : null,
            ),
            _navButton(
              icon: Icons.refresh,
              onPressed: widget.onRefresh,
            ),
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: '书签',
              onPressed: widget.onBookmarks,
            ),
            _sniffButton(),
          ],
        ),
        Row(
          children: [
            Expanded(child: _urlField()),
            const SizedBox(width: 8),
            FilledButton(onPressed: _submit, child: const Text('前往')),
          ],
        ),
      ],
    );
  }
}
