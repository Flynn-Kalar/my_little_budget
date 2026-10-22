import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/rich_note.dart';
import 'package:my_little_budget/ui/shared/rich_note_editor.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'note_editing_session_test.dart' as notes;

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'touch' : 'mouse'} checks edges without opening edit',
      (tester) async {
        await tester.binding.setSurfaceSize(
          mobile ? const Size(390, 844) : const Size(1200, 900),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var edits = 0;
        final changes = <int>[];
        final document = Document.fromJson([
          {
            'insert': '작은 글씨 체크',
            'attributes': {'size': '8'},
          },
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked'},
          },
          {'insert': '둘째 항목'},
          {
            'insert': '\n',
            'attributes': {'list': 'unchecked', 'indent': 1},
          },
          {'insert': '본문을 누르면 편집\n'},
        ]);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              FlutterQuillLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: RichNoteViewer(
                document: document,
                onTap: () => edits++,
                onChecklistToggle: (index, value) {
                  changes.add(index);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final targets = find.byKey(const ValueKey('note-check-target'));
        expect(targets, findsNWidgets(2));
        final rect = tester.getRect(targets.first);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        final kind = mobile ? PointerDeviceKind.touch : PointerDeviceKind.mouse;
        for (final point in [
          rect.topLeft + const Offset(2, 2),
          rect.topRight + const Offset(-2, 2),
          rect.bottomLeft + const Offset(2, -2),
          rect.bottomRight - const Offset(2, 2),
        ]) {
          await tester.tapAt(point, kind: kind);
          await tester.pumpAndSettle();
          expect(edits, 0);
          expect(changes.length, greaterThan(0));
        }
        expect(changes, [0, 0, 0, 0]);
        expect(checklistFromDocument(document).first.isChecked, isFalse);
        await tester.tap(targets.last, kind: kind);
        await tester.pumpAndSettle();
        expect(changes.last, 1);
        expect(edits, 0);
        expect(checklistFromDocument(document).last.isChecked, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    notes.noteTest(
      '${mobile ? 'mobile' : 'desktop'} expanded checklist targets persist in the note viewer',
      (tester) async {
        final db = await notes.setup(tester, mobile);
        final id = await db.notesDao.saveNote(
          title: '넓은 체크 영역',
          content: '확인 항목',
          richContent: jsonEncode([
            {'insert': '확인 항목'},
            {
              'insert': '\n',
              'attributes': {'list': 'unchecked'},
            },
          ]),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('넓은 체크 영역'));
        await tester.pumpAndSettle();
        final target = find.byKey(const ValueKey('note-check-target'));
        final rect = tester.getRect(target);
        await tester.tapAt(
          rect.topLeft + const Offset(3, 3),
          kind: mobile ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(find.byType(RichNoteViewer), findsOneWidget);
        expect(notes.titleField, findsNothing);
        expect(
          (await db.notesDao.getNoteWithChecklist(id))!.items.single.isChecked,
          isTrue,
        );
        await tester.tapAt(
          tester.getRect(target).bottomRight - const Offset(3, 3),
        );
        await tester.pumpAndSettle();
        expect(
          (await db.notesDao.getNoteWithChecklist(id))!.items.single.isChecked,
          isFalse,
        );
        expect(find.byType(RichNoteViewer), findsOneWidget);
      },
    );
  }
}
