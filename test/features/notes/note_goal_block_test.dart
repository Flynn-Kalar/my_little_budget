import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';
import 'package:my_little_budget/features/notes/rich_note.dart';

void main() {
  test(
    'multiple goal blocks coexist with text and checklist, edit by identity, undo and round-trip',
    () {
      final c = QuillController(
        document: Document.fromJson([
          {'insert': '앞 문장\n입금 확인'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': '뒤 문장\n'},
        ]),
        selection: const TextSelection.collapsed(offset: 5),
      );
      addTearDown(c.dispose);
      final a = newNoteGoalBlock(
        '비상금',
        NoteAmountGoal(
          targetAmount: 2681630,
          currentAmount: 1400000,
          startDate: DateTime(2026, 10, 1),
        ),
      );
      insertNoteGoalBlock(c, a);
      c.updateSelection(
        TextSelection.collapsed(offset: c.document.length - 1),
        ChangeSource.local,
      );
      final b = newNoteGoalBlock(
        '여행',
        NoteAmountGoal(
          targetAmount: 100000,
          currentAmount: 200000,
          startDate: DateTime(2026, 10, 1),
        ),
      );
      insertNoteGoalBlock(c, b);
      expect(
        plainTextFromDocument(c.document),
        contains('1,400,000 / 2,681,630원 (52.2%)'),
      );
      expect(plainTextFromDocument(c.document), contains('100.0%'));
      expect(checklistFromDocument(c.document).single.text, '입금 확인');
      final encoded = encodeDocument(c.document);
      final reopened = Document.fromJson(c.document.toDelta().toJson());
      expect(encodeDocument(reopened), encoded);
      expect(plainTextFromDocument(reopened), contains('뒤 문장'));
      replaceNoteGoalBlock(
        c,
        a.id,
        NoteGoalBlock(
          id: a.id,
          title: '비상금 수정',
          goal: NoteAmountGoal(
            targetAmount: 2681630,
            currentAmount: 1800000,
            startDate: DateTime(2026, 10, 1),
          ),
        ),
      );
      expect(plainTextFromDocument(c.document), contains('1,800,000'));
      expect(plainTextFromDocument(c.document), contains('여행'));
      expect(replaceNoteGoalBlock(c, 'missing', null), isFalse);
      c.document.history.clear();
      replaceNoteGoalBlock(c, a.id, null);
      expect(plainTextFromDocument(c.document), isNot(contains('비상금')));
      expect(checklistFromDocument(c.document).single.text, '입금 확인');
      expect(plainTextFromDocument(c.document), contains('앞 문장'));
      c.undo();
      expect(plainTextFromDocument(c.document), contains('비상금 수정'));
      c.redo();
      expect(plainTextFromDocument(c.document), isNot(contains('비상금 수정')));
    },
  );
}
