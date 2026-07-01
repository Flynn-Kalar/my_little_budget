import 'package:drift/drift.dart';

import 'notes.dart';

@DataClassName('NoteChecklistItem')
@TableIndex(name: 'idx_note_checklist_items_note', columns: {#noteId})
class NoteChecklistItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId =>
      integer().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemText =>
      text().named('text').withLength(min: 1, max: 200)();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
}
