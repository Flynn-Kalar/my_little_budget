import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/notes/note_draft_store.dart';
import 'package:my_little_budget/features/notes/checklist.dart';

void main() {
  test(
    'drafts retain incomplete inputs without altering notes, checklists or reminders',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final id = await db.notesDao.saveNote(
        title: '원본',
        content: '본문',
        checklistItems: const [ChecklistItemDraft(text: '체크')],
      );
      final original = (await db.notesDao.getNote(id))!;
      final jobs = await db.customSelect('SELECT * FROM reminder_jobs').get();
      final store = NoteDraftStore(db);
      await store.write(
        noteId: null,
        baseUpdatedAt: null,
        payload: {'title': '', 'amount': '입력 중'},
      );
      await store.write(
        noteId: id,
        baseUpdatedAt: original.updatedAt,
        payload: {'title': '수정', 'rich': [], 'amount': '2,'},
      );
      expect(jsonDecode((await store.load(null))!.payload)['title'], '');
      expect(jsonDecode((await store.load(id))!.payload)['amount'], '2,');
      expect((await db.notesDao.getNote(id))!.toJson(), original.toJson());
      expect(
        (await db.notesDao.getNoteWithChecklist(id))!.items.single.isChecked,
        isFalse,
      );
      expect(
        (await db.customSelect('SELECT * FROM reminder_jobs').get()).map(
          (r) => r.data,
        ),
        jobs.map((r) => r.data),
      );
      await store.checkVersion(id, original.updatedAt);
      await db.notesDao.saveNote(id: id, title: '다른 편집', content: '새 본문');
      await expectLater(
        store.checkVersion(id, original.updatedAt),
        throwsA(isA<NoteEditConflict>()),
      );
      final backup = await db.backupDao.exportBackup();
      expect(backup.toJsonString(), isNot(contains('입력 중')));
      await db.backupDao.importBackup(backup);
      expect(await store.load(null), isNull);
      expect(await store.load(id), isNull);
    },
  );

  test(
    'v20 migrates safely and drafts survive reopening the database',
    () async {
      final directory = await Directory.systemTemp.createTemp('note_drafts_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/budget.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final id = await db.notesDao.saveNote(
        title: '기존 메모',
        content: '- 본문',
        pinned: true,
      );
      final original = (await db.notesDao.getNote(id))!;
      await db.customStatement('DROP TABLE note_drafts');
      await db.customStatement('PRAGMA user_version=20');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect((await db.notesDao.getNote(id))!.toJson(), original.toJson());
      await NoteDraftStore(db).write(
        noteId: id,
        baseUpdatedAt: original.updatedAt,
        payload: {'title': '복구할 초안'},
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          jsonDecode((await NoteDraftStore(db).load(id))!.payload)['title'],
          '복구할 초안',
        );
        await db.notesDao.deleteNote(id);
        expect(await NoteDraftStore(db).load(id), isNull);
      } finally {
        await db.close();
      }
    },
  );
}
