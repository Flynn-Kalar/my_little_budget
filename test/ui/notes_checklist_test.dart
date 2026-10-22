import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/desktop/notes/notes_screen.dart';
import 'package:my_little_budget/ui/mobile/notes/mobile_notes_screen.dart';
import 'package:my_little_budget/ui/shared/rich_note_editor.dart';
import 'package:my_little_budget/ui/shared/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';
import 'package:my_little_budget/features/notes/rich_note.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  Future<AppDatabase> pumpNotesScreen(
    WidgetTester tester, {
    required bool mobile,
  }) async {
    await tester.binding.setSurfaceSize(
      mobile ? const Size(390, 844) : const Size(1200, 900),
    );
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko'), Locale('en')],
          home: Scaffold(
            body: mobile ? const MobileNotesScreen() : const NotesScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  Future<void> seedRichChecklistNote(AppDatabase db) async {
    const richContent =
        '[{"insert":"Memo body\\nAlpha"},{"insert":"\\n","attributes":{"list":"unchecked"}}]';
    await db.notesDao.saveNote(
      title: 'Rich checklist',
      content: 'Memo body\nAlpha',
      richContent: richContent,
    );
  }

  Future<void> verifyRichChecklistViewer(
    WidgetTester tester,
    AppDatabase db,
  ) async {
    await seedRichChecklistNote(db);
    await tester.pumpAndSettle();

    expect(find.text('Rich checklist'), findsOneWidget);
    expect(find.text('0/1 완료'), findsOneWidget);

    await tester.tap(find.text('Rich checklist'));
    await tester.pumpAndSettle();
    expect(find.byType(RichNoteViewer), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    final checkbox = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'QuillCheckboxPoint',
    );
    expect(checkbox, findsOneWidget);
    final checkboxTapTarget = find.descendant(
      of: checkbox,
      matching: find.byType(InkWell),
    );
    expect(checkboxTapTarget, findsOneWidget);

    await tester.tap(checkboxTapTarget);
    await tester.pumpAndSettle();
    final toggledEntry = (await db.notesDao.getNoteWithChecklist(1))!;
    expect(toggledEntry.items.single.isChecked, isTrue);
    final closeText = find.text('닫기');
    await tester.tap(
      closeText.evaluate().isNotEmpty
          ? closeText
          : find.byType(BackButton).evaluate().isNotEmpty
          ? find.byType(BackButton)
          : find.byIcon(Icons.close),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/1 완료'), findsOneWidget);
  }

  testWidgets('desktop notes render rich checklist document and progress', (
    tester,
  ) async {
    final db = await pumpNotesScreen(tester, mobile: false);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await verifyRichChecklistViewer(tester, db);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  testWidgets('mobile notes render rich checklist document and progress', (
    tester,
  ) async {
    final db = await pumpNotesScreen(tester, mobile: true);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await verifyRichChecklistViewer(tester, db);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  testWidgets('opening a note for edit shows the rich editor toolbar', (
    tester,
  ) async {
    final db = await pumpNotesScreen(tester, mobile: true);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seedRichChecklistNote(db);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rich checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(RichNoteEditor), findsOneWidget);
    expect(find.byTooltip('실행 취소'), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsOneWidget);
    await tester.tap(find.byTooltip('글자·서식 더보기'));
    await tester.pumpAndSettle();
    expect(find.text('18 pt'), findsOneWidget);
    expect(find.byIcon(Icons.format_bold), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} converts legacy goals only on save',
      (tester) async {
        final db = await pumpNotesScreen(tester, mobile: mobile);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(db.close);
        final id = await db.notesDao.saveNote(
          title: '기존 목표',
          content: '유지할 본문',
          amountGoal: Value(
            NoteAmountGoal(
              targetAmount: 2000000,
              currentAmount: 500000,
              startDate: DateTime(2026, 1, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('기존 목표'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        expect(find.text('메모 유형'), findsNothing);
        expect(find.byType(NoteGoalForm), findsNothing);
        var editor = tester.widget<RichNoteEditor>(find.byType(RichNoteEditor));
        expect(
          plainTextFromDocument(editor.controller.document),
          contains('유지할 본문'),
        );
        expect(
          plainTextFromDocument(editor.controller.document),
          contains('500,000 / 2,000,000원'),
        );
        expect((await db.notesDao.getNote(id))!.goalTargetAmount, 2000000);
        await tester.ensureVisible(find.text('취소'));
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect((await db.notesDao.getNote(id))!.richContent, isNull);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        editor = tester.widget<RichNoteEditor>(find.byType(RichNoteEditor));
        final op = editor.controller.document
            .toDelta()
            .toList()
            .where((o) => o.data is Map)
            .single;
        final block = NoteGoalBlock.decode(
          (op.data as Map)[noteGoalBlockType],
        )!;
        replaceNoteGoalBlock(
          editor.controller,
          block.id,
          NoteGoalBlock(
            id: block.id,
            title: '변환한 목표',
            goal: NoteAmountGoal(
              targetAmount: 2000000,
              currentAmount: -1000,
              startDate: block.goal.startDate,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('저장'));
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        final saved = (await db.notesDao.getNote(id))!;
        expect(saved.goalTargetAmount, isNull);
        expect(saved.richContent, contains('budget-goal'));
        final restored = documentForUnifiedNoteEditor(saved);
        expect(
          restored.toDelta().toList().where((o) => o.data is Map),
          hasLength(1),
        );
        expect(
          plainTextFromDocument(restored),
          contains('-1,000 / 2,000,000원'),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} orders notes inline within pin groups',
      (tester) async {
        final db = await pumpNotesScreen(tester, mobile: mobile);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(db.close);
        final a = await db.notesDao.saveNote(
          title: '고정 A',
          content: '',
          pinned: true,
        );
        final b = await db.notesDao.saveNote(
          title: '고정 B',
          content: '',
          pinned: true,
        );
        final c = await db.notesDao.saveNote(title: '일반 C', content: '');
        final d = await db.notesDao.saveNote(title: '일반 D', content: '');
        await db.notesDao.updateNoteOrder(true, [a, b]);
        await db.notesDao.updateNoteOrder(false, [c, d]);
        await tester.pumpAndSettle();
        Future<void> tap(Finder f) async {
          await tester.ensureVisible(f);
          await tester.pumpAndSettle();
          await tester.tap(f);
          await tester.pumpAndSettle();
        }

        Finder key(String value) => find.byKey(ValueKey(value));
        await tap(key('notes-order-button'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          tester.widget<IconButton>(key('notes-order-up-$a')).onPressed,
          isNull,
        );
        expect(
          tester.widget<IconButton>(key('notes-order-down-$b')).onPressed,
          isNull,
        );
        expect(
          tester.widget<IconButton>(key('notes-order-up-$c')).onPressed,
          isNull,
        );
        await tap(key('notes-order-up-$b'));
        await tap(find.text('취소'));
        expect((await db.notesDao.listNotes()).map((n) => n.id), [a, b, c, d]);
        await tap(key('notes-order-button'));
        await tap(key('notes-order-up-$b'));
        await tap(key('notes-order-up-$d'));
        await tap(key('notes-order-save'));
        expect((await db.notesDao.listNotes()).map((n) => n.id), [b, a, d, c]);
        await tap(key('notes-order-button'));
        expect(
          tester.getTopLeft(key('notes-order-row-$b')).dy,
          lessThan(tester.getTopLeft(key('notes-order-row-$a')).dy),
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(key('notes-order-button'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('software keyboard converts hyphens and body defaults to 18', (
    tester,
  ) async {
    final db = await pumpNotesScreen(tester, mobile: true);
    addTearDown(db.close);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.tap(find.byTooltip('새 메모'));
    await tester.pumpAndSettle();
    final editor = tester.widget<RichNoteEditor>(find.byType(RichNoteEditor));
    editor.focusNode.requestFocus();
    await tester.pumpAndSettle();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '- \n',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pumpAndSettle();
    expect(editor.controller.document.toPlainText(), '\n');
    expect(
      editor.controller.document.toDelta().toList().last.attributes?['list'],
      'bullet',
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '입금\n\n',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(editor.controller.document.toPlainText(), '입금\n\n');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '입금\n\n\n',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      editor.controller.document.toDelta().toList().last.attributes?['list'],
      isNull,
    );
    final quill = tester.widget<QuillEditor>(find.byType(QuillEditor));
    expect(quill.config.customStyles!.paragraph!.style.fontSize, 18);
    expect(quill.config.customStyles!.lists!.style.fontSize, 18);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
