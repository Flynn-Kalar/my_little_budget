import 'dart:convert';

import 'database.dart';

/// SPEC §5.2 — 백업 JSON 모델 + 파싱.

const backupVersion = 1;
const backupAppName = 'my_little_budget';

class Backup {
  const Backup({
    required this.exportedAt,
    required this.accounts,
    required this.categories,
    required this.budgetGroups,
    required this.budgetGroupCategories,
    required this.transactions,
    required this.investments,
    required this.tags,
    required this.transactionTags,
    required this.monthlyIncome,
    required this.recurringTransactions,
  });

  final String exportedAt;
  final List<Account> accounts;
  final List<Category> categories;
  final List<BudgetGroup> budgetGroups;
  final List<BudgetGroupCategoryLink> budgetGroupCategories;
  final List<Transaction> transactions;
  final List<Investment> investments;
  final List<Tag> tags;
  final List<TransactionTagLink> transactionTags;
  final List<MonthlyIncomeRow> monthlyIncome;
  final List<RecurringTransaction> recurringTransactions;

  Map<String, dynamic> toJson() => {
    'version': backupVersion,
    'appName': backupAppName,
    'exportedAt': exportedAt,
    'data': {
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'budgetGroups': budgetGroups.map((e) => e.toJson()).toList(),
      'budgetGroupCategories': budgetGroupCategories
          .map((e) => e.toJson())
          .toList(),
      'transactions': transactions.map((e) => e.toJson()).toList(),
      'investments': investments.map((e) => e.toJson()).toList(),
      'tags': tags.map((e) => e.toJson()).toList(),
      'transactionTags': transactionTags.map((e) => e.toJson()).toList(),
      'monthlyIncome': monthlyIncome.map((e) => e.toJson()).toList(),
      'recurringTransactions': recurringTransactions
          .map((e) => e.toJson())
          .toList(),
    },
  };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class BackupParseResult {
  const BackupParseResult.ok(Backup this.backup) : error = null;
  const BackupParseResult.fail(String this.error) : backup = null;

  final Backup? backup;
  final String? error;

  bool get isOk => backup != null;
}

/// SPEC §5.2 — JSON 문자열 → Backup. boolish(0/1↔true/false) 호환 정규화 포함.
BackupParseResult parseBackup(String jsonString) {
  late final dynamic raw;
  try {
    raw = jsonDecode(jsonString);
  } catch (_) {
    return const BackupParseResult.fail('올바른 JSON 파일이 아닙니다');
  }
  if (raw is! Map) return const BackupParseResult.fail('백업 파일 형식이 올바르지 않습니다');

  if (raw['version'] != backupVersion) {
    return BackupParseResult.fail('지원하지 않는 버전입니다 (${raw['version']})');
  }
  if (raw['appName'] != backupAppName) {
    return const BackupParseResult.fail('이 앱의 백업이 아닙니다');
  }

  final data = raw['data'];
  if (data is! Map) return const BackupParseResult.fail('data 필드가 없습니다');

  try {
    return BackupParseResult.ok(
      Backup(
        exportedAt: raw['exportedAt'] as String? ?? '',
        accounts: _list(data['accounts'])
            .map(
              (j) => Account.fromJson(
                _bools(j, const ['excludeFromTotal', 'isInvestment']),
              ),
            )
            .toList(),
        categories: _list(data['categories']).map(Category.fromJson).toList(),
        budgetGroups: _list(data['budgetGroups'])
            .map((j) => BudgetGroup.fromJson(_bools(j, const ['carryForward'])))
            .toList(),
        budgetGroupCategories: _list(
          data['budgetGroupCategories'],
        ).map(BudgetGroupCategoryLink.fromJson).toList(),
        transactions: _list(
          data['transactions'],
        ).map(Transaction.fromJson).toList(),
        investments: _list(
          data['investments'],
        ).map(Investment.fromJson).toList(),
        tags: _list(
          data['tags'],
        ).map((j) => Tag.fromJson(_tagJson(j))).toList(),
        transactionTags: _list(
          data['transactionTags'],
        ).map(TransactionTagLink.fromJson).toList(),
        monthlyIncome: _list(
          data['monthlyIncome'],
        ).map(MonthlyIncomeRow.fromJson).toList(),
        recurringTransactions: _list(data['recurringTransactions'])
            .map(
              (j) => RecurringTransaction.fromJson(_bools(j, const ['active'])),
            )
            .toList(),
      ),
    );
  } catch (e) {
    return BackupParseResult.fail('파일 형식 오류: $e');
  }
}

/// SPEC §5.2 — 백업 파일명: my_little_budget-backup-YYYYMMDD-HHMMSS.json
String buildBackupFilename({DateTime? now}) {
  final d = now ?? DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'my_little_budget-backup-${d.year}${two(d.month)}${two(d.day)}-'
      '${two(d.hour)}${two(d.minute)}${two(d.second)}.json';
}

List<Map<String, dynamic>> _list(Object? v) =>
    (v is List ? v : const []).cast<Map<String, dynamic>>();

/// 백업 JSON 의 bool 필드는 SQLite 시절(int 0/1) 또는 신규(true/false) 둘 다 허용.
/// drift fromJson 은 bool 만 받으므로 미리 정규화.
Map<String, Object?> _bools(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is int) m[k] = v != 0;
  }
  return m;
}

Map<String, Object?> _tagJson(Map<String, dynamic> m) {
  m['usageCount'] ??= 0;
  m['isPinned'] ??= false;
  return _bools(m, const ['isPinned']);
}
