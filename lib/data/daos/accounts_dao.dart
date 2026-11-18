import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../../features/accounts/card_billing.dart';
import '../../features/accounts/fund_purpose.dart';
import '../../features/accounts/validation.dart';
import '../../features/investments/cost_basis.dart';
import '../database.dart';
import '../investment_mapping.dart';
import '../sync_metadata.dart';
import '../tables/accounts.dart';
import '../tables/budget_groups.dart';
import '../tables/investments.dart';
import '../tables/recurring_transactions.dart';
import '../tables/transactions.dart';

part 'accounts_dao.g.dart';

/// SPEC §3.1 / §3.9 / §4.2 — 자산 조회·잔액 계산·CRUD.

/// 자산 + 계산된 현재 잔액. = Tauri AccountBalance.
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.color,
    required this.initialBalance,
    required this.cardLimit,
    required this.excludeFromTotal,
    required this.isInvestment,
    required this.balance,
    int? projectedBalance,
    this.uuid = '',
    this.cardPaymentDay,
    this.cardClosingDay,
    this.cardPaymentAccountUuid,
    this.cardPaymentAccountName,
    this.cardBilling,
    this.cardSpendingToDate = 0,
    this.cardMonthSpending = 0,
    this.fundPurpose = 'living',
  }) : _projectedBalance = projectedBalance;

  final int accountId;
  final String name;
  final String kind;
  final String color;
  final int initialBalance;
  final int? cardLimit;
  final bool excludeFromTotal;
  final bool isInvestment;
  final int balance;
  final int? _projectedBalance;
  int get projectedBalance => _projectedBalance ?? balance;
  final String uuid;
  final int? cardPaymentDay;
  final int? cardClosingDay;
  final String? cardPaymentAccountUuid;
  final String? cardPaymentAccountName;
  final CardBillingSummary? cardBilling;

  /// Spending in the current period, independent of card repayment transfers.
  final int cardSpendingToDate;
  final int cardMonthSpending;
  final String fundPurpose;
}

