import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../../features/recurring/logic.dart';
import '../../features/recurring/validation.dart';
import '../database.dart';
import '../sync_metadata.dart';
import '../tables/accounts.dart';
import '../tables/categories.dart';
import '../tables/recurring_transactions.dart';
import '../tables/tags.dart';
import '../tables/transactions.dart';

part 'recurring_dao.g.dart';

/// SPEC §3.7 / §4.8.2 / §5.1 — 반복 거래 조회·CRUD + 자동 backfill.

class RecurringListItem {
  const RecurringListItem({
    required this.recurring,
    this.accountName,
    this.categoryName,
    this.fromAccountName,
    this.toAccountName,
  });
  final RecurringTransaction recurring;
  final String? accountName;
  final String? categoryName;
  final String? fromAccountName;
  final String? toAccountName;
}

@DriftAccessor(
  tables: [
    RecurringTransactions,
    Transactions,
    Tags,
    TransactionTags,
    Accounts,
    Categories,
  ],
)
class RecurringDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringDaoMixin {
  RecurringDao(super.db);

  /// 활성 우선, id 순. 자산/카테고리명 동봉. SPEC §4.8.2.
  Future<List<RecurringListItem>> listRecurringTransactions() async {
    final recs =
        await (select(recurringTransactions)..orderBy([
              (r) =>
                  OrderingTerm(expression: r.active, mode: OrderingMode.desc),
              (r) => OrderingTerm(expression: r.id),
            ]))
            .get();

    final accNames = {
      for (final a in await select(accounts).get()) a.id: a.name,
    };
    final catNames = {
      for (final c in await select(categories).get()) c.id: c.name,
    };

    return recs
        .map(
          (r) => RecurringListItem(
            recurring: r,
            accountName: r.accountId == null ? null : accNames[r.accountId],
            categoryName: r.categoryId == null ? null : catNames[r.categoryId],
            fromAccountName: r.fromAccountId == null
                ? null
                : accNames[r.fromAccountId],
            toAccountName: r.toAccountId == null
                ? null
                : accNames[r.toAccountId],
          ),
        )
        .toList();
  }

  Future<int> saveRecurring({int? id, required RecurringDraft draft}) async {
    final tagNamesJson = draft.tagNames.isEmpty
        ? null
        : jsonEncode(draft.tagNames);

    if (id != null) {
      await (update(
        recurringTransactions,
      )..where((r) => r.id.equals(id))).write(
        RecurringTransactionsCompanion(
          name: Value(draft.name),
          type: Value(draft.type),
          amount: Value(draft.amount),
          memo: Value(draft.memo),
          accountId: Value(draft.accountId),
          categoryId: Value(draft.categoryId),
          fromAccountId: Value(draft.fromAccountId),
          toAccountId: Value(draft.toAccountId),
          frequency: Value(draft.frequency),
          dayOfMonth: Value(draft.dayOfMonth),
          dayOfWeek: Value(draft.dayOfWeek),
          occurredTime: Value(draft.occurredTime),
          startDate: Value(draft.startDate),
          endDate: Value(draft.endDate),
          tagNames: Value(tagNamesJson),
          updatedAt: Value(sqlNow()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
      return id;
    }
    return into(recurringTransactions).insert(
      RecurringTransactionsCompanion.insert(
        name: draft.name,
        type: draft.type,
        amount: draft.amount,
        memo: Value(draft.memo),
        accountId: Value(draft.accountId),
        categoryId: Value(draft.categoryId),
        fromAccountId: Value(draft.fromAccountId),
        toAccountId: Value(draft.toAccountId),
        frequency: draft.frequency,
        dayOfMonth: Value(draft.dayOfMonth),
        dayOfWeek: Value(draft.dayOfWeek),
        occurredTime: Value(draft.occurredTime),
        startDate: draft.startDate,
        endDate: Value(draft.endDate),
        tagNames: Value(tagNamesJson),
      ),
    );
  }

  Future<void> deleteRecurring(int id) async {
    await (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();
  }

  Future<void> toggleRecurringActive(int id, bool active) async {
    await (update(recurringTransactions)..where((r) => r.id.equals(id))).write(
      RecurringTransactionsCompanion(
        active: Value(active),
        updatedAt: Value(sqlNow()),
        syncStatus: const Value(syncStatusPending),
      ),
    );
  }

  /// SPEC §5.1 — 활성 반복거래의 lastGeneratedOn 이후 ~ horizon 누락분을
  /// transactions 에 backfill (멱등). 생성 건수 반환. 순수 dueOccurrences 재사용.
  Future<int> generateDueRecurringTransactions(String horizon) async {
    final recs = await (select(
      recurringTransactions,
    )..where((r) => r.active.equals(true))).get();

    var generated = 0;
    await transaction(() async {
      for (final r in recs) {
        // FK set-null 등으로 필수 자산/카테고리가 비면 건너뜀 (CHECK 위반 방지).
        if (r.type == 'transfer') {
          if (r.fromAccountId == null || r.toAccountId == null) continue;
        } else {
          if (r.accountId == null || r.categoryId == null) continue;
        }

        final rule = RecurrenceRule(
          frequency: r.frequency == 'weekly'
              ? RecurFrequency.weekly
              : RecurFrequency.monthly,
          startDate: r.startDate,
          dayOfMonth: r.dayOfMonth,
          dayOfWeek: r.dayOfWeek,
        );
        final occurrences = dueOccurrences(
          rule,
          lastGeneratedOn: r.lastGeneratedOn,
          horizon: horizon,
          endDate: r.endDate,
        );
        if (occurrences.isEmpty) continue;

        final tagNames = _parseTagNames(r.tagNames);

        for (final date in occurrences) {
          final int txId;
          if (r.type == 'transfer') {
            txId = await into(transactions).insert(
              TransactionsCompanion.insert(
                type: 'transfer',
                occurredOn: date,
                occurredTime: Value(r.occurredTime),
                amount: r.amount,
                memo: Value(r.memo),
                fromAccountId: Value(r.fromAccountId),
                toAccountId: Value(r.toAccountId),
              ),
            );
          } else {
            txId = await into(transactions).insert(
              TransactionsCompanion.insert(
                type: r.type,
                occurredOn: date,
                occurredTime: Value(r.occurredTime),
                amount: r.amount,
                memo: Value(r.memo),
                accountId: Value(r.accountId),
                categoryId: Value(r.categoryId),
              ),
            );
          }

          for (final name in tagNames) {
            final existing = await (select(
              tags,
            )..where((t) => t.name.equals(name))).getSingleOrNull();
            final tagId =
                existing?.id ??
                await into(tags).insert(
                  TagsCompanion.insert(
                    name: name,
                    color: const Value('#64748b'),
                    sortOrder: Value(await _nextTagSortOrder()),
                  ),
                );
            await into(transactionTags).insert(
              TransactionTagsCompanion.insert(
                transactionId: txId,
                tagId: tagId,
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
          generated++;
        }

        await (update(
          recurringTransactions,
        )..where((x) => x.id.equals(r.id))).write(
          RecurringTransactionsCompanion(
            lastGeneratedOn: Value(occurrences.last),
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
      }
    });
    return generated;
  }

  List<String> _parseTagNames(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // ignore
    }
    return const [];
  }

  Future<int> _nextTagSortOrder() async {
    final row = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) AS m FROM tags',
      readsFrom: {tags},
    ).getSingle();
    return row.read<int>('m') + 1;
  }
}
