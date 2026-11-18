import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/accounts/card_billing.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  test('principal sums exactly and remainder belongs to first round', () {
    final schedule = cardInstallmentSchedule(
      purchaseDate: '2026-10-31',
      amount: 100001,
      months: 3,
      paymentDay: 14,
      closingDay: 31,
    );
    expect(schedule.map((p) => p.amount), [33335, 33333, 33333]);
    expect(schedule.map((p) => p.paymentDate), [
      '2026-11-16',
      '2026-12-14',
      '2027-01-14',
    ]);
    expect(schedule.map((p) => p.round), [1, 2, 3]);
  });

  test('a purchase after the closing date starts next cycle', () {
    final schedule = cardInstallmentSchedule(
      purchaseDate: '2026-11-01',
      amount: 120000,
      months: 3,
      paymentDay: 14,
      closingDay: 31,
    );
    expect(schedule.first.paymentDate, '2026-12-14');
  });

  test(
    'month end is anchored independently and holiday shift does not skip a round',
    () {
      final schedule = cardInstallmentSchedule(
        purchaseDate: '2027-01-15',
        amount: 600,
        months: 3,
        paymentDay: 31,
        closingDay: 15,
      );
      expect(schedule.map((p) => p.nominalDate.day), [31, 28, 31]);
      expect(schedule.map((p) => p.paymentDate), [
        '2027-02-01',
        '2027-03-02',
        '2027-03-31',
      ]);
      final bill = calculateCardBilling(
        today: DateTime(2027, 3, 1),
        paymentDay: 31,
        closingDay: 15,
        initialBalance: 0,
        entries: const [
          CardBillingEntry('2027-01-15', -600, installmentMonths: 3),
          CardBillingEntry('2027-02-01', 200),
        ],
      );
      expect(bill.dueAmount, 200);
      expect(bill.laterAmount, 200);
      expect(bill.installments.single.current!.round, 2);
    },
  );

  test(
    'repeated closing dates in short months still have separate billing cycles',
    () {
      final bill = calculateCardBilling(
        today: DateTime(2027, 2, 2),
        paymentDay: 31,
        closingDay: 30,
        initialBalance: 0,
        entries: const [
          CardBillingEntry('2027-01-30', -900, installmentMonths: 3),
          CardBillingEntry('2027-02-01', 300),
        ],
      );
      expect(bill.closingDate, '2027-01-30');
      expect(bill.dueAmount, 300);
      expect(bill.laterAmount, 300);
      expect(bill.installments.single.current!.round, 2);
    },
  );

  test(
    'overdue principal stays due until repayment, future repayments do not count yet',
    () {
      CardBillingSummary bill(DateTime date) => calculateCardBilling(
        today: date,
        paymentDay: 14,
        closingDay: 31,
        initialBalance: -1000,
        entries: const [
          CardBillingEntry('2026-10-31', -9000, installmentMonths: 3),
          CardBillingEntry('2026-11-20', 4000),
        ],
      );
      expect(bill(DateTime(2026, 11, 10)).dueAmount, 4000);
      expect(bill(DateTime(2026, 11, 10)).laterAmount, 6000);
      expect(bill(DateTime(2026, 11, 17)).dueAmount, 7000);
      expect(bill(DateTime(2026, 11, 20)).dueAmount, 3000);
      expect(bill(DateTime(2027, 2, 1)).dueAmount, 6000);
      expect(bill(DateTime(2027, 2, 1)).laterAmount, 0);
    },
  );

  test(
    'refund offsets whole card debt while plan explicitly describes scheduled principal',
    () {
      final bill = calculateCardBilling(
        today: DateTime(2026, 11, 10),
        paymentDay: 14,
        closingDay: 31,
        initialBalance: 0,
        entries: const [
          CardBillingEntry(
            '2026-10-31',
            -9000,
            installmentMonths: 3,
            title: '노트북',
          ),
          CardBillingEntry('2026-11-01', 5000),
        ],
      );
      expect(bill.dueAmount, 0);
      expect(bill.laterAmount, 4000);
      expect(bill.installments.single.title, '노트북');
      expect(bill.installments.single.current!.amount, 3000);
      expect(bill.installments.single.laterPrincipal, 6000);
    },
  );

  test(
    'future purchase has no current round and all principal remains later',
    () {
      final bill = calculateCardBilling(
        today: DateTime(2026, 11, 10),
        paymentDay: 14,
        closingDay: 31,
        initialBalance: 0,
        entries: const [
          CardBillingEntry('2026-12-20', -9000, installmentMonths: 3),
        ],
      );
      expect(bill.dueAmount, 0);
      expect(bill.laterAmount, 9000);
      expect(bill.installments.single.current, isNull);
      expect(bill.installments.single.future.first.paymentDate, '2027-01-14');
    },
  );

  test(
    'every month length conserves principal and nominal rounds for 60 months',
    () {
      for (var month = 1; month <= 12; month++) {
        for (final days in [(31, 30), (14, 31), (1, 1), (25, 5)]) {
          final schedule = cardInstallmentSchedule(
            purchaseDate: '2026-${month.toString().padLeft(2, '0')}-28',
            amount: 1234567,
            months: 60,
            paymentDay: days.$1,
            closingDay: days.$2,
          );
          expect(schedule.fold<int>(0, (s, p) => s + p.amount), 1234567);
          for (var i = 1; i < 60; i++) {
            final before = schedule[i - 1].nominalDate;
            final after = schedule[i].nominalDate;
            expect(
              (after.year - before.year) * 12 + after.month - before.month,
              1,
            );
            expect(after.isAfter(before), isTrue);
          }
        }
      }
    },
  );

  test(
    'validation rejects non-expense, invalid months, and less than one won per round',
    () {
      for (final input in [
        ('income', 100, 3),
        ('transfer', 100, 3),
        ('expense', 100, 1),
        ('expense', 100, 61),
        ('expense', 2, 3),
      ]) {
        final result = validateTransaction(
          type: input.$1,
          amount: input.$2,
          installmentMonths: input.$3,
          occurredOn: '2026-11-01',
          occurredTime: '12:00',
          accountId: 1,
          categoryId: 1,
        );
        expect(result.errors, contains('installmentMonths'));
      }
    },
  );
}
