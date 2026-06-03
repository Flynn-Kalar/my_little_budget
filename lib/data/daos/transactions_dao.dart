import 'package:drift/drift.dart';

import '../../core/colors.dart';
import '../../core/date.dart';
import '../../features/investments/cost_basis.dart';
import '../../features/transactions/validation.dart';
import '../database.dart';
import '../investment_mapping.dart';
import '../tables/accounts.dart';
import '../tables/categories.dart';
import '../tables/investments.dart';
import '../tables/tags.dart';
import '../tables/transactions.dart';

part 'transactions_dao.g.dart';

/// SPEC §3.3 / §4.1 — 거래 조회·검색·CRUD·태그.

class TransactionTagInfo {
  const TransactionTagInfo({
    required this.id,
    required this.name,
    required this.color,
  });
  final int id;
  final String name;
  final String color;
}

/// 조인된 자산/카테고리명까지 채운 거래 한 줄. = Tauri TransactionRow.
class TransactionRow {
  const TransactionRow({
    required this.id,
    required this.type,
    required this.occurredOn,
    required this.occurredTime,
    required this.amount,
    this.memo,
    this.accountId,
    this.accountName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.fromAccountId,
    this.fromAccountName,
    this.toAccountId,
    this.toAccountName,
    this.tags = const [],
    this.source,
    this.investmentSide,
    this.ticker,
    this.quantity,
    this.originalAmount,
    this.costBasis,
    this.balanceImpact,
  });

  final int id;
  final String type;
  final String occurredOn;
  final String occurredTime;
  final int amount;
  final String? memo;
  final int? accountId;
  final String? accountName;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final int? fromAccountId;
  final String? fromAccountName;
  final int? toAccountId;
  final String? toAccountName;
  final List<TransactionTagInfo> tags;

  /// 자산 상세에서 투자 활동을 가상 행으로 끼워넣을 때만 'investment'. SPEC §4.3.
  final String? source;
  final String? investmentSide; // buy | sell | dividend
  final String? ticker;
  final double? quantity; // 마이그 0015: 소수점
  final int? originalAmount;
  final int? costBasis;
  final int? balanceImpact;
}

/// SPEC §4.5 — 지출 카테고리 도넛/범례.
class CategoryBreakdownRow {
  const CategoryBreakdownRow({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.total,
  });
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final int total;
}

/// SPEC §4.5 — 12개월 추세.
class MonthlyTrendRow {
  const MonthlyTrendRow({
    required this.month,
    required this.income,
    required this.expense,
  });
  final String month;
  final int income;
  final int expense;
  int get net => income - expense;
}

/// SPEC §4.6 — 연간 카테고리×월 피벗.
class YearlyPivotRow {
  YearlyPivotRow({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.months,
  });
  final int? categoryId;
  final String categoryName;
  final String categoryColor;
  final List<int> months; // length 12 (1월=index 0)
  int get total => months.fold(0, (s, v) => s + v);
}

/// SPEC §4.1 의 검색/필터 조건.
class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.q,
    this.minAmount,
    this.maxAmount,
    this.accountId,
    this.categoryIds,
    this.tagIds,
    this.untaggedOnly = false,
    this.fromDate,
    this.toDate,
  });

  final String? type;
  final String? q;
  final int? minAmount;
  final int? maxAmount;
  final int? accountId;
  final List<int>? categoryIds;
  final List<int>? tagIds;
  final bool untaggedOnly;
  final String? fromDate;
  final String? toDate;
}

class MonthlySummary {
  const MonthlySummary(this.income, this.expense);
  final int income;
  final int expense;
  int get net => income - expense;
}

