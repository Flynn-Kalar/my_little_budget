import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../../data/sync_metadata.dart';

import 'note_amount_goal.dart';

const noteGoalBlockType = 'budget-goal';

class NoteGoalBlock {
  const NoteGoalBlock({
    required this.id,
    required this.title,
    required this.goal,
  });
  final String id;
  final String title;
  final NoteAmountGoal goal;

  String encode() => jsonEncode({
    'id': id,
    'title': title,
    'target': goal.targetAmount,
    'current': goal.currentAmount,
    'start': formatGoalDate(goal.startDate),
    'due': goal.dueDate == null ? null : formatGoalDate(goal.dueDate!),
  });

  static NoteGoalBlock? decode(dynamic data) {
    try {
      final map = jsonDecode(data as String) as Map<String, dynamic>;
      final goal = NoteAmountGoal(
        targetAmount: map['target'] as int,
        currentAmount: map['current'] as int,
        startDate: DateTime.parse(map['start'] as String),
        dueDate: map['due'] == null
            ? null
            : DateTime.parse(map['due'] as String),
      );
      if (goal.validationError != null) return null;
      return NoteGoalBlock(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        goal: goal,
      );
    } catch (_) {
      return null;
    }
  }

  String get plainText =>
      '${title.isEmpty ? '금액 목표' : title}\n'
      '${formatNoteAmount(goal.currentAmount)} / ${formatNoteAmount(goal.targetAmount)}원 '
      '(${goal.percentage})\n남은 금액 ${formatNoteAmount(goal.remaining)}원';
}

/// A standalone block at the selection, with a writable line on either side.
void insertNoteGoalBlock(QuillController controller, NoteGoalBlock block) {
  final selection = controller.selection;
  final start = selection.isValid
      ? selection.start
      : controller.document.length - 1;
  final length = selection.isValid ? selection.end - start : 0;
  final text = controller.document.toPlainText();
  final leading = start > 0 && text[start - 1] != '\n' ? '\n' : '';
  final delta = Delta()
    ..insert(leading)
    ..insert({noteGoalBlockType: block.encode()})
    ..insert('\n');
  controller.replaceText(
    start,
    length,
    delta,
    TextSelection.collapsed(offset: start + leading.length + 2),
  );
}

NoteGoalBlock newNoteGoalBlock(String title, NoteAmountGoal goal) =>
    NoteGoalBlock(id: newSyncUuid(), title: title.trim(), goal: goal);

/// Find by identity after a dialog closes, so edits never replace another block.
bool replaceNoteGoalBlock(
  QuillController controller,
  String id,
  NoteGoalBlock? next,
) {
  var offset = 0;
  for (final op in controller.document.toDelta().toList()) {
    if (op.data is Map) {
      final block = NoteGoalBlock.decode((op.data as Map)[noteGoalBlockType]);
      if (block?.id == id) {
        controller.replaceText(
          offset,
          1,
          next == null ? '' : BlockEmbed(noteGoalBlockType, next.encode()),
          TextSelection.collapsed(offset: next == null ? offset : offset + 1),
        );
        return true;
      }
    }
    offset += op.length ?? 0;
  }
  return false;
}
