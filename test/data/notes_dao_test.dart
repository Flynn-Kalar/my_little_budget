import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/notes/checklist.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('체크 항목 추가·수정·삭제·재정렬과 cascade 삭제를 지원한다', () async {
    final id = await db.notesDao.saveNote(
      title: '미션 메모',
      content: '내용',
      checklistItems: const [
        ChecklistItemDraft(text: '첫 번째'),
        ChecklistItemDraft(text: '두 번째'),
      ],
    );
    var entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.items.map((item) => item.itemText), ['첫 번째', '두 번째']);

    final first = entry.items[0];
    final second = entry.items[1];
    await db.notesDao.saveNote(
      id: id,
      title: '미션 메모',
      content: '수정 내용',
      checklistItems: [
        ChecklistItemDraft(id: second.id, text: '두 번째 수정', isChecked: true),
        ChecklistItemDraft(id: first.id, text: first.itemText),
        const ChecklistItemDraft(text: '세 번째'),
      ],
    );

    entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.items.map((item) => item.itemText), [
      '두 번째 수정',
      '첫 번째',
      '세 번째',
    ]);
    expect(entry.items.first.isChecked, isTrue);

    await db.notesDao.reorderChecklistItems(
      id,
      entry.items.reversed.map((item) => item.id).toList(),
    );
    entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.items.first.itemText, '세 번째');

    await db.notesDao.deleteNote(id);
    final count = await db
        .customSelect('SELECT COUNT(*) AS total FROM note_checklist_items')
        .getSingle();
    expect(count.read<int>('total'), 0);
  });

  test('항목 토글이 진행률 집계를 즉시 변경한다', () async {
    final id = await db.notesDao.saveNote(
      title: '진행률',
      content: '',
      checklistItems: const [
        ChecklistItemDraft(text: 'A'),
        ChecklistItemDraft(text: 'B'),
      ],
    );
    var entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.checkedCount, 0);
    expect(entry.hasIncompleteItems, isTrue);

    await db.notesDao.toggleChecklistItem(entry.items.first.id, true);
    entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.checkedCount, 1);
    expect(entry.isChecklistComplete, isFalse);

    await db.notesDao.toggleChecklistItem(entry.items.last.id, true);
    entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.isChecklistComplete, isTrue);
  });

  test('기한이 지난 미완료 체크리스트 메모만 배지로 센다', () async {
    final now = DateTime.utc(2026, 6, 21, 12);
    await db.notesDao.saveNote(
      title: '지난 알림',
      content: '',
      reminderAt: now.subtract(const Duration(minutes: 1)),
      checklistItems: const [ChecklistItemDraft(text: '미완료')],
    );
    await db.notesDao.saveNote(
      title: '미래 알림',
      content: '',
      reminderAt: now.add(const Duration(minutes: 1)),
      checklistItems: const [ChecklistItemDraft(text: '미완료')],
    );
    await db.notesDao.saveNote(
      title: '완료 알림',
      content: '',
      reminderAt: now.subtract(const Duration(minutes: 2)),
      checklistItems: const [ChecklistItemDraft(text: '완료', isChecked: true)],
    );
    await db.notesDao.saveNote(
      title: '알림 전용',
      content: '',
      reminderAt: now.subtract(const Duration(minutes: 2)),
    );

    expect(await db.notesDao.pendingReminderCount(now), 1);
  });

  test('빈 제목과 체크리스트 제한을 검증한다', () async {
    expect(
      () => db.notesDao.saveNote(title: '  ', content: ''),
      throwsArgumentError,
    );
    expect(
      () => db.notesDao.saveNote(
        title: '제한',
        content: '',
        checklistItems: List.generate(
          101,
          (index) => ChecklistItemDraft(text: '$index'),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('지난 반복 주기에서 모든 체크 항목을 초기화한다', () async {
    final id = await db.notesDao.saveNote(
      title: '일일 미션',
      content: '',
      schedule: const NoteScheduleDraft(
        type: NoteScheduleType.daily,
        resetTime: '06:00',
      ),
      checklistItems: const [
        ChecklistItemDraft(text: 'A', isChecked: true),
        ChecklistItemDraft(text: 'B', isChecked: true),
      ],
    );
    await db.customStatement(
      'UPDATE notes SET next_reset_at = ? WHERE id = ?',
      [DateTime.utc(2026, 6, 20, 21).toIso8601String(), id],
    );

    final changed = await db.notesDao.reconcileRecurringNotes(
      DateTime(2026, 6, 21, 7),
    );
    final entry = await db.notesDao.getNoteWithChecklist(id);

    expect(changed, 1);
    expect(entry!.items.every((item) => !item.isChecked), isTrue);
    expect(DateTime.parse(entry.note.nextResetAt!).toLocal().hour, 6);
    expect(DateTime.parse(entry.note.nextResetAt!).toLocal().day, 22);
  });

  test('반복 알림 전용 메모는 배지에서 제외한다', () async {
    const schedule = NoteScheduleDraft(
      type: NoteScheduleType.weekly,
      resetTime: '00:00',
      weekday: DateTime.monday,
    );
    await db.notesDao.saveNote(title: '알림 전용', content: '', schedule: schedule);
    await db.notesDao.saveNote(
      title: '주간 미션',
      content: '',
      schedule: schedule,
      checklistItems: const [ChecklistItemDraft(text: '미완료')],
    );
    expect(await db.notesDao.pendingReminderCount(DateTime.now()), 1);
  });
  test('rich delta content mirrors checklist table on save and toggle', () async {
    const richContent =
        '[{"insert":"Body\\nAlpha"},{"insert":"\\n","attributes":{"list":"unchecked"}},{"insert":"Beta"},{"insert":"\\n","attributes":{"list":"checked"}}]';

    final id = await db.notesDao.saveNote(
      title: 'Rich note',
      content: 'Body\nAlpha\nBeta',
      richContent: richContent,
    );

    var entry = await db.notesDao.getNoteWithChecklist(id);
    expect(entry!.note.richContent, richContent);
    expect(entry.note.content, 'Body\nAlpha\nBeta');
    expect(entry.items.map((item) => item.itemText), ['Alpha', 'Beta']);
    expect(entry.items.map((item) => item.isChecked), [false, true]);

    await db.notesDao.toggleChecklistItem(entry.items.first.id, true);
    entry = await db.notesDao.getNoteWithChecklist(id);
    final checklistStates = _checklistStates(entry!.note.richContent!);
    expect(checklistStates, ['checked', 'checked']);
  });

  test('recurring reset unchecks rich delta checklist lines', () async {
    const richContent =
        '[{"insert":"Alpha"},{"insert":"\\n","attributes":{"list":"checked"}},{"insert":"Beta"},{"insert":"\\n","attributes":{"list":"checked"}}]';
    final id = await db.notesDao.saveNote(
      title: 'Rich reset',
      content: 'Alpha\nBeta',
      richContent: richContent,
      schedule: const NoteScheduleDraft(
        type: NoteScheduleType.daily,
        resetTime: '06:00',
      ),
    );
    await db.customStatement(
      'UPDATE notes SET next_reset_at = ? WHERE id = ?',
      [DateTime.utc(2026, 6, 20, 21).toIso8601String(), id],
    );

    final changed = await db.notesDao.reconcileRecurringNotes(
      DateTime(2026, 6, 21, 7),
    );
    final entry = await db.notesDao.getNoteWithChecklist(id);

    expect(changed, 1);
    expect(entry!.items.every((item) => !item.isChecked), isTrue);
    expect(_checklistStates(entry.note.richContent!), [
      'unchecked',
      'unchecked',
    ]);
  });
}

List<String> _checklistStates(String richContent) {
  final ops = jsonDecode(richContent) as List<dynamic>;
  return [
    for (final op in ops)
      if (op case {'attributes': {'list': final String state}}) state,
  ];
}