@DriftAccessor(
  tables: [
    Accounts,
    Transactions,
    Investments,
    BudgetGroups,
    RecurringTransactions,
  ],
)
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// 활성 자산 (보관 제외). sortOrder, id 순.
  Future<List<Account>> getActiveAccounts() {
    return (select(accounts)
          ..where((a) => a.archivedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.sortOrder),
            (a) => OrderingTerm(expression: a.id),
          ]))
        .get();
  }

  Stream<List<Account>> watchActiveAccounts() {
    return (select(accounts)
          ..where((a) => a.archivedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm(expression: a.sortOrder),
            (a) => OrderingTerm(expression: a.id),
          ]))
        .watch();
  }

  /// 보관된 자산. archivedAt 순.
  Future<List<Account>> getArchivedAccounts() {
    return (select(accounts)
          ..where((a) => a.archivedAt.isNotNull())
          ..orderBy([(a) => OrderingTerm(expression: a.archivedAt)]))
        .get();
  }

  /// 활성 자산 + 자산 현황 잔액 (거래 합산 SQL + 투자 손익). SPEC §3.9.
  ///
  /// 모든 자산은 오늘까지의 잔액과 집계기간 말의 예상 잔액을 분리한다.
  Future<List<AccountBalance>> getAccountBalances({
    DateTime? asOf,
    String? statementStart,
    String? statementEnd,
  }) async {
    final localAsOf = asOf ?? DateTime.now();
    final today = toDateKey(localAsOf);
    final currentMonthEnd =
        statementEnd ?? monthRange(toMonthKey(localAsOf)).end;
    final currentMonthStart =
        statementStart ?? monthRange(toMonthKey(localAsOf)).start;
    final rows = await customSelect(
      '''
      WITH movements AS (
        SELECT account_id AS aid, occurred_on,
          CASE WHEN type = 'expense' THEN -amount ELSE amount END AS amount
        FROM transactions WHERE type IN ('income', 'expense', 'adjustment')
        UNION ALL
        SELECT from_account_id, occurred_on, -amount FROM transactions WHERE type = 'transfer'
        UNION ALL
        SELECT to_account_id, occurred_on, amount FROM transactions WHERE type = 'transfer'
      ), totals AS (
        SELECT aid,
          SUM(CASE WHEN occurred_on <= ? THEN amount ELSE 0 END) AS current_amount,
          SUM(CASE WHEN occurred_on <= ? THEN amount ELSE 0 END) AS projected_amount
        FROM movements GROUP BY aid
      ), spending AS (
        SELECT account_id AS aid,
          SUM(CASE WHEN occurred_on <= ? THEN
            CASE WHEN type = 'expense' THEN amount ELSE -amount END ELSE 0 END) AS spent_to_date,
          SUM(CASE WHEN type = 'expense' THEN amount ELSE -amount END) AS month_spending
        FROM transactions
        WHERE type IN ('expense', 'income', 'adjustment') AND occurred_on >= ? AND occurred_on <= ?
        GROUP BY account_id
      )
      SELECT
        a.id AS id, a.name AS name, a.kind AS kind, a.color AS color,
        a.uuid AS uuid,
        a.fund_purpose AS fund_purpose,
        a.card_payment_day AS card_payment_day,
        a.card_closing_day AS card_closing_day,
        a.card_payment_account_uuid AS card_payment_account_uuid,
        (SELECT name || CASE WHEN archived_at IS NOT NULL THEN ' (보관됨)' ELSE '' END
          FROM accounts WHERE uuid = a.card_payment_account_uuid) AS card_payment_account_name,
        a.initial_balance AS initial_balance,
        a.card_limit AS card_limit,
        a.exclude_from_total AS exclude_from_total,
        a.is_investment AS is_investment,
        a.initial_balance + COALESCE(t.current_amount, 0) AS balance,
        a.initial_balance + COALESCE(t.projected_amount, 0) AS projected_balance,
        COALESCE(s.spent_to_date, 0) AS spent_to_date,
        COALESCE(s.month_spending, 0) AS month_spending
      FROM accounts a LEFT JOIN totals t ON t.aid = a.id
      LEFT JOIN spending s ON s.aid = a.id
      WHERE a.archived_at IS NULL
      ORDER BY a.sort_order, a.id
      ''',
      variables: [
        Variable<String>(today),
        Variable<String>(currentMonthEnd),
        Variable<String>(today),
        Variable<String>(currentMonthStart),
        Variable<String>(currentMonthEnd),
      ],
      readsFrom: {accounts, transactions},
    ).get();

    final impact = await _investmentImpactByAccount(today, currentMonthEnd);
    final cardIds = rows
        .where((r) => r.read<String>('kind') == 'card')
        .map((r) => r.read<int>('id'))
        .toSet();
    final cardEntries = <int, List<CardBillingEntry>>{};
    if (cardIds.isNotEmpty) {
      final movements =
          await (select(transactions)..where(
                (t) =>
                    t.accountId.isIn(cardIds) |
                    t.fromAccountId.isIn(cardIds) |
                    t.toAccountId.isIn(cardIds),
              ))
              .get();
      void add(int? id, String date, int amount, {bool isAdjustment = false}) {
        if (cardIds.contains(id)) {
          (cardEntries[id!] ??= []).add(
            CardBillingEntry(date, amount, isAdjustment: isAdjustment),
          );
        }
      }

      for (final movement in movements) {
        if (movement.type == 'transfer') {
          add(movement.fromAccountId, movement.occurredOn, -movement.amount);
          add(movement.toAccountId, movement.occurredOn, movement.amount);
        } else {
          add(
            movement.accountId,
            movement.occurredOn,
            movement.type == 'expense' ? -movement.amount : movement.amount,
            isAdjustment: movement.type == 'adjustment',
          );
        }
      }
    }

    return rows.map((r) {
      final id = r.read<int>('id');
      final paymentDay = r.readNullable<int>('card_payment_day');
      final closingDay = r.readNullable<int>('card_closing_day');
      return AccountBalance(
        accountId: id,
        name: r.read<String>('name'),
        kind: r.read<String>('kind'),
        color: r.read<String>('color'),
        initialBalance: r.read<int>('initial_balance'),
        cardLimit: r.readNullable<int>('card_limit'),
        excludeFromTotal: r.read<int>('exclude_from_total') != 0,
        isInvestment: r.read<int>('is_investment') != 0,
        balance: r.read<int>('balance') + (impact.current[id] ?? 0),
        projectedBalance:
            r.read<int>('projected_balance') + (impact.projected[id] ?? 0),
        uuid: r.read<String>('uuid'),
        fundPurpose: normalizeFundPurpose(
          r.readNullable<String>('fund_purpose'),
        ),
        cardSpendingToDate: r.read<int>('spent_to_date'),
        cardMonthSpending: r.read<int>('month_spending'),
        cardPaymentDay: paymentDay,
        cardClosingDay: closingDay,
        cardPaymentAccountUuid: r.readNullable<String>(
          'card_payment_account_uuid',
        ),
        cardPaymentAccountName: r.readNullable<String>(
          'card_payment_account_name',
        ),
        cardBilling:
            r.read<String>('kind') == 'card' &&
                paymentDay != null &&
                closingDay != null &&
                paymentDay >= 1 &&
                paymentDay <= 31 &&
                closingDay >= 1 &&
                closingDay <= 31
            ? calculateCardBilling(
                today: localAsOf,
                paymentDay: paymentDay,
                closingDay: closingDay,
                initialBalance: r.read<int>('initial_balance'),
                entries: cardEntries[id] ?? const [],
              )
            : null,
      );
    }).toList();
  }

  Future<AccountBalance?> getAccountBalance(
    int id, {
    DateTime? asOf,
    String? statementStart,
    String? statementEnd,
  }) async {
    for (final b in await getAccountBalances(
      asOf: asOf,
      statementStart: statementStart,
      statementEnd: statementEnd,
    )) {
      if (b.accountId == id) return b;
    }
    return null;
  }

  /// 투자 손익을 자산별로 합산. 전체 투자기록을 한 번만 walk. SPEC §3.10.
  Future<({Map<int, int> current, Map<int, int> projected})>
  _investmentImpactByAccount(String today, String periodEnd) async {
    final all = await select(investments).get();
    final events = computeInvestmentEvents(all.map(toInvestmentEntry).toList());
    final current = <int, int>{};
    final projected = <int, int>{};
    for (final e in events) {
      final aid = e.accountId;
      if (aid == null) continue;
      if (e.occurredOn.compareTo(today) <= 0) {
        current[aid] = (current[aid] ?? 0) + e.balanceImpact;
      }
      if (e.occurredOn.compareTo(periodEnd) <= 0) {
        projected[aid] = (projected[aid] ?? 0) + e.balanceImpact;
      }
    }
    return (current: current, projected: projected);
  }

  /// 자산이 다른 기록에서 참조되는 총 횟수. 0 이면 hard delete 가능. SPEC §4.2.
  Future<int> getAccountUsageCount(int id) async {
    final row = await customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM transactions
           WHERE account_id = ? OR from_account_id = ? OR to_account_id = ?)
        + (SELECT COUNT(*) FROM investments WHERE account_id = ?)
        + (SELECT COUNT(*) FROM budget_groups WHERE account_id = ?)
        + (SELECT COUNT(*) FROM recurring_transactions
           WHERE account_id = ? OR from_account_id = ? OR to_account_id = ?)
        + (SELECT COUNT(*) FROM accounts WHERE card_payment_account_uuid =
           (SELECT uuid FROM accounts WHERE id = ?))
        AS n
      ''',
      variables: List.filled(9, Variable<int>(id)),
      readsFrom: {
        accounts,
        transactions,
        investments,
        budgetGroups,
        recurringTransactions,
      },
    ).getSingle();
    return row.read<int>('n');
  }

  /// 자산 저장. SPEC §4.2.
  ///   신규: currentBalance 가 initial_balance 로 저장.
  ///   편집: initial_balance 불변. 잔액 차이는 adjustment 거래로 기록.
  ///   isInvestment=true 면 다른 모든 자산을 false 로 강제 (단일 투자 자산).
  Future<void> saveAccount({
    int? id,
    required AccountDraft draft,
    required int currentBalance,
    DateTime? asOf,
    int? currentCardSpending,
    String? statementStart,
    String? statementEnd,
  }) async {
    await transaction(() async {
      final today = asOf ?? DateTime.now();
      if (currentCardSpending != null && draft.kind != 'card') {
        throw ArgumentError('카드 사용액은 신용카드 자산에만 적용할 수 있습니다.');
      }
      if (id != null && draft.kind != 'bank') {
        final linked = await customSelect(
          '''
          SELECT COUNT(*) AS n FROM accounts WHERE card_payment_account_uuid =
            (SELECT uuid FROM accounts WHERE id = ?)
          ''',
          variables: [Variable<int>(id)],
          readsFrom: {accounts},
        ).getSingle();
        if (linked.read<int>('n') > 0) {
          throw ArgumentError('카드 출금계좌 연결을 해제한 뒤 자산 종류를 변경해주세요.');
        }
      }
      final paymentUuid = draft.kind == 'card'
          ? draft.cardPaymentAccountUuid
          : null;
      if (paymentUuid != null) {
        final bank = await (select(
          accounts,
        )..where((a) => a.uuid.equals(paymentUuid))).getSingleOrNull();
        if (bank == null || bank.kind != 'bank' || bank.id == id) {
          throw ArgumentError('출금계좌는 은행 자산을 선택해주세요.');
        }
      }
      if (draft.isInvestment) {
        final clearOthers = update(accounts);
        if (id != null) clearOthers.where((a) => a.id.isNotValue(id));
        await clearOthers.write(
          AccountsCompanion(
            isInvestment: const Value(false),
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
      }

      if (id != null) {
        final before = await getAccountBalance(
          id,
          asOf: today,
          statementStart: statementStart,
          statementEnd: statementEnd,
        );
        final delta = currentCardSpending == null
            ? currentBalance - (before?.balance ?? 0)
            : (before?.cardSpendingToDate ?? 0) - currentCardSpending;

        await (update(accounts)..where((a) => a.id.equals(id))).write(
          AccountsCompanion(
            name: Value(draft.name),
            kind: Value(draft.kind),
            cardLimit: Value(draft.cardLimit),
            cardPaymentDay: Value(
              draft.kind == 'card' ? draft.cardPaymentDay : null,
            ),
            cardClosingDay: Value(
              draft.kind == 'card' ? draft.cardClosingDay : null,
            ),
            cardPaymentAccountUuid: Value(paymentUuid),
            fundPurpose: Value(
              !(draft.kind == 'cash' || draft.kind == 'bank') ||
                      draft.isInvestment
                  ? 'living'
                  : draft.fundPurpose,
            ),
            color: Value(draft.color),
            excludeFromTotal: Value(draft.excludeFromTotal),
            isInvestment: Value(draft.isInvestment),
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
            // initialBalance 는 의도적으로 건드리지 않음.
          ),
        );

        if (delta != 0) {
          await into(transactions).insert(
            TransactionsCompanion.insert(
              type: 'adjustment',
              occurredOn: toDateKey(today),
              occurredTime: Value(nowTime()),
              amount: delta,
              accountId: Value(id),
              memo: Value(currentCardSpending == null ? '잔액 조정' : '카드 사용액 조정'),
            ),
          );
        }
      } else {
        final newId = await into(accounts).insert(
          AccountsCompanion.insert(
            name: draft.name,
            kind: draft.kind,
            initialBalance: Value(
              currentCardSpending == null ? currentBalance : 0,
            ),
            cardLimit: Value(draft.cardLimit),
            cardPaymentDay: Value(
              draft.kind == 'card' ? draft.cardPaymentDay : null,
            ),
            cardClosingDay: Value(
              draft.kind == 'card' ? draft.cardClosingDay : null,
            ),
            cardPaymentAccountUuid: Value(paymentUuid),
            fundPurpose: Value(
              !(draft.kind == 'cash' || draft.kind == 'bank') ||
                      draft.isInvestment
                  ? 'living'
                  : draft.fundPurpose,
            ),
            color: Value(draft.color),
            excludeFromTotal: Value(draft.excludeFromTotal),
            isInvestment: Value(draft.isInvestment),
          ),
        );
        if (currentCardSpending != null && currentCardSpending != 0) {
          await into(transactions).insert(
            TransactionsCompanion.insert(
              type: 'adjustment',
              occurredOn: toDateKey(today),
              occurredTime: Value(nowTime()),
              amount: -currentCardSpending,
              accountId: Value(newId),
              memo: const Value('카드 사용액 조정'),
            ),
          );
        }
      }
    });
  }

  Future<void> archiveAccount(int id) async {
    await customUpdate(
      "UPDATE accounts SET archived_at = datetime('now'), updated_at = datetime('now'), sync_status = '$syncStatusPending' WHERE id = ?",
      variables: [Variable<int>(id)],
      updates: {accounts},
    );
  }

  Future<void> restoreAccount(int id) async {
    await (update(accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: const Value(null),
        updatedAt: Value(sqlNow()),
        syncStatus: const Value(syncStatusPending),
      ),
    );
  }

  /// 참조 0건일 때만 영구 삭제. 사용 중이면 에러 메시지 반환, 성공 시 null. SPEC §4.2.
  Future<String?> deleteAccount(int id) async {
    final usage = await getAccountUsageCount(id);
    if (usage > 0) {
      return '이 자산은 $usage건의 기록에 사용 중이라 삭제할 수 없습니다. '
          '먼저 해당 기록을 정리해주세요.';
    }
    await (delete(accounts)..where((a) => a.id.equals(id))).go();
    return null;
  }

  Future<void> updateAccountOrder(List<int> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(
          accounts,
        )..where((a) => a.id.equals(orderedIds[i]))).write(
          AccountsCompanion(
            sortOrder: Value(i),
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
      }
    });
  }
}
