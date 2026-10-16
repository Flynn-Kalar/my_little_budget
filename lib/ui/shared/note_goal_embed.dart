import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../features/notes/note_amount_goal.dart';
import '../../features/notes/note_goal_block.dart';
import 'note_amount_goal.dart';

Future<void> editNoteGoalBlock(
  BuildContext context,
  QuillController controller, {
  NoteGoalBlock? block,
}) => showDialog<void>(
  context: context,
  builder: (context) => _GoalBlockDialog(
    controller: controller,
    block: block,
    selection: controller.selection,
  ),
);

class _GoalBlockDialog extends StatefulWidget {
  const _GoalBlockDialog({
    required this.controller,
    required this.selection,
    this.block,
  });
  final QuillController controller;
  final TextSelection selection;
  final NoteGoalBlock? block;
  @override
  State<_GoalBlockDialog> createState() => _GoalBlockDialogState();
}

class _GoalBlockDialogState extends State<_GoalBlockDialog> {
  late final title = TextEditingController(text: widget.block?.title ?? '');
  late final draft = NoteGoalDraft(null)..enabled = true;
  String? error;
  @override
  void initState() {
    super.initState();
    final block = widget.block;
    if (block != null) {
      draft.target.text = formatNoteAmount(block.goal.targetAmount);
      draft.current.text = formatNoteAmount(block.goal.currentAmount);
      draft.start = block.goal.startDate;
      draft.due = block.goal.dueDate;
    }
  }

  @override
  void dispose() {
    title.dispose();
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return AlertDialog(
      title: Text(block == null ? '금액 목표 삽입' : '금액 목표 수정'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: '목표 이름 (선택사항)'),
              ),
              NoteGoalForm(draft: draft, showType: false),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (block != null)
          TextButton(
            onPressed: () {
              replaceNoteGoalBlock(widget.controller, block.id, null);
              Navigator.pop(context);
            },
            child: const Text('목표 삭제'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (draft.validationError != null) {
              setState(() => error = draft.validationError);
              return;
            }
            final next = block == null
                ? newNoteGoalBlock(title.text, draft.goal!)
                : NoteGoalBlock(
                    id: block.id,
                    title: title.text.trim(),
                    goal: draft.goal!,
                  );
            if (block == null) {
              widget.controller.updateSelection(
                widget.selection,
                ChangeSource.local,
              );
              insertNoteGoalBlock(widget.controller, next);
            } else {
              replaceNoteGoalBlock(widget.controller, block.id, next);
            }
            Navigator.pop(context);
          },
          child: Text(block == null ? '삽입' : '적용'),
        ),
      ],
    );
  }
}

class NoteGoalEmbedBuilder extends EmbedBuilder {
  const NoteGoalEmbedBuilder();
  @override
  String get key => noteGoalBlockType;

  @override
  String toPlainText(Embed node) =>
      NoteGoalBlock.decode(node.value.data)?.plainText ?? '금액 목표';

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final block = NoteGoalBlock.decode(embedContext.node.value.data);
    if (block == null) return const Text('금액 목표를 읽을 수 없습니다.');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.title.isEmpty ? '금액 목표' : block.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!embedContext.readOnly)
                IconButton(
                  tooltip: '금액 목표 수정',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => editNoteGoalBlock(
                    context,
                    embedContext.controller,
                    block: block,
                  ),
                ),
            ],
          ),
          NoteGoalSummary(goal: block.goal),
        ],
      ),
    );
  }
}
