import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/shell/layout_policy.dart';
import 'package:my_little_budget/features/notes/note_draft_store.dart';
import 'package:my_little_budget/features/notes/rich_note.dart';
import 'package:my_little_budget/ui/desktop/notes/notes_screen.dart';
import 'package:my_little_budget/ui/mobile/notes/mobile_notes_screen.dart';
import 'package:my_little_budget/ui/mobile/notes/mobile_note_detail_page.dart';
import 'package:my_little_budget/ui/mobile/notes/mobile_note_editor.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';
import 'package:my_little_budget/ui/shared/note_editing_session.dart';
import 'package:my_little_budget/ui/shared/rich_note_editor.dart';

AppDatabase? _testDatabase;
void noteTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    _testDatabase = null;
    try {
      await body(tester);
    } finally {
      if (find.byType(NoteEditingSession).evaluate().isNotEmpty) {
        await tester
            .state<NoteEditingSessionState>(find.byType(NoteEditingSession))
            .flushDraft();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      await _testDatabase?.close();
      await tester.binding.setSurfaceSize(null);
    }
  });
}

Finder get titleField => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == '제목',
);

Future<void> pumpScreen(
  WidgetTester tester,
  AppDatabase db,
  bool mobile,
) async {
  await tester.binding.setSurfaceSize(
    mobile ? const Size(390, 844) : const Size(1200, 900),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        builder: (context, child) => ShellLayoutScope(
          mobile: mobile,
          viewportWidth: mobile ? 390 : 1200,
          child: child!,
        ),
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
}

Future<AppDatabase> setup(WidgetTester tester, bool mobile) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  _testDatabase = db;
  await pumpScreen(tester, db, mobile);
  return db;
}

