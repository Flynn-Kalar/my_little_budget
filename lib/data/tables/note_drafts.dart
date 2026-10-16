import 'package:drift/drift.dart';

import 'notes.dart';

/// Local recovery data, deliberately separate from saved notes and backups.
@DataClassName('NoteDraftRecord')
class NoteDrafts extends Table {
  TextColumn get draftKey => text()();
  IntColumn get noteId => integer().nullable().references(
    Notes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get baseUpdatedAt => text().nullable()();
  TextColumn get payload => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column> get primaryKey => {draftKey};
}
