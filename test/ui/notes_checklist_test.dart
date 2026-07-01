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
      closeText.evaluate().isNotEmpty ? closeText : find.byIcon(Icons.close),
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
    expect(find.text('12 pt'), findsOneWidget);

    final fontSizeX = tester.getCenter(find.text('12 pt')).dx;
    final checklistX = tester.getCenter(find.byIcon(Icons.check_box).first).dx;
    final boldX = tester.getCenter(find.byIcon(Icons.format_bold).first).dx;
    expect(fontSizeX, lessThan(checklistX));
    expect(checklistX, lessThan(boldX));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}