@DriftAccessor(tables: [Transactions, Accounts, Categories, Tags, TransactionTags, Investments])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// SPEC §4.1 — 월/필터 기준 거래 목록. 검색 활성 시 전체 기간으로 확장.
  Future<List<TransactionRow>> listTransactionsByMonth(
    String month, {
    TransactionFilter filter = const TransactionFilter(),
  }) async {
    final bounds = monthRange(month);
    final hasDate = filter.fromDate != null || filter.toDate != null;
    final hasSearch = filter.q != null ||
        filter.minAmount != null ||
        filter.maxAmount != null ||
        filter.accountId != null ||
        (filter.categoryIds?.isNotEmpty ?? false) ||
        (filter.tagIds?.isNotEmpty ?? false) ||
        filter.untaggedOnly;

    final String start;
    final String end;
    if (hasDate) {
      start = filter.fromDate ?? '0000-01-01';
      end = filter.toDate ?? '9999-12-31';
    } else if (hasSearch) {
      start = '0000-01-01';
      end = '9999-12-31';
    } else {
      start = bounds.start;
      end = bounds.end;
    }

    final where = <String>['t.occurred_on BETWEEN ? AND ?'];
    final vars = <Variable>[Variable<String>(start), Variable<String>(end)];

    if (filter.type != null) {
      where.add('t.type = ?');
      vars.add(Variable<String>(filter.type!));
    } else {
      // adjustment 는 내역에서 항상 제외 (자산 상세에서만).
      where.add("t.type <> 'adjustment'");
    }

    if (filter.minAmount != null) {
      where.add('t.amount >= ?');
      vars.add(Variable<int>(filter.minAmount!));
    }
    if (filter.maxAmount != null) {
      where.add('t.amount <= ?');
      vars.add(Variable<int>(filter.maxAmount!));
    }

    if (filter.accountId != null) {
      where.add('(t.account_id = ? OR t.from_account_id = ? OR t.to_account_id = ?)');
      vars.addAll(List.filled(3, Variable<int>(filter.accountId!)));
    }

    final catIds = filter.categoryIds;
    if (catIds != null && catIds.isNotEmpty) {
      where.add('t.category_id IN (${_placeholders(catIds.length)})');
      vars.addAll(catIds.map(Variable<int>.new));
    }

    if (filter.untaggedOnly) {
      where.add("(t.type = 'income' OR t.type = 'expense')");
      where.add('t.id NOT IN (SELECT transaction_id FROM transaction_tags)');
    } else {
      final tagIds = filter.tagIds;
      if (tagIds != null && tagIds.isNotEmpty) {
        where.add('t.id IN (SELECT transaction_id FROM transaction_tags '
            'WHERE tag_id IN (${_placeholders(tagIds.length)}))');
        vars.addAll(tagIds.map(Variable<int>.new));
      }
    }

    final q = filter.q?.trim();
    if (q != null && q.isNotEmpty) {
      final needle = '%$q%';
      where.add('(t.memo LIKE ? OR c.name LIKE ? OR a.name LIKE ? '
          'OR fa.name LIKE ? OR ta.name LIKE ?)');
      vars.addAll(List.filled(5, Variable<String>(needle)));
    }

    final rows = await customSelect(
      '''
      SELECT
        t.id, t.type, t.occurred_on, t.occurred_time, t.amount, t.memo,
        t.account_id, a.name AS account_name,
        t.category_id, c.name AS category_name, c.color AS category_color,
        t.from_account_id, fa.name AS from_account_name,
        t.to_account_id, ta.name AS to_account_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts fa ON fa.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      WHERE ${where.join(' AND ')}
      ORDER BY t.occurred_on DESC, t.occurred_time DESC, t.id DESC
      ''',
      variables: vars,
      readsFrom: {transactions, accounts, categories, transactionTags},
    ).get();

    final tagMap = await _tagsFor(rows.map((r) => r.read<int>('id')).toList());
    return rows.map((r) => _rowFromQuery(r, tagMap)).toList();
  }

  /// SPEC §4.1 — 월 수입/지출/순수입. (transfer·adjustment 제외)
  Future<MonthlySummary> monthlySummary(String month) async {
    final b = monthRange(month);
    final rows = await customSelect(
      'SELECT type, COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE occurred_on BETWEEN ? AND ? GROUP BY type',
      variables: [Variable<String>(b.start), Variable<String>(b.end)],
      readsFrom: {transactions},
    ).get();

    var income = 0;
    var expense = 0;
    for (final r in rows) {
      switch (r.read<String>('type')) {
        case 'income':
          income = r.read<int>('total');
        case 'expense':
          expense = r.read<int>('total');
      }
    }
    return MonthlySummary(income, expense);
  }

  /// SPEC §4.5 — 지출 카테고리별 합. 카테고리 없는 지출은 '미분류' 로 집계.
  Future<List<CategoryBreakdownRow>> expenseByCategory(String month) async {
    final b = monthRange(month);
    final rows = await customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.color AS color,
        COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.occurred_on BETWEEN ? AND ? AND t.type = 'expense'
      GROUP BY c.id
      ORDER BY SUM(t.amount) DESC
      ''',
      variables: [Variable<String>(b.start), Variable<String>(b.end)],
      readsFrom: {transactions, categories},
    ).get();
    return rows
        .map((r) => CategoryBreakdownRow(
              categoryId: r.readNullable<int>('id') ?? 0,
              categoryName: r.readNullable<String>('name') ?? '미분류',
              categoryColor: r.readNullable<String>('color') ?? '#94a3b8',
              total: r.read<int>('total'),
            ))
        .toList();
  }

  /// SPEC §4.5 — 최근 n개월(anchorMonth 포함) 수입/지출/순수입. 거래 없는 달은 0.
  Future<List<MonthlyTrendRow>> monthlyTrend(int n, String anchorMonth) async {
    final ad = parseMonthKey(anchorMonth);
    final months = <String>[
      for (var i = n - 1; i >= 0; i--)
        toMonthKey(DateTime(ad.year, ad.month - i, 1)),
    ];
    final start = '${months.first}-01';
    final last = parseMonthKey(months.last);
    final endDate = DateTime(last.year, last.month + 1, 0);
    final end = toDateKey(endDate);

    final rows = await customSelect(
      'SELECT substr(occurred_on, 1, 7) AS m, type, '
      'COALESCE(SUM(amount), 0) AS total FROM transactions '
      'WHERE occurred_on BETWEEN ? AND ? GROUP BY m, type',
      variables: [Variable<String>(start), Variable<String>(end)],
      readsFrom: {transactions},
    ).get();

    final map = <String, (int income, int expense)>{
      for (final m in months) m: (0, 0),
    };
    for (final r in rows) {
      final m = r.read<String>('m');
      final cur = map[m];
      if (cur == null) continue;
      final total = r.read<int>('total');
      switch (r.read<String>('type')) {
        case 'income':
          map[m] = (total, cur.$2);
        case 'expense':
          map[m] = (cur.$1, total);
      }
    }
    return [
      for (final m in months)
        MonthlyTrendRow(month: m, income: map[m]!.$1, expense: map[m]!.$2),
    ];
  }

  /// SPEC §4.6 — 연간 카테고리 × 월 피벗. 사용 내역 없는 카테고리는 제외, 총액 내림차순.
  Future<List<YearlyPivotRow>> yearlyCategoryPivot(int year, String type) async {
    final start = '$year-01-01';
    final end = '$year-12-31';
    final rows = await customSelect(
      '''
      SELECT c.id AS cid, c.name AS cname, c.color AS ccolor,
        substr(t.occurred_on, 6, 2) AS m,
        COALESCE(SUM(t.amount), 0) AS total
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      WHERE t.occurred_on BETWEEN ? AND ? AND t.type = ?
      GROUP BY c.id, substr(t.occurred_on, 6, 2)
      ''',
      variables: [
        Variable<String>(start),
        Variable<String>(end),
        Variable<String>(type),
      ],
      readsFrom: {transactions, categories},
    ).get();

    final byCat = <String, YearlyPivotRow>{};
    for (final r in rows) {
      final cid = r.readNullable<int>('cid');
      final key = '${cid ?? 0}';
      final entry = byCat.putIfAbsent(
        key,
        () => YearlyPivotRow(
          categoryId: cid,
          categoryName: r.readNullable<String>('cname') ?? '미분류',
          categoryColor: r.readNullable<String>('ccolor') ?? '#94a3b8',
          months: List.filled(12, 0, growable: false),
        ),
      );
      final mi = int.parse(r.read<String>('m')) - 1;
      if (mi >= 0 && mi < 12) entry.months[mi] = r.read<int>('total');
    }
    return byCat.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  /// SPEC §4.6 — 거래가 존재한 연도 (네비게이션 칩용).
  Future<List<int>> availableTransactionYears() async {
    final rows = await customSelect(
      'SELECT DISTINCT substr(occurred_on, 1, 4) AS y FROM transactions ORDER BY y',
      readsFrom: {transactions},
    ).get();
    return rows.map((r) => int.parse(r.read<String>('y'))).toList();
  }

  Future<TransactionRow?> getTransactionById(int id) async {
    final rows = await customSelect(
      '''
      SELECT
        t.id, t.type, t.occurred_on, t.occurred_time, t.amount, t.memo,
        t.account_id, a.name AS account_name,
        t.category_id, c.name AS category_name, c.color AS category_color,
        t.from_account_id, fa.name AS from_account_name,
        t.to_account_id, ta.name AS to_account_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts fa ON fa.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      WHERE t.id = ?
      ''',
      variables: [Variable<int>(id)],
      readsFrom: {transactions, accounts, categories},
    ).get();
    if (rows.isEmpty) return null;
    final tagMap = await _tagsFor([id]);
    return _rowFromQuery(rows.first, tagMap);
  }

  /// SPEC §4.3 — 자산 상세의 거래 목록. 일반 거래(income/expense/transfer/adjustment)
  /// + 그 자산에 귀속된 투자 이벤트를 가상 행으로 끼워넣고 최신순 정렬.
  /// 같은 시각이면 일반 거래 > 투자 (안정 정렬).
  Future<List<TransactionRow>> listTransactionsByAccount(int accountId) async {
    final baseRows = await customSelect(
      '''
      SELECT
        t.id, t.type, t.occurred_on, t.occurred_time, t.amount, t.memo,
        t.account_id, a.name AS account_name,
        t.category_id, c.name AS category_name, c.color AS category_color,
        t.from_account_id, fa.name AS from_account_name,
        t.to_account_id, ta.name AS to_account_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN accounts fa ON fa.id = t.from_account_id
      LEFT JOIN accounts ta ON ta.id = t.to_account_id
      WHERE
        ((t.type IN ('income','expense') AND t.account_id = ?)
         OR (t.type = 'transfer' AND (t.from_account_id = ? OR t.to_account_id = ?))
         OR (t.type = 'adjustment' AND t.account_id = ?))
      ''',
      variables: List.filled(4, Variable<int>(accountId)),
      readsFrom: {transactions, accounts, categories},
    ).get();

    final tagMap =
        await _tagsFor(baseRows.map((r) => r.read<int>('id')).toList());
    final txRows = baseRows.map((r) => _rowFromQuery(r, tagMap)).toList();

    // 투자 가상 행
    final allInv = await select(investments).get();
    final events =
        eventsForAccount(allInv.map(toInvestmentEntry).toList(), accountId);

    const sideColor = {
      InvestmentSide.buy: '#94a3b8',
      InvestmentSide.sell: '#22c55e',
      InvestmentSide.dividend: '#a78bfa',
    };
    const sideLabel = {
      InvestmentSide.buy: '매수',
      InvestmentSide.sell: '매도',
      InvestmentSide.dividend: '배당',
    };

    final invVirtual = events
        .map((e) => TransactionRow(
              id: e.id,
              // 잔액 영향 기준 표시 색: +→income, −→expense, 0(매수)→expense 스타일
              type: e.balanceImpact > 0 ? 'income' : 'expense',
              occurredOn: e.occurredOn,
              occurredTime: e.occurredTime,
              amount: e.balanceImpact.abs(),
              accountId: accountId,
              categoryName: '${sideLabel[e.side]} · ${e.ticker}',
              categoryColor: sideColor[e.side],
              source: 'investment',
              investmentSide: e.side.name,
              ticker: e.ticker,
              quantity: e.quantity,
              originalAmount: e.originalAmount,
              costBasis: e.costBasis,
              balanceImpact: e.balanceImpact,
            ))
        .toList();

    final merged = [...txRows, ...invVirtual]
      ..sort((a, b) {
        final d = b.occurredOn.compareTo(a.occurredOn);
        if (d != 0) return d;
        final t = b.occurredTime.compareTo(a.occurredTime);
        if (t != 0) return t;
        final aInv = a.source == 'investment' ? 1 : 0;
        final bInv = b.source == 'investment' ? 1 : 0;
        if (aInv != bInv) return aInv - bInv;
        return b.id.compareTo(a.id);
      });
    return merged;
  }

  /// 거래 저장 + 태그 이름 매핑 갱신. 검증을 통과한 draft 만 받는다. SPEC §4.1.
  Future<int> saveTransaction({
    int? id,
    required TransactionDraft draft,
    List<String> tagNames = const [],
  }) async {
    return transaction(() async {
      final int txId;
      if (id != null) {
        await (update(transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            type: Value(draft.type),
            occurredOn: Value(draft.occurredOn),
            occurredTime: Value(draft.occurredTime),
            amount: Value(draft.amount),
            memo: Value(draft.memo),
            accountId: Value(draft.accountId),
            categoryId: Value(draft.categoryId),
            fromAccountId: Value(draft.fromAccountId),
            toAccountId: Value(draft.toAccountId),
            updatedAt: Value(sqlNow()),
          ),
        );
        txId = id;
      } else {
        txId = await into(transactions).insert(
          TransactionsCompanion.insert(
            type: draft.type,
            occurredOn: draft.occurredOn,
            occurredTime: Value(draft.occurredTime),
            amount: draft.amount,
            memo: Value(draft.memo),
            accountId: Value(draft.accountId),
            categoryId: Value(draft.categoryId),
            fromAccountId: Value(draft.fromAccountId),
            toAccountId: Value(draft.toAccountId),
          ),
        );
      }
      await _setTagsByName(txId, tagNames);
      return txId;
    });
  }

  Future<void> deleteTransaction(int id) async {
    await (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  /// SPEC §4.1 — 메모 자동완성용. 최근 거래의 distinct(trim) memo, limit 개까지.
  Future<List<String>> getRecentMemos({int limit = 300}) async {
    final rows = await (select(transactions)
          ..where((t) => t.memo.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit * 4))
        .get();
    final seen = <String>{};
    final result = <String>[];
    for (final r in rows) {
      final m = r.memo?.trim();
      if (m == null || m.isEmpty || seen.contains(m)) continue;
      seen.add(m);
      result.add(m);
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<List<TransactionTagInfo>> getTransactionTags(int txId) async {
    return (await _tagsFor([txId]))[txId] ?? const [];
  }

  /// SPEC §4.1 — 태그 이름 배열로 매핑 재설정. 신규 이름은 tags 에 자동 INSERT.
  Future<void> _setTagsByName(int txId, List<String> names) async {
    final cleaned = <String>{
      for (final n in names)
        if (n.trim().isNotEmpty && n.trim().length <= 20) n.trim(),
    };

    final ids = <int>[];
    for (final name in cleaned) {
      final existing =
          await (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
      if (existing != null) {
        ids.add(existing.id);
      } else {
        ids.add(await into(tags).insert(
          TagsCompanion.insert(name: name, color: Value(randomColor())),
        ));
      }
    }

    await (delete(transactionTags)..where((tt) => tt.transactionId.equals(txId)))
        .go();
    for (final tagId in ids) {
      await into(transactionTags).insert(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<Map<int, List<TransactionTagInfo>>> _tagsFor(List<int> txIds) async {
    if (txIds.isEmpty) return {};
    final rows = await customSelect(
      'SELECT tt.transaction_id AS tx, tg.id AS id, tg.name AS name, '
      'tg.color AS color FROM transaction_tags tt '
      'JOIN tags tg ON tg.id = tt.tag_id '
      'WHERE tt.transaction_id IN (${_placeholders(txIds.length)}) '
      'ORDER BY tg.name',
      variables: txIds.map(Variable<int>.new).toList(),
      readsFrom: {transactionTags, tags},
    ).get();

    final map = <int, List<TransactionTagInfo>>{};
    for (final r in rows) {
      (map[r.read<int>('tx')] ??= []).add(TransactionTagInfo(
        id: r.read<int>('id'),
        name: r.read<String>('name'),
        color: r.read<String>('color'),
      ));
    }
    return map;
  }

  TransactionRow _rowFromQuery(
    QueryRow r,
    Map<int, List<TransactionTagInfo>> tagMap,
  ) {
    final id = r.read<int>('id');
    return TransactionRow(
      id: id,
      type: r.read<String>('type'),
      occurredOn: r.read<String>('occurred_on'),
      occurredTime: r.read<String>('occurred_time'),
      amount: r.read<int>('amount'),
      memo: r.readNullable<String>('memo'),
      accountId: r.readNullable<int>('account_id'),
      accountName: r.readNullable<String>('account_name'),
      categoryId: r.readNullable<int>('category_id'),
      categoryName: r.readNullable<String>('category_name'),
      categoryColor: r.readNullable<String>('category_color'),
      fromAccountId: r.readNullable<int>('from_account_id'),
      fromAccountName: r.readNullable<String>('from_account_name'),
      toAccountId: r.readNullable<int>('to_account_id'),
      toAccountName: r.readNullable<String>('to_account_name'),
      tags: tagMap[id] ?? const [],
    );
  }
}

String _placeholders(int n) => List.filled(n, '?').join(', ');
