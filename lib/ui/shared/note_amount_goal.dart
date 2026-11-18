import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../features/notes/note_amount_goal.dart';
import '../../features/notes/note_goal_block.dart';
import '../../features/goals/providers.dart';
import '../../features/settings/statement_period.dart';
import '../../features/accounts/fund_purpose.dart';

/// Old temporary drafts may still have a separate goal. Bring it into the body
/// before the next save, just like a legacy saved note.
void migrateLegacyGoalDraft(QuillController controller, NoteGoalDraft draft) {
  final goal = draft.goal;
  if (goal == null) return;
  controller.updateSelection(
    TextSelection.collapsed(offset: controller.document.length - 1),
    ChangeSource.local,
  );
  insertNoteGoalBlock(controller, newNoteGoalBlock('', goal));
  draft.enabled = false;
  draft.refresh();
}

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
  String source = 'manual';
  String? accountUuid;
  String? tagUuid;

  void restore(Note? note) {
    final goal = note == null ? null : NoteAmountGoal.fromNote(note);
    enabled = goal != null;
    target.text = goal == null ? '' : formatNoteAmount(goal.targetAmount);
    current.text = formatNoteAmount(goal?.currentAmount ?? 0);
    start = goal?.startDate ?? DateUtils.dateOnly(DateTime.now());
    due = goal?.dueDate;
    source = goal?.source ?? 'manual';
    accountUuid = goal?.accountUuid;
    tagUuid = goal?.tagUuid;
    addition.clear();
    additionError = null;
    notifyListeners();
  }

  NoteAmountGoal? get goal => !enabled
      ? null
      : NoteAmountGoal(
          targetAmount: parseNoteAmount(target.text) ?? 0,
          currentAmount: source == 'account'
              ? 0
              : parseNoteAmount(current.text) ?? 0,
          startDate: start,
          dueDate: due,
          source: source,
          accountUuid: source == 'manual' ? null : accountUuid,
          tagUuid: source == 'transactions' ? tagUuid : null,
        );

  String? get validationError {
    if (!enabled) return null;
    if (parseNoteAmount(target.text) == null) {
      return '목표 금액에 올바른 숫자나 계산식을 입력하세요.';
    }
    if (source != 'account' && parseNoteAmount(current.text) == null) {
      return '현재 금액에 올바른 숫자나 계산식을 입력하세요.';
    }
    return goal?.validationError;
  }

  void refresh() => notifyListeners();

  void addAmount(int? amount) {
    final existing = parseNoteAmount(current.text);
    if (amount == null ||
        amount == 0 ||
        existing == null ||
        amount.abs() > maxNoteGoalAmount ||
        existing.abs() > maxNoteGoalAmount ||
        (existing + amount).abs() > maxNoteGoalAmount) {
      additionError = '현재 금액과 추가 금액을 확인하세요. 0원이 아닌 금액을 입력하고 허용 범위를 넘지 않아야 합니다.';
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
  const NoteGoalForm({
    super.key,
    required this.draft,
    this.busy = false,
    this.showAdditionControls = true,
    this.allowLinking = false,
  });
  final NoteGoalDraft draft;
  final bool busy;
  final bool showAdditionControls;
  final bool allowLinking;

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
        if (draft.enabled) ...[
          if (allowLinking) GoalLinkFields(draft: draft, busy: busy),
          TextField(
            controller: draft.target,
            enabled: !busy,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: '목표 금액',
              suffixText: '원',
            ),
          ),
          if (draft.source != 'account')
            TextField(
              controller: draft.current,
              enabled: !busy,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: draft.source == 'transactions' ? '시작 금액' : '현재 금액',
                helperText: draft.source == 'transactions'
                    ? '시작일부터의 거래 순액이 이 금액에 더해집니다.'
                    : null,
                suffixText: '원',
              ),
            ),
          if (showAdditionControls && draft.source == 'manual') ...[
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
                    keyboardType: TextInputType.text,
                    onSubmitted: busy
                        ? null
                        : (_) => draft.addAmount(
                            parseNoteAmount(draft.addition.text),
                          ),
                    decoration: const InputDecoration(
                      labelText: '추가 금액',
                      helperText: '음수를 입력하면 현재 금액에서 차감합니다.',
                      suffixText: '원',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => draft.addAmount(
                          parseNoteAmount(draft.addition.text),
                        ),
                  child: const Text('금액 추가'),
                ),
              ],
            ),
            if (draft.additionError != null)
              Text(
                draft.additionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
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
  const NoteGoalSummary({
    super.key,
    required this.goal,
    this.compact = false,
    this.resolved = false,
    this.monthStartAmount,
    this.today,
  });
  final NoteAmountGoal goal;
  final bool compact;
  final bool resolved;
  final int? monthStartAmount;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    if (goal.isLinked && !resolved) {
      return LinkedNoteGoalSummary(goal: goal, compact: compact);
    }
    final now = today ?? DateTime.now();
    final needed = goal.monthlyNeeded(now, monthStartAmount: monthStartAmount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${formatNoteAmount(goal.currentAmount)} / ${formatNoteAmount(goal.targetAmount)}원',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(goal.percentage, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: goal.progress,
          minHeight: compact ? 4 : 8,
        ),
        const SizedBox(height: 4),
        Text(
          '남은 금액 ${formatNoteAmount(goal.remaining)}원',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          needed == null
              ? '이번 달 필요한 적립액 · 목표일을 설정해주세요'
              : '이번 달 필요한 적립액 ${formatNoteAmount(needed)}원',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (!compact && needed != null && goal.remaining > 0)
          Text(
            goal.dueDate != null &&
                    DateUtils.dateOnly(
                      now,
                    ).isAfter(DateUtils.dateOnly(goal.dueDate!))
                ? '목표일이 지났습니다. 남은 금액을 표시합니다.'
                : monthStartAmount == null
                ? '남은 금액을 목표일까지 남은 달 수로 나눈 예상액입니다.'
                : '월초 부족액을 남은 달 수로 나누고 이번 달 순적립액을 반영했습니다.',
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
}

class LinkedNoteGoalSummary extends ConsumerWidget {
  const LinkedNoteGoalSummary({
    super.key,
    required this.goal,
    this.compact = false,
  });
  final NoteAmountGoal goal;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(statementTodayProvider);
    return ref
        .watch(goalProgressProvider(goal))
        .when(
          loading: () => const Text('목표 금액 집계 중…'),
          error: (error, _) => TextButton(
            onPressed: () => ref.invalidate(goalProgressProvider(goal)),
            child: const Text('목표 집계를 다시 불러오기'),
          ),
          data: (progress) => progress.issue != null
              ? Text(progress.issue!)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${fundPurposeLabels[progress.fundPurpose]} · ${progress.accountName}${progress.archived ? ' (보관됨)' : ''}${progress.tagName == null ? '' : ' · #${progress.tagName}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      goal.source == 'account'
                          ? '오늘 계좌 잔액으로 자동 집계'
                          : '시작일 이후 거래로 자동 집계',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    NoteGoalSummary(
                      goal: progress.goal,
                      compact: compact,
                      resolved: true,
                      monthStartAmount: progress.monthStartAmount,
                      today: today,
                    ),
                  ],
                ),
        );
  }
}

