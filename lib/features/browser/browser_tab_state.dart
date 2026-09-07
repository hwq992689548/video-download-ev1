import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class BrowserTabState {
  BrowserTabState({
    required this.id,
    this.url = 'about:blank',
    this.title = '新标签页',
  });

  final String id;
  String url;
  String title;
}

class BrowserTabStore extends ChangeNotifier {
  BrowserTabStore() {
    addTab();
  }

  final _uuid = const Uuid();
  final List<BrowserTabState> _tabs = [];
  int _activeIndex = 0;

  List<BrowserTabState> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  BrowserTabState get activeTab => _tabs[_activeIndex];

  void addTab({String url = 'about:blank'}) {
    _tabs.add(BrowserTabState(id: _uuid.v4(), url: url));
    _activeIndex = _tabs.length - 1;
    notifyListeners();
  }

  void closeTab(int index) {
    if (_tabs.length == 1) {
      _tabs[0] = BrowserTabState(id: _uuid.v4());
      _activeIndex = 0;
      notifyListeners();
      return;
    }
    _tabs.removeAt(index);
    if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void selectTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void updateTab(String id, {String? url, String? title}) {
    final index = _tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (url != null) _tabs[index].url = url;
    if (title != null && title.isNotEmpty) _tabs[index].title = title;
    notifyListeners();
  }
}
