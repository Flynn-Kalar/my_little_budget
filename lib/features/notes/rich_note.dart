import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';

import '../../data/database.dart';
import 'checklist.dart';

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
  final value = text.trimRight();
  if (value.isNotEmpty) delta.insert(value);
  delta.insert('\n');
  return Document.fromDelta(delta);
}

String encodeDocument(Document document) {
  return jsonEncode(document.toDelta().toJson());
}

String plainTextFromDocument(Document document) {
  return document.toPlainText().trim();
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
