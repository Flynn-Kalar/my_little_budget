import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';

void main() {
  test(
    'negative goal amounts survive database and backup round trips',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (final target in [3000000, -3000000]) {
        final id = await db.notesDao.saveNote(
          title: '음수 금액',
          content: '',
          amountGoal: Value(
            NoteAmountGoal(
              targetAmount: target,
              currentAmount: -24500,
              startDate: DateTime(2026),
            ),
          ),
        );
        final backup = parseBackup(
          (await db.backupDao.exportBackup()).toJsonString(),
        );
        expect(backup.error, isNull);
        await db.backupDao.importBackup(backup.backup!);
        final restored = NoteAmountGoal.fromNote(
          (await db.notesDao.getNote(id))!,
        )!;
        expect(restored.targetAmount, target);
        expect(restored.currentAmount, -24500);
      }
    },
  );
  test(
    'normal notes and goals round-trip, edits preserve omitted goals and backup data',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final normalId = await db.notesDao.saveNote(
        title: '일반',
        content: '기존 내용',
      );
      expect((await db.notesDao.getNote(normalId))!.goalTargetAmount, isNull);
      final goalId = await db.notesDao.saveNote(
        title: '복구',
        content: '본문',
        amountGoal: Value(
          NoteAmountGoal(
            targetAmount: 2681630,
            currentAmount: 1400000,
            startDate: DateTime(2026, 10, 2),
            dueDate: DateTime(2026, 12, 31),
          ),
        ),
      );
      await db.notesDao.saveNote(id: goalId, title: '제목 수정', content: '수정 본문');
      final goal = NoteAmountGoal.fromNote(
        (await db.notesDao.getNote(goalId))!,
      )!;
      expect(goal.percentage, '52.2%');
      expect(goal.dueDate, DateTime(2026, 12, 31));
      final backup = parseBackup(
        (await db.backupDao.exportBackup()).toJsonString(),
      );
      expect(backup.error, isNull);
      await db.backupDao.importBackup(backup.backup!);
      expect((await db.notesDao.getNote(goalId))!.goalCurrentAmount, 1400000);
      expect((await db.notesDao.getNote(normalId))!.content, '기존 내용');
      await db.notesDao.saveNote(
        id: goalId,
        title: '일반으로 변경',
        content: '유지',
        amountGoal: const Value(null),
      );
      expect((await db.notesDao.getNote(goalId))!.goalTargetAmount, isNull);
      await expectLater(
        db.notesDao.saveNote(
          title: '잘못된 목표',
          content: '',
          amountGoal: Value(
            NoteAmountGoal(
              targetAmount: 0,
              currentAmount: 0,
              startDate: DateTime(2026),
            ),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'v18 migration retains IDs, content, rich text, checklists and dates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'note_goal_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/budget.sqlite');
      final oldDb = AppDatabase.forTesting(NativeDatabase(file));
      const rich =
          '[{"insert":"기존"},{"insert":"\\n","attributes":{"list":"unchecked"}}]';
      final id = await oldDb.notesDao.saveNote(
        title: '기존 메모',
        content: '기존',
        richContent: rich,
        pinned: true,
      );
      final original = (await oldDb.notesDao.getNote(id))!;
      // Reconstruct v18 before it had the v25 note-content sync triggers.
      await oldDb.customStatement(
        'DROP TRIGGER IF EXISTS notes_sync_content_update',
      );
      await oldDb.customStatement('DROP TRIGGER IF EXISTS sync_notes_update');
      for (final column in [
        'goal_target_amount',
        'goal_current_amount',
        'goal_start_date',
        'goal_due_date',
      ]) {
        await oldDb.customStatement('ALTER TABLE notes DROP COLUMN $column');
      }
      await oldDb.customStatement('PRAGMA user_version = 18');
      await oldDb.close();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final entry = (await db.notesDao.getNoteWithChecklist(id))!;
        expect(entry.note.title, original.title);
        expect(entry.note.content, original.content);
        expect(entry.note.richContent, rich);
        expect(entry.note.createdAt, original.createdAt);
        expect(entry.note.updatedAt, original.updatedAt);
        expect(entry.note.pinned, isTrue);
        expect(entry.items.single.itemText, '기존');
        expect(entry.note.goalTargetAmount, isNull);
        await db.notesDao.saveNote(id: id, title: '기존 수정', content: '수정');
        expect((await db.notesDao.getNote(id))!.content, '수정');
      } finally {
        await db.close();
      }
    },
  );
}
