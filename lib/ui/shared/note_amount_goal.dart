import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../features/notes/note_amount_goal.dart';

class NoteGoalDraft extends ChangeNotifier {
  NoteGoalDraft(Note? note) {
    restore(note);
    target.addListener(notifyListeners);
    current.addListener(notifyListeners);
  }

  final target = TextEditingController();
  final current = TextEditingController();
  final addition = TextEditingController();
  bool enabled = false;
  DateTime start = DateUtils.dateOnly(DateTime.now());
  DateTime? due;
  String? additionError;

  void restore(Note? note) {
    final goal = note == null ? null : NoteAmountGoal.fromNote(note);
    enabled = goal != null;
    target.text = goal == null ? '' : formatNoteAmount(goal.targetAmount);
    current.text = formatNoteAmount(goal?.currentAmount ?? 0);
    start = goal?.startDate ?? DateUtils.dateOnly(DateTime.now());
    due = goal?.dueDate;
    addition.clear();
    additionError = null;
    notifyListeners();
  }

  NoteAmountGoal? get goal => !enabled
      ? null
      : NoteAmountGoal(
          targetAmount: parseNoteAmount(target.text) ?? 0,
          currentAmount: parseNoteAmount(current.text) ?? -1,
          startDate: start,
          dueDate: due,
        );

  String? get validationError => goal?.validationError;

  void refresh() => notifyListeners();

  void addAmount(int? amount) {
    final existing = parseNoteAmount(current.text);
    if (amount == null ||
        amount <= 0 ||
        existing == null ||
        amount > maxNoteGoalAmount ||
        existing > maxNoteGoalAmount - amount) {
      additionError = '현재 금액과 추가 금액을 확인하세요. 추가 금액은 1원 이상이어야 합니다.';
      notifyListeners();
      return;
    }
    additionError = null;
    current.text = formatNoteAmount(existing + amount);
    addition.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    target.dispose();
    current.dispose();
    addition.dispose();
    super.dispose();
  }
}

class NoteGoalForm extends StatelessWidget {
  const NoteGoalForm({super.key, required this.draft, this.busy = false});
  final NoteGoalDraft draft;
  final bool busy;

  Future<void> _pickDate(BuildContext context, {required bool due}) async {
    final value = await showDatePicker(
      context: context,
      initialDate: due ? draft.due ?? draft.start : draft.start,
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
    );
    if (value == null) return;
    if (due) {
      draft.due = value;
    } else {
      draft.start = value;
    }
    draft.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<bool>(
          initialValue: draft.enabled,
          decoration: const InputDecoration(labelText: '메모 유형'),
          items: const [
            DropdownMenuItem(value: false, child: Text('일반 메모')),
            DropdownMenuItem(value: true, child: Text('금액 목표')),
          ],
          onChanged: busy
              ? null
              : (value) {
                  draft.enabled = value ?? false;
                  draft.refresh();
                },
        ),
        if (draft.enabled) ...[
          TextField(
            controller: draft.target,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '목표 금액',
              suffixText: '원',
            ),
          ),
          TextField(
            controller: draft.current,
            enabled: !busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '현재 금액',
              suffixText: '원',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final amount in [100000, 200000, 400000])
                Expanded(
                  child: TextButton(
                    onPressed: busy ? null : () => draft.addAmount(amount),
                    child: Text('+${formatNoteAmount(amount)}'),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.addition,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  onSubmitted: busy
                      ? null
                      : (_) => draft.addAmount(
                          parseNoteAmount(draft.addition.text),
                        ),
                  decoration: const InputDecoration(
                    labelText: '추가 금액',
                    suffixText: '원',
                  ),
                ),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () =>
                          draft.addAmount(parseNoteAmount(draft.addition.text)),
                child: const Text('금액 추가'),
              ),
            ],
          ),
          if (draft.additionError != null)
            Text(
              draft.additionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('시작일'),
            subtitle: Text(formatGoalDate(draft.start)),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: busy ? null : () => _pickDate(context, due: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('목표일 (선택사항)'),
            subtitle: Text(
              draft.due == null ? '설정하지 않음' : formatGoalDate(draft.due!),
            ),
            trailing: draft.due == null
                ? const Icon(Icons.calendar_month_outlined)
                : IconButton(
                    tooltip: '목표일 지우기',
                    onPressed: busy
                        ? null
                        : () {
                            draft.due = null;
                            draft.refresh();
                          },
                    icon: const Icon(Icons.clear),
                  ),
            onTap: busy ? null : () => _pickDate(context, due: true),
          ),
          if (draft.validationError == null) NoteGoalSummary(goal: draft.goal!),
        ],
        const SizedBox(height: 12),
      ],
    ),
  );
}

class NoteGoalSummary extends StatelessWidget {
  const NoteGoalSummary({super.key, required this.goal, this.compact = false});
  final NoteAmountGoal goal;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${formatNoteAmount(goal.currentAmount)} / ${formatNoteAmount(goal.targetAmount)}원',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      Text(goal.percentage, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: goal.progress, minHeight: compact ? 4 : 8),
      const SizedBox(height: 4),
      Text(
        '남은 금액 ${formatNoteAmount(goal.remaining)}원',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (!compact)
        Text(
          '시작일 ${formatGoalDate(goal.startDate)}${goal.dueDate == null ? '' : ' · 목표일 ${formatGoalDate(goal.dueDate!)}'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      const SizedBox(height: 8),
    ],
  );
}
