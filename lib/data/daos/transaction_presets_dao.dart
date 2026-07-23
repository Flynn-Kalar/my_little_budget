import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../../features/presets/validation.dart';
import '../database.dart';
import '../sync_metadata.dart';
import '../tables/accounts.dart';
import '../tables/categories.dart';
import '../tables/transaction_presets.dart';

part 'transaction_presets_dao.g.dart';

class TransactionPresetListItem {
  const TransactionPresetListItem({
    required this.preset,
    required this.tagNames,
    this.accountName,
    this.categoryName,
    this.fromAccountName,
    this.toAccountName,
    this.accountArchived = false,
    this.categoryArchived = false,
    this.fromAccountArchived = false,
    this.toAccountArchived = false,
  });

  final TransactionPreset preset;
  final List<String> tagNames;
  final String? accountName;
  final String? categoryName;
  final String? fromAccountName;
  final String? toAccountName;
  final bool accountArchived;
  final bool categoryArchived;
  final bool fromAccountArchived;
  final bool toAccountArchived;

  bool get isUsable {
    if (preset.type == 'transfer') {
      return preset.fromAccountId != null &&
          preset.toAccountId != null &&
          fromAccountName != null &&
          toAccountName != null &&
          !fromAccountArchived &&
          !toAccountArchived;
    }
    return preset.accountId != null &&
        preset.categoryId != null &&
        accountName != null &&
        categoryName != null &&
        !accountArchived &&
        !categoryArchived;
  }

  String get displayName {
    final explicit = preset.name?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final memo = preset.memo?.trim();
    if (memo != null && memo.isNotEmpty) return memo;
    if (preset.type == 'transfer') {
      if (fromAccountName != null && toAccountName != null) {
        return '$fromAccountName → $toAccountName';
      }
    } else if (categoryName != null) {
      return categoryName!;
    }
    return '이름 없는 프리셋';
  }

  TransactionPresetDraft toDraft() => TransactionPresetDraft(
    name: preset.name,
    type: preset.type,
    amount: preset.amount,
    memo: preset.memo,
    accountId: preset.accountId,
    categoryId: preset.categoryId,
    fromAccountId: preset.fromAccountId,
    toAccountId: preset.toAccountId,
    tagNames: tagNames,
  );
}

@DriftAccessor(tables: [TransactionPresets, Accounts, Categories])
class TransactionPresetsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionPresetsDaoMixin {
  TransactionPresetsDao(super.db);

  Future<List<TransactionPresetListItem>> listPresets() async {
    final presets =
        await (select(transactionPresets)..orderBy([
              (p) => OrderingTerm(expression: p.name),
              (p) => OrderingTerm(expression: p.id),
            ]))
            .get();
    final accountMap = {
      for (final account in await select(accounts).get()) account.id: account,
    };
    final categoryMap = {
      for (final category in await select(categories).get())
        category.id: category,
    };
    final result = [
      for (final preset in presets) _item(preset, accountMap, categoryMap),
    ];
    result.sort((a, b) {
      final name = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );
      return name != 0 ? name : a.preset.id.compareTo(b.preset.id);
    });
    return result;
  }

  Future<int> savePreset({
    int? id,
    required TransactionPresetDraft draft,
  }) async {
    final tags = draft.tagNames.isEmpty ? null : jsonEncode(draft.tagNames);
    if (id != null) {
      await (update(transactionPresets)..where((p) => p.id.equals(id))).write(
        TransactionPresetsCompanion(
          name: Value(draft.name),
          type: Value(draft.type),
          amount: Value(draft.amount),
          memo: Value(draft.memo),
          accountId: Value(draft.accountId),
          categoryId: Value(draft.categoryId),
          fromAccountId: Value(draft.fromAccountId),
          toAccountId: Value(draft.toAccountId),
          tagNames: Value(tags),
          updatedAt: Value(sqlNow()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
      return id;
    }
    return into(transactionPresets).insert(
      TransactionPresetsCompanion.insert(
        name: Value(draft.name),
        type: draft.type,
        amount: draft.amount,
        memo: Value(draft.memo),
        accountId: Value(draft.accountId),
        categoryId: Value(draft.categoryId),
        fromAccountId: Value(draft.fromAccountId),
        toAccountId: Value(draft.toAccountId),
        tagNames: Value(tags),
      ),
    );
  }

  Future<void> deletePreset(int id) =>
      (delete(transactionPresets)..where((p) => p.id.equals(id))).go();

  Future<void> removeTagName(String name) async {
    final rows = await select(transactionPresets).get();
    for (final preset in rows) {
      final names = _decodeTags(preset.tagNames);
      if (!names.remove(name)) continue;
      await (update(
        transactionPresets,
      )..where((p) => p.id.equals(preset.id))).write(
        TransactionPresetsCompanion(
          tagNames: Value(names.isEmpty ? null : jsonEncode(names)),
          updatedAt: Value(sqlNow()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
    }
  }

  TransactionPresetListItem _item(
    TransactionPreset preset,
    Map<int, Account> accountMap,
    Map<int, Category> categoryMap,
  ) {
    final account = accountMap[preset.accountId];
    final category = categoryMap[preset.categoryId];
    final from = accountMap[preset.fromAccountId];
    final to = accountMap[preset.toAccountId];
    return TransactionPresetListItem(
      preset: preset,
      tagNames: _decodeTags(preset.tagNames),
      accountName: account?.name,
      categoryName: category?.name,
      fromAccountName: from?.name,
      toAccountName: to?.name,
      accountArchived: account?.archivedAt != null,
      categoryArchived: category?.archivedAt != null,
      fromAccountArchived: from?.archivedAt != null,
      toAccountArchived: to?.archivedAt != null,
    );
  }
}

List<String> _decodeTags(String? value) {
  if (value == null || value.isEmpty) return <String>[];
  try {
    return (jsonDecode(value) as List).whereType<String>().toSet().toList(
      growable: true,
    );
  } catch (_) {
    return <String>[];
  }
}
