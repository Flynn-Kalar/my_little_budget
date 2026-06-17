import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/cloud_backup.dart';

void main() {
  group('CloudBackupService', () {
    test('fake service uploads, lists, and downloads backup content', () async {
      final service = _FakeCloudBackupService();

      final uploaded = await service.uploadBackup(
        filename: 'my_little_budget-backup-20260617-090000.json',
        json: _validBackupJson,
      );

      expect(uploaded.isOk, true, reason: uploaded.error);
      expect(uploaded.value!.name, contains('20260617'));

      final list = await service.listBackups();
      expect(list.isOk, true, reason: list.error);
      expect(list.value, hasLength(1));

      final downloaded = await service.downloadBackup(list.value!.single);
      expect(downloaded.isOk, true, reason: downloaded.error);
      expect(parseBackup(downloaded.value!).isOk, true);
    });

    test('fake service reports no remote backups', () async {
      final service = _FakeCloudBackupService();

      final list = await service.listBackups();

      expect(list.isOk, true, reason: list.error);
      expect(list.value, isEmpty);
    });

    test('fake service can surface sign-in and download failures', () async {
      final service = _FakeCloudBackupService(signInFails: true);

      expect(await service.signIn(), isNull);

      final missing = await service.downloadBackup(
        const CloudBackupFile(id: 'missing', name: 'missing.json'),
      );
      expect(missing.isOk, false);
    });
  });
}

const _validBackupJson = '''
{
  "version": 1,
  "appName": "my_little_budget",
  "exportedAt": "2026-06-17T00:00:00Z",
  "data": {
    "accounts": [],
    "categories": [],
    "budgetGroups": [],
    "budgetGroupCategories": [],
    "transactions": [],
    "investments": [],
    "tags": [],
    "transactionTags": [],
    "monthlyIncome": [],
    "recurringTransactions": []
  }
}
''';

class _FakeCloudBackupService implements CloudBackupService {
  _FakeCloudBackupService({this.signInFails = false});

  final bool signInFails;
  final Map<String, String> _files = {};
  CloudBackupAccount? _account;

  @override
  bool get isSupported => true;

  @override
  Future<CloudBackupAccount?> currentAccount() async => _account;

  @override
  Future<CloudBackupAccount?> signIn() async {
    if (signInFails) return null;
    return _account = const CloudBackupAccount(email: 'user@example.com');
  }

  @override
  Future<void> signOut() async {
    _account = null;
  }

  @override
  Future<CloudBackupResult<CloudBackupFile>> uploadBackup({
    required String filename,
    required String json,
  }) async {
    final id = (_files.length + 1).toString();
    _files[id] = json;
    return CloudBackupResult.ok(
      CloudBackupFile(
        id: id,
        name: filename,
        modifiedAt: DateTime(2026, 6, 17),
      ),
    );
  }

  @override
  Future<CloudBackupResult<List<CloudBackupFile>>> listBackups() async {
    return CloudBackupResult.ok([
      for (final entry in _files.entries)
        CloudBackupFile(
          id: entry.key,
          name: 'backup-${entry.key}.json',
          modifiedAt: DateTime(2026, 6, 17),
        ),
    ]);
  }

  @override
  Future<CloudBackupResult<String>> downloadBackup(CloudBackupFile file) async {
    final content = _files[file.id];
    if (content == null) {
      return const CloudBackupResult.fail('missing backup');
    }
    return CloudBackupResult.ok(content);
  }
}
