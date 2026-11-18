import 'package:drift/drift.dart';

import '../core/date.dart';
import '../features/accounts/fund_purpose.dart';
import '../features/goals/progress.dart';
import '../features/notes/note_amount_goal.dart';
import 'database.dart';

class GoalProgressStore {
  GoalProgressStore(this.db);
  final AppDatabase db;

  Stream<LinkedGoalProgress> watch(NoteAmountGoal goal, DateTime today) {
    final accountMode = goal.source == 'account';
    final day = toDateKey(today);
    final monthStart = toDateKey(DateTime(today.year, today.month));
    const signedAmount = '''CASE WHEN t.type = 'transfer' THEN
      (CASE WHEN t.to_account_id = a.id THEN t.amount ELSE 0 END) -
      (CASE WHEN t.from_account_id = a.id THEN t.amount ELSE 0 END)
      WHEN t.type = 'expense' THEN -t.amount ELSE t.amount END''';
    return db
        .customSelect(
          '''
      SELECT a.name, a.kind, a.initial_balance, a.is_investment, a.archived_at,
        a.fund_purpose,
        (SELECT name FROM tags WHERE uuid = ? AND deleted_at IS NULL) AS tag_name,
        COALESCE(SUM(CASE WHEN t.occurred_on <= ? THEN $signedAmount ELSE 0 END), 0) AS current_delta,
        COALESCE(SUM(CASE WHEN t.occurred_on < ? THEN $signedAmount ELSE 0 END), 0) AS month_start_delta
      FROM accounts a
      LEFT JOIN transactions t ON (t.account_id = a.id OR t.from_account_id = a.id OR t.to_account_id = a.id)
        AND t.deleted_at IS NULL
        AND (? = 1 OR t.occurred_on >= ?)
        AND (? = '' OR EXISTS (SELECT 1 FROM transaction_tags tt JOIN tags g ON g.id = tt.tag_id
          WHERE tt.transaction_id = t.id AND g.uuid = ? AND g.deleted_at IS NULL))
      WHERE a.uuid = ? AND a.deleted_at IS NULL GROUP BY a.id
    ''',
          variables: [
            Variable<String>(goal.tagUuid ?? ''),
            Variable<String>(day),
            Variable<String>(monthStart),
            Variable<int>(accountMode ? 1 : 0),
            Variable<String>(toDateKey(goal.startDate)),
            Variable<String>(goal.tagUuid ?? ''),
            Variable<String>(goal.tagUuid ?? ''),
            Variable<String>(goal.accountUuid ?? ''),
          ],
          readsFrom: {
            db.accounts,
            db.transactions,
            db.tags,
            db.transactionTags,
          },
        )
        .watch()
        .map((rows) {
          if (rows.isEmpty) {
            return LinkedGoalProgress(
              goal: goal,
              issue: '연결 계좌를 찾을 수 없습니다. 목표 설정에서 계좌를 확인해주세요.',
            );
          }
          final row = rows.single;
          if (row.read<String>('kind') == 'card' ||
              row.read<int>('is_investment') != 0) {
            return LinkedGoalProgress(
              goal: goal,
              issue: '적립 목표는 카드·투자 이외의 계좌에 연결해주세요.',
            );
          }
          final tagName = row.readNullable<String>('tag_name');
          if (goal.tagUuid != null && tagName == null) {
            return LinkedGoalProgress(
              goal: goal,
              issue: '연결 태그를 찾을 수 없습니다. 목표 설정에서 태그를 확인해주세요.',
            );
          }
          final base = accountMode
              ? row.read<int>('initial_balance')
              : goal.currentAmount;
          return LinkedGoalProgress(
            goal: goal.withCurrentAmount(base + row.read<int>('current_delta')),
            monthStartAmount: base + row.read<int>('month_start_delta'),
            accountName: row.read<String>('name'),
            tagName: tagName,
            fundPurpose: normalizeFundPurpose(
              row.readNullable<String>('fund_purpose'),
            ),
            archived: row.readNullable<String>('archived_at') != null,
          );
        });
  }
}
