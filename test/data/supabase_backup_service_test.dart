import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/supabase_backup_service.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';

void main() {
  group('SupabaseBackupService contract', () {
    test('fake service uploads and downloads latest backup JSON', () async {
      final service = _FakeSupabaseBackupService();
      final settings = const SupabaseBackupSettings(
        url: 'https://example.supabase.co',
        anonKey: 'anon',
        bucket: 'backups',
      );
      final backup = Backup(
        exportedAt: '2026-06-17T00:00:00Z',
        accounts: const <Account>[],
        categories: const <Category>[],
        budgetGroups: const <BudgetGroup>[],
        budgetGroupCategories: const <BudgetGroupCategoryLink>[],
        transactions: const <Transaction>[],
        investments: const <Investment>[],
        tags: const <Tag>[],
        transactionTags: const <TransactionTagLink>[],
        monthlyIncome: const <MonthlyIncomeRow>[],
        recurringTransactions: const <RecurringTransaction>[],
      );

      final upload = await service.uploadBackup(
        settings: settings,
        backup: backup,
        now: DateTime(2026, 6, 17, 9, 8, 7),
      );

      expect(upload.isOk, true, reason: upload.error);
      expect(upload.value!.latestPath, 'my_little_budget/latest.json');
      expect(
        upload.value!.historyPath,
        'my_little_budget/backups/my_little_budget-backup-20260617-090807.json',
      );

      final downloaded = await service.downloadLatestBackup(settings);
      expect(downloaded.isOk, true, reason: downloaded.error);
      expect(downloaded.value, contains('"appName": "my_little_budget"'));
    });
  });
}

class _FakeSupabaseBackupService implements SupabaseBackupService {
  String? _latest;

  @override
  Future<SupabaseBackupResult<void>> testConnection(
    SupabaseBackupSettings settings,
  ) async {
    return const SupabaseBackupResult.ok(null);
  }

  @override
  Future<SupabaseBackupResult<SupabaseBackupUpload>> uploadBackup({
    required SupabaseBackupSettings settings,
    required Backup backup,
    DateTime? now,
  }) async {
    final normalized = settings.normalized();
    final date = now ?? DateTime.now();
    final latestPath = '${normalized.pathPrefix}/latest.json';
    final historyPath =
        '${normalized.pathPrefix}/backups/${buildBackupFilename(now: date)}';
    _latest = backup.toJsonString();
    return SupabaseBackupResult.ok(
      SupabaseBackupUpload(latestPath: latestPath, historyPath: historyPath),
    );
  }

  @override
  Future<SupabaseBackupResult<String>> downloadLatestBackup(
    SupabaseBackupSettings settings,
  ) async {
    final value = _latest;
    if (value == null) return const SupabaseBackupResult.fail('missing backup');
    return SupabaseBackupResult.ok(value);
  }

  @override
  Future<SupabaseBackupResult<SupabaseBackupRemoteStatus>> getRemoteStatus(
    SupabaseBackupSettings settings,
  ) async {
    final normalized = settings.normalized();
    return SupabaseBackupResult.ok(
      SupabaseBackupRemoteStatus(
        latestPath: '${normalized.pathPrefix}/latest.json',
        exists: _latest != null,
        updatedAt: DateTime(2026, 6, 17, 9, 8),
      ),
    );
  }
}
