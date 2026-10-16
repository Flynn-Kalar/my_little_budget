import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../data/database.dart';
import 'checklist.dart';
import 'note_goal_block.dart';

Document documentFromNote(Note note) {
  final rich = note.richContent;
  if (rich != null && rich.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(rich);
      if (decoded is List) return Document.fromJson(decoded);
    } catch (_) {
      // Fall back to plain content below.
    }
  }
  return documentFromPlainText(note.content);
}

Document documentFromPlainText(String text) {
  final delta = Delta();
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  for (final line in lines) {
    final bullet = line.startsWith('- ');
    final value = bullet ? line.substring(2) : line;
    if (value.isNotEmpty) delta.insert(value);
    delta.insert('\n', bullet ? {'list': 'bullet'} : null);
  }
  return Document.fromDelta(delta);
}

String noteBodyPreview(Note note) {
  final buffer = StringBuffer();
  final line = StringBuffer();
  for (final op in documentFromNote(note).toDelta().toList()) {
    if (op.data is Map) {
      final block = NoteGoalBlock.decode((op.data as Map)[noteGoalBlockType]);
      if (block != null) line.write(block.plainText);
    }
    if (op.data is! String) continue;
    for (final char in (op.data as String).split('')) {
      if (char == '\n') {
        if (op.attributes?['list'] == 'bullet') buffer.write('• ');
        buffer.writeln(line);
        line.clear();
      } else {
        line.write(char);
      }
    }
  }
  return buffer.toString().trimRight();
}

String encodeDocument(Document document) {
  return jsonEncode(document.toDelta().toJson());
}

/// Runs on controller changes so software keyboards support the same shortcut.
void convertNoteBulletShortcut(QuillController controller) {
  final selection = controller.selection;
  if (!selection.isCollapsed) return;
  final text = controller.document.toPlainText();
  final offset = selection.baseOffset;
  if (offset < 2 || offset > text.length - 1) return;
  final start = text.lastIndexOf('\n', offset - 1) + 1;
  if (offset != start + 2 || !text.startsWith('- ', start)) return;
  // A checklist item remains a checklist even if its text starts with a hyphen.
  final line = controller.document.querySegmentLeafNode(start).line;
  if (line?.style.attributes.containsKey('list') ?? false) return;
  controller.replaceText(start, 2, '', TextSelection.collapsed(offset: start));
  controller.formatSelection(Attribute.ul);
}

String plainTextFromDocument(Document document) {
  final text = StringBuffer();
  for (final op in document.toDelta().toList()) {
    if (op.data is String) {
      text.write(op.data);
    } else if (op.data is Map) {
      text.write(
        NoteGoalBlock.decode((op.data as Map)[noteGoalBlockType])?.plainText ??
            '',
      );
    }
  }
  return text.toString().trim();
}

List<ChecklistItemDraft> checklistFromDocument(Document document) {
  final result = <ChecklistItemDraft>[];
  final buffer = StringBuffer();

  for (final op in document.toDelta().toList()) {
    final data = op.data;
    if (data is! String) continue;
    final attrs = op.attributes ?? const <String, dynamic>{};
    final list = attrs['list'];

    for (var i = 0; i < data.length; i++) {
      final char = data[i];
      if (char == '\n') {
        final text = buffer.toString().trim();
        if ((list == 'checked' || list == 'unchecked') && text.isNotEmpty) {
          result.add(
            ChecklistItemDraft(text: text, isChecked: list == 'checked'),
          );
        }
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
  }

  return result;
}

String? uncheckedChecklistRichContent(String? richContent) {
  if (richContent == null || richContent.trim().isEmpty) return richContent;
  final decoded = jsonDecode(richContent);
  if (decoded is! List) return richContent;

  var changed = false;
  final next = decoded.map((raw) {
    if (raw is! Map) return raw;
    final op = Map<String, dynamic>.from(raw);
    final attrs = op['attributes'];
    if (attrs is Map && attrs['list'] == 'checked') {
      op['attributes'] = Map<String, dynamic>.from(attrs)
        ..['list'] = 'unchecked';
      changed = true;
    }
    return op;
  }).toList();

  return changed ? jsonEncode(next) : richContent;
}

String? setChecklistStateInRichContent(
  String? richContent, {
  required int checklistIndex,
  required bool isChecked,
}) {
  if (richContent == null || richContent.trim().isEmpty) return richContent;
  final decoded = jsonDecode(richContent);
  if (decoded is! List) return richContent;

  var current = 0;
  var changed = false;
  final next = decoded.map((raw) {
    if (raw is! Map) return raw;
    final op = Map<String, dynamic>.from(raw);
    final attrs = op['attributes'];
    if (attrs is Map &&
        (attrs['list'] == 'checked' || attrs['list'] == 'unchecked')) {
      if (current == checklistIndex) {
        op['attributes'] = Map<String, dynamic>.from(attrs)
          ..['list'] = isChecked ? 'checked' : 'unchecked';
        changed = true;
      }
      current++;
    }
    return op;
  }).toList();

  return changed ? jsonEncode(next) : richContent;
}