Future<void> openNew(WidgetTester tester, bool mobile) async {
  await tester.tap(mobile ? find.byTooltip('새 메모') : find.text('새 메모'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final mobile in [false, true]) {
    for (final checklist in [false, true]) {
      noteTest(
        '${mobile ? 'mobile' : 'desktop'} tapping noninteractive note text opens editing with checklist=$checklist',
        (tester) async {
          final db = await setup(tester, mobile);
          final id = await db.notesDao.saveNote(
            title: '탭 편집',
            content: '일반 본문\n확인 항목',
            richContent: jsonEncode([
              {'insert': '일반 본문\n확인 항목'},
              {
                'insert': '\n',
                if (checklist) 'attributes': {'list': 'unchecked'},
              },
            ]),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('탭 편집'));
          await tester.pumpAndSettle();
          if (checklist) {
            final checkbox = find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == 'QuillCheckboxPoint',
            );
            await tester.tap(
              find.descendant(of: checkbox, matching: find.byType(InkWell)),
            );
            await tester.pumpAndSettle();
            expect(find.byType(RichNoteViewer), findsOneWidget);
            expect(titleField, findsNothing);
            expect(
              (await db.notesDao.getNoteWithChecklist(
                id,
              ))!.items.single.isChecked,
              true,
            );
          }
          final text = find
              .descendant(
                of: find.byType(RichNoteViewer),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is RichText &&
                      w.text.toPlainText().contains(
                        checklist ? '확인 항목' : '일반 본문',
                      ),
                ),
              )
              .first;
          await tester.tapAt(tester.getTopLeft(text) + const Offset(30, 10));
          await tester.pumpAndSettle();
          expect(titleField, findsOneWidget);
          expect(find.byType(NoteEditingSession), findsOneWidget);
          expect(find.byType(RichNoteViewer), findsNothing);
          if (checklist) {
            expect(
              checklistFromDocument(
                tester
                    .widget<RichNoteEditor>(find.byType(RichNoteEditor))
                    .controller
                    .document,
              ).single.isChecked,
              true,
            );
          }
        },
      );
    }
  }

  noteTest(
    'mobile blank reading area opens editing while dragging only scrolls',
    (tester) async {
      final db = await setup(tester, true);
      await db.notesDao.saveNote(title: '짧은 메모', content: '본문');
      await db.notesDao.saveNote(
        title: '긴 메모',
        content: List.generate(90, (i) => '$i 긴 본문').join('\n'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('짧은 메모'));
      await tester.pumpAndSettle();
      final page = find.byType(MobileNoteDetailPage);
      await tester.tapAt(tester.getBottomRight(page) - const Offset(30, 40));
      await tester.pumpAndSettle();
      expect(titleField, findsOneWidget);
      await tapVisible(tester, find.text('취소'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('긴 메모'));
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('mobile-note-detail-scroll')),
          )
          .controller!;
      await tester.dragFrom(
        tester.getCenter(find.byType(MobileNoteDetailPage)),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(titleField, findsNothing);
      expect(find.byType(RichNoteViewer), findsOneWidget);
    },
  );

  for (final mobile in [false, true]) {
    noteTest(
      '${mobile ? 'mobile' : 'desktop'} inserts inline goals among text and checklists and saves edits',
      (tester) async {
        final db = await setup(tester, mobile);
        await openNew(tester, mobile);
        await tester.enterText(titleField, '본문 목표 테스트');
        final editor = tester.widget<RichNoteEditor>(
          find.byType(RichNoteEditor),
        );
        editor.controller.replaceText(
          0,
          0,
          '앞 설명\n뒤 설명',
          const TextSelection.collapsed(offset: 5),
        );
        Future<void> insert(String name, String amount) async {
          await tapVisible(tester, find.byTooltip('금액 목표 삽입'));
          final dialog = find.byType(AlertDialog);
          Finder field(String label) => find.descendant(
            of: dialog,
            matching: find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.labelText == label,
            ),
          );
          await tester.enterText(field('목표 이름 (선택사항)'), name);
          await tester.enterText(field('목표 금액'), amount);
          await tester.enterText(field('현재 금액'), '1000000');
          await tapVisible(tester, find.widgetWithText(FilledButton, '삽입'));
        }

        await insert('비상금', '2681630');
        editor.controller.updateSelection(
          TextSelection.collapsed(
            offset: editor.controller.document.length - 1,
          ),
          ChangeSource.local,
        );
        await insert('여행', '2000000');
        expect(find.byTooltip('금액 목표 수정'), findsNWidgets(2));
        await tapVisible(tester, find.byTooltip('금액 목표 수정').first);
        if (mobile) {
          await tapVisible(tester, find.text('+400,000'));
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
        await tapVisible(tester, find.widgetWithText(FilledButton, '적용'));
        expect(
          plainTextFromDocument(editor.controller.document),
          contains('1,400,000 / 2,681,630원'),
        );
        final end = editor.controller.document.length - 1;
        editor.controller.replaceText(
          end,
          0,
          '\n점검',
          TextSelection.collapsed(offset: end + 3),
        );
        editor.controller.formatText(end + 1, 2, Attribute.unchecked);
        await tester.pumpAndSettle();
        expect(
          checklistFromDocument(editor.controller.document).single.text,
          '점검',
        );
        await tapVisible(tester, find.text('저장'));
        final saved = (await db.notesDao.listNotes()).single;
        expect(saved.goalTargetAmount, isNull);
        expect(saved.content, contains('뒤 설명'));
        expect(saved.content, contains('여행'));
        expect(saved.richContent, contains('budget-goal'));
        await tester.tap(find.text('본문 목표 테스트'));
        await tester.pumpAndSettle();
        final viewer = tester.widget<RichNoteViewer>(
          find.byType(RichNoteViewer),
        );
        expect(
          plainTextFromDocument(viewer.document),
          contains('1,400,000 / 2,681,630원'),
        );
        expect(checklistFromDocument(viewer.document).single.text, '점검');
        expect(find.text('여행'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  noteTest(
    'mobile detail uses a full page with unboxed rich text, full titles and footer dates',
    (tester) async {
      final db = await setup(tester, true);
      final title = List.filled(8, '긴 메모 제목 ').join().trim();
      final body =
          '첫 줄\n\n${List.generate(90, (i) => '$i 교통비와 식비 기록').join('\n')}\n마지막 줄\n';
      final rich = jsonEncode([
        {
          'insert': '첫 줄',
          'attributes': {'bold': true},
        },
        {'insert': body.substring(3)},
      ]);
      final id = await db.notesDao.saveNote(
        title: title,
        content: body,
        richContent: rich,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(MobileNoteDetailPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      final titleWidget = tester.widget<Text>(
        find.byKey(const ValueKey('mobile-note-detail-title')),
      );
      expect(titleWidget.data, title);
      expect(titleWidget.maxLines, isNull);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('mobile-note-detail-title')))
            .height,
        greaterThan(50),
      );
      final viewer = tester.widget<RichNoteViewer>(find.byType(RichNoteViewer));
      expect(viewer.document.toPlainText(), body);
      expect(viewer.document.toDelta().toJson(), jsonDecode(rich));
      expect(viewer.bordered, isFalse);
      expect(viewer.scrollable, isFalse);
      expect(viewer.maxHeight, isNull);
      final pageScroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('mobile-note-detail-scroll')),
          )
          .controller!;
      expect(pageScroll.position.maxScrollExtent, greaterThan(1000));
      pageScroll.jumpTo(pageScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.textContaining('수정 ').hitTestable(), findsOneWidget);
      expect((await db.notesDao.getNote(id))!.richContent, rich);
      final scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(MobileNoteDetailPage),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, isNull); // Follow the existing theme.
    },
  );

  noteTest(
    'mobile detail refreshes after editing, reopens saved text and deletes with confirmation',
    (tester) async {
      final db = await setup(tester, true);
      final id = await db.notesDao.saveNote(title: '보기 원본', content: '이전 본문');
      await tester.pumpAndSettle();
      await tester.tap(find.text('보기 원본'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('편집'));
      await tester.pumpAndSettle();
      await tester.enterText(titleField, '최신 제목');
      final editor = tester.widget<RichNoteEditor>(find.byType(RichNoteEditor));
      editor.controller.replaceText(
        0,
        editor.controller.document.length - 1,
        '수정 본문\n\n빈 줄 유지',
        const TextSelection.collapsed(offset: 0),
      );
      await tapVisible(tester, find.text('저장'));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('최신 제목'), findsOneWidget);
      expect(
        tester
            .widget<RichNoteViewer>(find.byType(RichNoteViewer))
            .document
            .toPlainText(),
        '수정 본문\n\n빈 줄 유지\n',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('최신 제목'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RichNoteViewer>(find.byType(RichNoteViewer))
            .document
            .toPlainText(),
        '수정 본문\n\n빈 줄 유지\n',
      );
      await tester.tap(find.byTooltip('삭제'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '삭제'));
      await tester.pumpAndSettle();
      expect(await db.notesDao.getNote(id), isNull);
      expect(find.byType(MobileNoteDetailPage), findsNothing);
    },
  );

  noteTest('mobile detail does not fabricate missing timestamps', (
    tester,
  ) async {
    final db = await setup(tester, true);
    final id = await db.notesDao.saveNote(title: '날짜 없음', content: '본문');
    await db.customUpdate(
      "UPDATE notes SET created_at='', updated_at='invalid' WHERE id=?",
      variables: [Variable<int>(id)],
      updates: {db.notes},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('날짜 없음'));
    await tester.pumpAndSettle();
    expect(find.textContaining('작성 '), findsNothing);
    expect(find.textContaining('수정 '), findsNothing);
  });

  noteTest(
    'mobile follows the actual caret at the end, middle and top across keyboard resizing',
    (tester) async {
      await setup(tester, true);
      await openNew(tester, true);
      final editor = tester.widget<RichNoteEditor>(find.byType(RichNoteEditor));
      final mobile = tester.widget<MobileNoteEditor>(
        find.byType(MobileNoteEditor),
      );
      final body = List.generate(180, (i) => '$i 교통비 항목을 확인합니다.').join('\n');
      editor.controller.replaceText(
        0,
        0,
        body,
        const TextSelection.collapsed(offset: 0),
      );
      editor.focusNode.requestFocus();
      await tester.pumpAndSettle();

      Rect viewport() {
        final box =
            mobile.formViewportKey.currentContext!.findRenderObject()!
                as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      }

      void expectCaret(TextSelection selection) {
        final render = editor.editorKey!.currentState!.renderEditor;
        final caret = render.getLocalRectForCaret(selection.extent);
        final top = render.localToGlobal(caret.topLeft).dy;
        final bottom = render.localToGlobal(caret.bottomRight).dy;
        expect(top, greaterThanOrEqualTo(viewport().top - 1));
        expect(bottom, lessThanOrEqualTo(viewport().bottom + 1));
        expect(bottom, lessThan(tester.getTopLeft(find.text('저장')).dy));
        expect(editor.controller.selection, selection);
      }

      final end = editor.controller.document.length - 1;
      final bottomSelection = TextSelection.collapsed(offset: end);
      editor.controller.updateSelection(bottomSelection, ChangeSource.local);
      await tester.pumpAndSettle();
      expectCaret(bottomSelection);
      expect(editor.scrollController.offset, greaterThan(0));
      final middle = TextSelection.collapsed(offset: end ~/ 2);
      editor.controller.updateSelection(middle, ChangeSource.local);
      await tester.pumpAndSettle();
      expectCaret(middle);
      final reversed = TextSelection(baseOffset: end, extentOffset: 0);
      editor.controller.updateSelection(reversed, ChangeSource.local);
      await tester.pumpAndSettle();
      expectCaret(reversed);
      editor.controller.updateSelection(bottomSelection, ChangeSource.local);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expectCaret(bottomSelection);
      editor.controller.replaceText(
        end,
        0,
        '\n새 줄',
        TextSelection.collapsed(offset: end + 4),
      );
      await tester.pumpAndSettle();
      final afterTyping = editor.controller.selection;
      expectCaret(afterTyping);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expectCaret(afterTyping);

      final beforeDrag = editor.scrollController.offset;
      final visibleEditor = tester
          .getRect(find.byType(MobileNoteEditor))
          .intersect(viewport());
      await tester.dragFrom(visibleEditor.center, const Offset(0, 160));
      await tester.pumpAndSettle();
      final afterDrag = editor.scrollController.offset;
      expect(afterDrag, lessThan(beforeDrag));
      await tester.pump(const Duration(milliseconds: 500));
      expect(editor.scrollController.offset, closeTo(afterDrag, 1));
      expect(editor.controller.selection, afterTyping);
    },
  );

  for (final mobile in [false, true]) {
    final label = mobile ? 'mobile' : 'desktop';
    noteTest(
      '$label reopens an existing draft, preserves settings and protects a newer original',
      (tester) async {
        final db = await setup(tester, mobile);
        final id = await db.notesDao.saveNote(title: '원래 제목', content: '원래 본문');
        await tester.pumpAndSettle();
        await tester.tap(find.text('원래 제목'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(titleField, '초안 제목');
        await tester.pumpAndSettle();
        await tester
            .state<NoteEditingSessionState>(find.byType(NoteEditingSession))
            .flushDraft();
        final store = NoteDraftStore(db);
        final record = (await store.load(id))!;
        final payload = jsonDecode(record.payload) as Map<String, dynamic>;
        // A valid draft may contain schedule changes not yet saved as a note.
        (payload['settings'] as Map)['scheduleType'] = 'daily';
        (payload['settings'] as Map)['resetTime'] = '07:30';
        payload['reminderOptions'] = {
          'dueDate': '2027-01-01',
          'every': 2,
          'until': null,
          'timeZone': 'Asia/Seoul',
          'alarmMode': false,
          'anchorDate': null,
        };
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        await store.write(
          noteId: id,
          baseUpdatedAt: record.baseUpdatedAt,
          payload: payload,
        );
        await db.notesDao.saveNote(
          id: id,
          title: '원본 최신 제목',
          content: '원본 최신 본문',
        );
        await pumpScreen(tester, db, mobile);
        await tester.tap(find.text('원본 최신 제목'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        expect(find.text('임시 작성 내용이 있습니다'), findsOneWidget);
        await tester.tap(find.text('복구'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(titleField).controller!.text, '초안 제목');
        await tapVisible(tester, find.text('새 메모로 저장'));
        expect((await db.notesDao.getNote(id))!.title, '원본 최신 제목');
        final copied = (await db.select(db.notes).get()).last;
        expect(copied.title, '초안 제목');
        expect(copied.content, '원래 본문');
        expect(copied.scheduleType, 'daily');
        expect(copied.resetTime, '07:30');
        final options = await db
            .customSelect(
              'SELECT repeat_every FROM reminder_series WHERE note_id=?',
              variables: [Variable(copied.id)],
            )
            .getSingle();
        expect(options.read<int>('repeat_every'), 2);
        expect(await store.load(id), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    noteTest('$label flushes a draft on backgrounding without saving a note', (
      tester,
    ) async {
      final db = await setup(tester, mobile);
      await openNew(tester, mobile);
      await tester.enterText(titleField, '백그라운드 초안');
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      final record = (await NoteDraftStore(db).load(null))!;
      expect(jsonDecode(record.payload)['title'], '백그라운드 초안');
      expect(await db.select(db.notes).get(), isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    });
    noteTest(
      '$label protects cancel/back, discards deliberately and allows reverted edits to close',
      (tester) async {
        final db = await setup(tester, mobile);
        await openNew(tester, mobile);
        await tester.enterText(titleField, '편집');
        await tester.enterText(titleField, '');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('취소'));
        expect(find.text('변경사항을 저장할까요?'), findsNothing);
        expect(find.byType(NoteEditingSession), findsNothing);
        await openNew(tester, mobile);
        await tester.enterText(titleField, '유지할 내용');
        await tapVisible(tester, find.text('취소'));
        expect(find.text('변경사항을 저장할까요?'), findsOneWidget);
        await tester.tap(find.text('계속 작성'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(titleField).controller!.text, '유지할 내용');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('변경사항을 저장할까요?'), findsOneWidget);
        await tester.tap(find.text('변경사항 버리기'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditingSession), findsNothing);
        expect(await NoteDraftStore(db).load(null), isNull);
        expect(await db.select(db.notes).get(), isEmpty);
      },
    );

    noteTest(
      '$label recovers untitled rich text, goals and settings without changing saved notes',
      (tester) async {
        final db = await setup(tester, mobile);
        await openNew(tester, mobile);
        final editor = tester.widget<RichNoteEditor>(
          find.byType(RichNoteEditor),
        );
        editor.controller.replaceText(
          0,
          0,
          '복구 본문',
          const TextSelection.collapsed(offset: 5),
        );
        editor.controller.formatText(0, 2, Attribute.bold);
        insertNoteGoalBlock(
          editor.controller,
          newNoteGoalBlock(
            '복구 목표',
            NoteAmountGoal(
              targetAmount: 2000000,
              currentAmount: 500000,
              startDate: DateTime(2026, 1, 1),
              dueDate: DateTime(2027, 1, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('상단 고정'));
        await tester.pump(const Duration(seconds: 2));
        final session = tester.state<NoteEditingSessionState>(
          find.byType(NoteEditingSession),
        );
        await session.flushDraft();
        await tester.pumpAndSettle();
        expect(find.text('이 기기에 임시 저장됨'), findsOneWidget);
        final draft = (await NoteDraftStore(db).load(null))!;
        expect(jsonDecode(draft.payload)['title'], '');
        expect(await db.select(db.notes).get(), isEmpty);
        // Recreate the entire UI, simulating an interrupted editing session.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await pumpScreen(tester, db, mobile);
        await openNew(tester, mobile);
        expect(find.text('임시 작성 내용이 있습니다'), findsOneWidget);
        await tester.tap(find.text('복구'));
        await tester.pumpAndSettle();
        final restored = tester.widget<RichNoteEditor>(
          find.byType(RichNoteEditor),
        );
        expect(
          plainTextFromDocument(restored.controller.document),
          contains('복구 본문'),
        );
        expect(
          restored.controller.document.toDelta().toJson(),
          jsonDecode(draft.payload)['rich'],
        );
        final goalOp = restored.controller.document
            .toDelta()
            .toList()
            .where((o) => o.data is Map)
            .single;
        final restoredGoal = NoteGoalBlock.decode(
          (goalOp.data as Map)[noteGoalBlockType],
        )!;
        expect(restoredGoal.goal.currentAmount, 500000);
        expect(restoredGoal.goal.dueDate, DateTime(2027, 1, 1));
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, '상단 고정'))
              .selected,
          isTrue,
        );
        await tapVisible(tester, find.text('저장'));
        expect(find.text('제목을 입력하세요.'), findsWidgets);
        expect(await NoteDraftStore(db).load(null), isNotNull);
        await tester.enterText(titleField, '복구 완료');
        await tapVisible(tester, find.text('저장'));
        final saved = (await db.select(db.notes).get()).single;
        expect(saved.content, contains('복구 본문'));
        expect(saved.content, contains('복구 목표'));
        expect(saved.goalCurrentAmount, isNull);
        expect(saved.pinned, isTrue);
        expect(await NoteDraftStore(db).load(null), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    noteTest('$label retains input after a DB failure and retries successfully', (
      tester,
    ) async {
      final db = await setup(tester, mobile);
      await openNew(tester, mobile);
      await tester.enterText(titleField, '실패 후 복구');
      await db.customStatement(
        "CREATE TRIGGER test_note_failure BEFORE INSERT ON notes BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await tapVisible(tester, find.text('저장'));
      expect(find.text('저장하지 못했습니다. 작성 내용은 유지됩니다. 다시 시도해 주세요.'), findsWidgets);
      expect(tester.widget<TextField>(titleField).controller!.text, '실패 후 복구');
      expect(await NoteDraftStore(db).load(null), isNotNull);
      await db.customStatement('DROP TRIGGER test_note_failure');
      await tapVisible(tester, find.text('저장'));
      expect((await db.select(db.notes).get()).single.title, '실패 후 복구');
      expect(await NoteDraftStore(db).load(null), isNull);
      expect(tester.takeException(), isNull);
    });

    noteTest(
      '$label prevents overwriting a changed original and supports saving a copy',
      (tester) async {
        final db = await setup(tester, mobile);
        final id = await db.notesDao.saveNote(title: '원본', content: '원본 본문');
        await tester.pumpAndSettle();
        await tester.tap(find.text('원본'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();
        await tester.enterText(titleField, '내가 편집한 내용');
        await db.notesDao.saveNote(
          id: id,
          title: '다른 화면의 최신 내용',
          content: '최신 본문',
        );
        await tapVisible(tester, find.text('저장'));
        expect(find.text('새 메모로 저장'), findsOneWidget);
        expect((await db.notesDao.getNote(id))!.content, '최신 본문');
        await tapVisible(tester, find.text('새 메모로 저장'));
        final notes = await db.select(db.notes).get();
        expect(notes, hasLength(2));
        expect(notes.last.title, '내가 편집한 내용');
        expect(notes.first.title, '다른 화면의 최신 내용');
        expect(await NoteDraftStore(db).load(id), isNull);
      },
    );

    noteTest(
      '$label save-and-close validates before leaving and toolbar history works',
      (tester) async {
        await setup(tester, mobile);
        await openNew(tester, mobile);
        final editor = tester.widget<RichNoteEditor>(
          find.byType(RichNoteEditor),
        );
        editor.controller.replaceText(
          0,
          0,
          '본문',
          const TextSelection.collapsed(offset: 2),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('실행 취소'));
        await tester.pumpAndSettle();
        expect(editor.controller.document.toPlainText(), '\n');
        await tester.tap(find.byTooltip('다시 실행'));
        await tester.pumpAndSettle();
        expect(editor.controller.document.toPlainText(), '본문\n');
        await tapVisible(tester, find.text('취소'));
        await tester.tap(find.text('저장 후 닫기'));
        await tester.pumpAndSettle();
        expect(find.text('제목을 입력하세요.'), findsWidgets);
        expect(find.byType(RichNoteEditor), findsOneWidget);
        await tester.enterText(titleField, '완료');
        await tapVisible(tester, find.text('취소'));
        await tester.tap(find.text('저장 후 닫기'));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditingSession), findsNothing);
        expect(find.text('완료'), findsWidgets);
      },
    );
  }

  noteTest(
    'mobile keeps save accessible with the keyboard and expandable settings',
    (tester) async {
      await setup(tester, true);
      await openNew(tester, true);
      expect(find.text('일정 유형').hitTestable(), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.text('저장').hitTestable(), findsOneWidget);
      await tapVisible(tester, find.text('추가 설정'));
      expect(find.text('일정 유형'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
