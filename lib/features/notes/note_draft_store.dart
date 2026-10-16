import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database.dart';

class NoteEditConflict implements Exception {
  const NoteEditConflict();
}

class NoteDraftStore {
  NoteDraftStore(this.db);
  final AppDatabase db;

  String keyFor(int? noteId) => noteId == null ? 'new' : 'note:$noteId';

  Future<NoteDraftRecord?> load(int? noteId) => (db.select(
    db.noteDrafts,
  )..where((row) => row.draftKey.equals(keyFor(noteId)))).getSingleOrNull();

  Future<void> write({
    required int? noteId,
    required String? baseUpdatedAt,
    required Map<String, dynamic> payload,
  }) async {
    await db
        .into(db.noteDrafts)
        .insertOnConflictUpdate(
          NoteDraftsCompanion.insert(
            draftKey: keyFor(noteId),
            noteId: Value(noteId),
            baseUpdatedAt: Value(baseUpdatedAt),
            payload: jsonEncode(payload),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
  }

  Future<void> delete(int? noteId) async {
    await (db.delete(
      db.noteDrafts,
    )..where((row) => row.draftKey.equals(keyFor(noteId)))).go();
  }

  /// Call inside the same transaction as the final save to prevent stale edits
  /// replacing a checklist toggle or a newer edit in another screen.
  Future<void> checkVersion(int? noteId, String? baseUpdatedAt) async {
    if (noteId == null) return;
    final current = await db.notesDao.getNote(noteId);
    if (current == null || current.updatedAt != baseUpdatedAt) {
      throw const NoteEditConflict();
    }
  }
}
