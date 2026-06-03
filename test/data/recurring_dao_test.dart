import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/recurring/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> account() async =>
      (await db.accountsDao.getActiveAccounts()).first.id;
  Future<int> category() async =>
      (await db.categoriesDao.getActiveCategories('expense')).first.id;

  group('generateDueRecurringTransactions (SPEC §5.1)', () {
    test('매월 반복 → horizon 까지 backfill, 멱등', () async {
      final r = validateRecurring(
        type: 'expense',
        name: '월세',
        amount: 500000,
        frequency: 'monthly',
        dayOfMonth: 1,
        occurredTime: '00:00',
        startDate: '2025-01-01',
        accountId: await account(),
        categoryId: await category(),
      );
      expect(r.isOk, true);
      await db.recurringDao.saveRecurring(draft: r.value!);

      final n1 = await db.recurringDao.generateDueRecurringTransactions('2025-03-31');
      expect(n1, 3); // 1/1, 2/1, 3/1

      // 두 번째 호출은 같은 horizon → 추가 생성 0 (멱등)
      final n2 = await db.recurringDao.generateDueRecurringTransactions('2025-03-31');
      expect(n2, 0);

      // horizon 확장하면 추가분만
      final n3 = await db.recurringDao.generateDueRecurringTransactions('2025-05-31');
      expect(n3, 2); // 4/1, 5/1

      final jan = await db.transactionsDao.listTransactionsByMonth('2025-01');
      expect(jan.length, 1);
      expect(jan.first.amount, 500000);
    });

    test('태그가 지정된 반복거래는 생성 거래에 태그 부착', () async {
      final r = validateRecurring(
        type: 'expense',
        name: '구독',
        amount: 10000,
        frequency: 'monthly',
        dayOfMonth: 15,
        occurredTime: '00:00',
        startDate: '2025-01-01',
        accountId: await account(),
        categoryId: await category(),
        tagNames: ['고정지출'],
      );
      await db.recurringDao.saveRecurring(draft: r.value!);
      await db.recurringDao.generateDueRecurringTransactions('2025-01-31');

      final rows = await db.transactionsDao.listTransactionsByMonth('2025-01');
      expect(rows.length, 1);
      expect(rows.first.tags.map((t) => t.name), contains('고정지출'));
    });

    test('비활성 반복거래는 생성 안 함', () async {
      final r = validateRecurring(
        type: 'expense',
        name: '비활성',
        amount: 1000,
        frequency: 'monthly',
        dayOfMonth: 1,
        occurredTime: '00:00',
        startDate: '2025-01-01',
        accountId: await account(),
        categoryId: await category(),
      );
      final id = await db.recurringDao.saveRecurring(draft: r.value!);
      await db.recurringDao.toggleRecurringActive(id, false);

      final n = await db.recurringDao.generateDueRecurringTransactions('2025-03-31');
      expect(n, 0);
    });
  });
}
