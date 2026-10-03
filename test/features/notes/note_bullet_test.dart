import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/rich_note.dart';

void main() {
  test(
    'legacy text supports mixed bullets without changing ordinary lines',
    () {
      final doc = documentFromPlainText('일반 본문\n- 입금\n- 카드 확인\n다음 문장');
      expect(doc.toPlainText(), '일반 본문\n입금\n카드 확인\n다음 문장\n');
      expect(
        doc.toDelta().toList().where(
          (op) => op.attributes?['list'] == 'bullet',
        ),
        hasLength(2),
      );
      expect(checklistFromDocument(doc), isEmpty);
    },
  );

  test(
    'shortcut, Enter continuation and empty Enter exit use real list attributes',
    () {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      controller.replaceText(
        0,
        0,
        '- ',
        const TextSelection.collapsed(offset: 2),
      );
      convertNoteBulletShortcut(controller);
      expect(controller.document.toPlainText(), '\n');
      expect(
        controller.document.toDelta().toList().last.attributes?['list'],
        'bullet',
      );
      controller.replaceText(
        0,
        0,
        '입금',
        const TextSelection.collapsed(offset: 2),
      );
      controller.replaceText(
        2,
        0,
        '\n',
        const TextSelection.collapsed(offset: 3),
      );
      expect(
        controller.document
            .toDelta()
            .toList()
            .where((op) => op.attributes?['list'] == 'bullet')
            .expand(
              (op) => (op.data as String).split('').where((c) => c == '\n'),
            ),
        hasLength(2),
      );
      controller.replaceText(
        3,
        0,
        '\n',
        const TextSelection.collapsed(offset: 4),
      );
      expect(
        controller.document.toDelta().toList().last.attributes?['list'],
        isNull,
      );
      final saved = encodeDocument(controller.document);
      expect(
        Document.fromJson(
          (controller.document.toDelta().toJson()),
        ).toPlainText(),
        controller.document.toPlainText(),
      );
      expect(saved, contains('bullet'));
    },
  );

  test('mid-line hyphens and existing checklists are preserved', () {
    final controller = QuillController(
      document: documentFromPlainText('본문 - '),
      selection: const TextSelection.collapsed(offset: 5),
    );
    addTearDown(controller.dispose);
    convertNoteBulletShortcut(controller);
    expect(controller.document.toPlainText(), '본문 - \n');
    controller.document = Document();
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
    controller.formatSelection(Attribute.unchecked);
    controller.replaceText(
      0,
      0,
      '- ',
      const TextSelection.collapsed(offset: 2),
    );
    convertNoteBulletShortcut(controller);
    expect(controller.document.toPlainText(), '- \n');
    expect(
      controller.document.toDelta().toList().last.attributes?['list'],
      'unchecked',
    );
  });
}
