/// Freeze a chooser's order while the user is interacting with it.
/// Changing category starts a new order; selected tags never move to the top.
class TagSuggestionOrder {
  Object? _context;
  List<String> _names = [];
  bool _locked = false;

  void lock() => _locked = true;
  void unlock() => _locked = false;

  List<String> resolve(List<String> suggestions, Object? context) {
    if (_context != context) {
      _context = context;
      _locked = false;
    }
    final available = suggestions.toSet();
    _names = _locked
        ? [
            ..._names.where(available.contains),
            ...suggestions.where((name) => !_names.contains(name)),
          ]
        : List.of(suggestions);
    return List.unmodifiable(_names);
  }
}
