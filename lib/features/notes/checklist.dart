import '../../data/database.dart';

class ChecklistItemDraft {
  const ChecklistItemDraft({
    this.id,
    required this.text,
    this.isChecked = false,
  });

  final int? id;
  final String text;
  final bool isChecked;
}

class NoteWithChecklist {
  const NoteWithChecklist({required this.note, required this.items});

  final Note note;
  final List<NoteChecklistItem> items;

  bool get hasChecklist => items.isNotEmpty;
  int get checkedCount => items.where((item) => item.isChecked).length;
  int get totalCount => items.length;
  bool get hasIncompleteItems => items.any((item) => !item.isChecked);
  bool get isChecklistComplete => items.isNotEmpty && !hasIncompleteItems;
}

List<ChecklistItemDraft> normalizeChecklistItems(
  Iterable<ChecklistItemDraft> items,
) {
  final normalized = items
      .map(
        (item) => ChecklistItemDraft(
          id: item.id,
          text: item.text.trim(),
          isChecked: item.isChecked,
        ),
      )
      .where((item) => item.text.isNotEmpty)
      .toList();
  if (normalized.length > 100) {
    throw ArgumentError('체크 항목은 최대 100개까지 추가할 수 있습니다.');
  }
  final tooLong = normalized.where((item) => item.text.length > 200);
  if (tooLong.isNotEmpty) {
    throw ArgumentError('체크 항목은 200자 이하여야 합니다.');
  }
  return normalized;
}