class GoalLinkFields extends ConsumerWidget {
  const GoalLinkFields({super.key, required this.draft, this.busy = false});
  final NoteGoalDraft draft;
  final bool busy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(goalAccountsProvider);
    final tags = ref.watch(goalTagsProvider);
    final eligible = (accounts.asData?.value ?? [])
        .where(
          (a) =>
              a.kind != 'card' &&
              !a.isInvestment &&
              (a.archivedAt == null || a.uuid == draft.accountUuid),
        )
        .toList();
    final allTags = tags.asData?.value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('goal-source'),
          initialValue: draft.source,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '집계 방식'),
          items: const [
            DropdownMenuItem(value: 'manual', child: Text('직접 입력')),
            DropdownMenuItem(value: 'account', child: Text('계좌 잔액 자동 집계')),
            DropdownMenuItem(
              value: 'transactions',
              child: Text('연결 계좌 거래 자동 집계'),
            ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  draft.source = value!;
                  draft.refresh();
                },
        ),
        if (draft.source != 'manual') ...[
          DropdownButtonFormField<String>(
            key: const ValueKey('goal-account'),
            initialValue: draft.accountUuid ?? '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: '연결 계좌'),
            items: [
              const DropdownMenuItem(value: '', child: Text('계좌 선택')),
              for (final a in eligible)
                DropdownMenuItem(
                  value: a.uuid,
                  child: Text(
                    '${a.name} · ${fundPurposeLabels[normalizeFundPurpose(a.fundPurpose)]}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (draft.accountUuid != null &&
                  !eligible.any((a) => a.uuid == draft.accountUuid))
                DropdownMenuItem(
                  value: draft.accountUuid,
                  child: const Text('기존 연결 계좌 (확인 필요)'),
                ),
            ],
            onChanged: busy || !accounts.hasValue
                ? null
                : (value) {
                    draft.accountUuid = value == '' ? null : value;
                    draft.refresh();
                  },
          ),
          const Text(
            '계좌 용도는 자산 편집에서 생활비·비상금·연간 지출 준비금으로 구분합니다.',
            style: TextStyle(fontSize: 12),
          ),
          if (draft.source == 'transactions') ...[
            DropdownButtonFormField<String>(
              key: const ValueKey('goal-tag'),
              initialValue: draft.tagUuid ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: '연결 거래 태그 (선택사항)'),
              items: [
                const DropdownMenuItem(value: '', child: Text('모든 거래')),
                for (final tag in allTags)
                  DropdownMenuItem(
                    value: tag.uuid,
                    child: Text(
                      '#${tag.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (draft.tagUuid != null &&
                    !allTags.any((tag) => tag.uuid == draft.tagUuid))
                  DropdownMenuItem(
                    value: draft.tagUuid,
                    child: const Text('기존 연결 태그 (확인 필요)'),
                  ),
              ],
              onChanged: busy || !tags.hasValue
                  ? null
                  : (value) {
                      draft.tagUuid = value == '' ? null : value;
                      draft.refresh();
                    },
            ),
            const Text(
              '입금·이체로 적립하고 출금·지출은 차감합니다. 태그를 고르면 해당 태그 거래만 집계합니다.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          if (accounts.hasError || tags.hasError)
            TextButton(
              onPressed: () {
                ref.invalidate(goalAccountsProvider);
                ref.invalidate(goalTagsProvider);
              },
              child: const Text('연결 항목 다시 불러오기'),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
