import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// '투자' 자산을 isInvestment=true 로 만든다.
  Future<int> makeInvestmentAccount() async {
    final accts = await db.accountsDao.getActiveAccounts();
    final inv = accts.firstWhere((a) => a.name == '투자');
    await db.accountsDao.saveAccount(
      id: inv.id,
      draft: AccountDraft(
        name: inv.name,
        kind: inv.kind,
        initialBalance: 0,
        color: inv.color,
        excludeFromTotal: false,
        isInvestment: true,
      ),
      currentBalance: 0,
    );
    return inv.id;
  }

  test('매수 시 accountId 자동 지정 + 잔액 영향 0', () async {
    final invId = await makeInvestmentAccount();
    final r = validateInvestment(
      side: 'buy',
      occurredOn: '2025-01-01',
      occurredTime: '00:00',
      ticker: 'AAPL',
      quantity: 10,
      totalAmount: 100000,
    );
    final id = await db.investmentsDao.saveInvestment(draft: r.value!);

    final stored = await db.investmentsDao.getInvestmentById(id);
    expect(stored!.accountId, invId);

    // 매수만 있으면 자산 잔액 영향 0
    final bal = await db.accountsDao.getAccountBalance(invId);
    expect(bal!.balance, 0);
  });

  test('매도 실현손익이 투자 자산 잔액에 반영', () async {
    final invId = await makeInvestmentAccount();
    // 매수 10주 100000 (평단 10000), 6주 매도 90000 → 원가 60000, 손익 +30000
    await db.investmentsDao.saveInvestment(
      draft: validateInvestment(
        side: 'buy', occurredOn: '2025-01-01', occurredTime: '00:00',
        ticker: 'AAPL', quantity: 10, totalAmount: 100000,
      ).value!,
    );
    await db.investmentsDao.saveInvestment(
      draft: validateInvestment(
        side: 'sell', occurredOn: '2025-02-01', occurredTime: '00:00',
        ticker: 'AAPL', quantity: 6, totalAmount: 90000,
      ).value!,
    );

    final bal = await db.accountsDao.getAccountBalance(invId);
    expect(bal!.balance, 30000); // 실현손익만 잔액에

    final summary = await db.investmentsDao.investmentMonthlySummary('2025-02');
    expect(summary.sell, 90000);
  });

  test('보유종목/실현손익 조회', () async {
    await makeInvestmentAccount();
    await db.investmentsDao.saveInvestment(
      draft: validateInvestment(
        side: 'buy', occurredOn: '2025-01-01', occurredTime: '00:00',
        ticker: 'TSLA', quantity: 10, totalAmount: 100000,
      ).value!,
    );
    await db.investmentsDao.saveInvestment(
      draft: validateInvestment(
        side: 'sell', occurredOn: '2025-01-10', occurredTime: '00:00',
        ticker: 'TSLA', quantity: 4, totalAmount: 60000,
      ).value!,
    );

    expect(await db.investmentsDao.listHeldTickers(), ['TSLA']); // 6주 남음

    final pnl = await db.investmentsDao.getRealizedPnL('2025-01-01', '2025-01-31');
    expect(pnl.length, 1);
    expect(pnl.first.pnl, 20000); // 매도 60000 - 원가 40000
  });
}
