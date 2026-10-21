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
      '${mobile ? 'mobile' : 'desktop'} creates and edits normal and amount goal notes',
      (tester) async {
        final db = await pumpNotesScreen(tester, mobile: mobile);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(db.close);
        final titleField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == '제목',
        );
        Future<void> createNote(String title, {bool goal = false}) async {
          await tester.tap(mobile ? find.byTooltip('새 메모') : find.text('새 메모'));
          await tester.pumpAndSettle();
          await tester.enterText(titleField, title);
          if (goal) {
            await tester.tap(find.byType(DropdownButtonFormField<bool>));
            await tester.pumpAndSettle();
            await tester.tap(find.text('금액 목표').last);
            await tester.pumpAndSettle();
            final form = tester.widget<NoteGoalForm>(find.byType(NoteGoalForm));
            form.draft.target.text = '2,681,630';
            form.draft.current.text = '1,000,000';
            if (mobile) {
              await tester.ensureVisible(find.text('+400,000'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('+400,000'));
            } else {
              expect(find.text('+400,000'), findsNothing);
              expect(find.text('금액 추가'), findsNothing);
              await tester.enterText(
                find.byWidgetPredicate(
                  (w) => w is TextField && w.decoration?.labelText == '현재 금액',
                ),
                '1,400,000',
              );
            }
            await tester.pumpAndSettle();
            expect(form.draft.current.text, '1,400,000');
          }
          final editor = tester.widget<RichNoteEditor>(
            find.byType(RichNoteEditor),
          );
          editor.controller.replaceText(
            0,
            0,
            '일반 본문',
            const TextSelection.collapsed(offset: 5),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('저장'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('저장'));
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
        }

        await createNote('새 일반 메모');
        expect((await db.notesDao.getNote(1))!.content, '일반 본문');
        expect((await db.notesDao.getNote(1))!.goalTargetAmount, isNull);
        await createNote('컴퓨터 비상금 복구', goal: true);
        expect((await db.notesDao.getNote(2))!.goalCurrentAmount, 1400000);
        expect(find.text('52.2%'), findsOneWidget);
        await tester.tap(find.text('컴퓨터 비상금 복구'));
        await tester.pumpAndSettle();
        expect(find.byType(RichNoteViewer), findsOneWidget);
        expect(find.text('남은 금액 1,281,630원'), findsWidgets);
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        final draft = tester
            .widget<NoteGoalForm>(find.byType(NoteGoalForm))
            .draft;
        expect(draft.target.text, '2,681,630');
        draft.current.text = '3,000,000';
        if (mobile) {
          draft.addition.text = '123,456';
          await tester.ensureVisible(find.text('금액 추가'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('금액 추가'));
        } else {
          expect(find.text('금액 추가'), findsNothing);
          draft.current.text = '3,123,456';
        }
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('저장'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('저장'));
        await tester.pumpAndSettle();
        expect((await db.notesDao.getNote(2))!.goalCurrentAmount, 3123456);
        expect(find.text('100.0%'), findsWidgets);
        expect(find.text('남은 금액 0원'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
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
