import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> setInvestmentAccount() async {
    final inv = (await db.accountsDao.getActiveAccounts())
        .firstWhere((a) => a.name == '투자');
    await db.accountsDao.saveAccount(
      id: inv.id,
      draft: AccountDraft(
        name: inv.name, kind: inv.kind, initialBalance: 0, color: inv.color,
        excludeFromTotal: false, isInvestment: true,
      ),
      currentBalance: 0,
    );
  }

  Future<void> save(String side, String on, double qty, int total, {String ticker = 'AAPL'}) {
    return db.investmentsDao.saveInvestment(
      draft: validateInvestment(
        side: side, occurredOn: on, occurredTime: '00:00',
        ticker: ticker, quantity: qty, totalAmount: total,
      ).value!,
    );
  }

  test('listInvestmentsByYear — 연 범위만', () async {
    await setInvestmentAccount();
    await save('buy', '2025-12-31', 1, 1000);
    await save('buy', '2026-01-01', 1, 1000);
    await save('buy', '2026-12-31', 1, 1000);
    await save('buy', '2027-01-01', 1, 1000);

    final y2026 = await db.investmentsDao.listInvestmentsByYear(2026);
    expect(y2026.length, 2);
    expect(y2026.every((i) => i.occurredOn.startsWith('2026')), true);
  });

  test('investmentYearlySummary — buy/sell/dividend 합산', () async {
    await setInvestmentAccount();
    await save('buy', '2026-03-01', 1, 50000);
    await save('buy', '2026-06-01', 1, 30000);
    await save('sell', '2026-07-01', 1, 90000);
    await save('dividend', '2026-08-01', 0, 5000);
    await save('buy', '2025-12-31', 1, 99999); // 다른 연도

    final s = await db.investmentsDao.investmentYearlySummary(2026);
    expect(s.buy, 80000);
    expect(s.sell, 90000);
    expect(s.dividend, 5000);
    expect(s.net, 15000); // 90000+5000-80000
  });

  test('availableInvestmentYears — 거래 있는 연도만 정렬', () async {
    await setInvestmentAccount();
    await save('buy', '2024-06-15', 1, 1000);
    await save('buy', '2026-01-10', 1, 1000);
    expect(await db.investmentsDao.availableInvestmentYears(), [2024, 2026]);
  });

  test('listCurrentHoldings — DAO 래퍼', () async {
    await setInvestmentAccount();
    await save('buy', '2026-01-01', 10, 1000, ticker: 'AAPL');
    await save('sell', '2026-02-01', 4, 500, ticker: 'AAPL');
    final h = await db.investmentsDao.listCurrentHoldings();
    expect(h.length, 1);
    expect(h.first.ticker, 'AAPL');
    expect(h.first.quantity, 6);
    expect(h.first.totalCost, 600); // basis = 1000 - (100 * 4) = 600
  });
}
