import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A selection belongs to the current query, and only contains its row IDs.
class TransactionSelection extends ChangeNotifier {
  final Set<int> _ids = {};
  bool active = false;
  bool busy = false;
  int? _anchor;

  Set<int> get ids => UnmodifiableSetView(_ids);
  bool contains(int id) => _ids.contains(id);

  void enter(int id) {
    if (busy) return;
    active = true;
    _ids.add(id);
    _anchor = id;
    notifyListeners();
  }

  void toggle(int id, {bool range = false, List<int> orderedIds = const []}) {
    if (!active || busy) return;
    final start = orderedIds.indexOf(_anchor ?? -1);
    final end = orderedIds.indexOf(id);
    if (range && start >= 0 && end >= 0) {
      _ids.addAll(
        orderedIds.sublist(
          start < end ? start : end,
          (start > end ? start : end) + 1,
        ),
      );
    } else {
      if (!_ids.remove(id)) _ids.add(id);
      _anchor = id;
    }
    notifyListeners();
  }

  void selectAll(Iterable<int> ids) {
    if (busy) return;
    _ids.addAll(ids);
    notifyListeners();
  }

  void clear() {
    if (busy) return;
    _ids.clear();
    _anchor = null;
    notifyListeners();
  }

  void exit() {
    if (busy) return;
    active = false;
    clear();
  }

  void setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  /// Called by the owner before rebuilding after a query/result change.
  void reconcile(Iterable<int> availableIds, {bool queryChanged = false}) {
    final available = availableIds.toSet();
    if (queryChanged || available.isEmpty) {
      active = false;
      _ids.clear();
      _anchor = null;
    } else {
      _ids.retainAll(available);
      if (!available.contains(_anchor)) _anchor = null;
    }
  }
}
