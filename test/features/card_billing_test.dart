import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/accounts/card_billing.dart';
import 'package:my_little_budget/features/accounts/validation.dart';

void main() {
  test('usage period changes only on the day after closing', () {
    expect(cardSpendingPeriod(DateTime(2026, 11, 10, 23, 59), 10), (
      start: '2026-10-11',
      end: '2026-11-10',
    ));
    expect(cardSpendingPeriod(DateTime(2026, 11, 11), 10), (
      start: '2026-11-11',
      end: '2026-12-10',
    ));
    for (final date in [
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 30),
      DateTime(2027, 2, 28),
      DateTime(2028, 2, 29),
      DateTime(2026, 12, 31),
    ]) {
      final period = cardSpendingPeriod(date, 31);
      expect(period.start, '${period.end.substring(0, 7)}-01');
      expect(DateTime.parse(period.end), date);
      final tomorrow = DateTime(date.year, date.month, date.day + 1);
      expect(DateTime.parse(cardSpendingPeriod(tomorrow, 31).start), tomorrow);
    }
  });

  test('all closing days partition dates with no gaps or overlap', () {
    for (var closingDay = 1; closingDay <= 31; closingDay++) {
      for (var month = 1; month <= 36; month++) {
        final last = DateTime(2026, month + 1, 0);
        final closing = DateTime(
          last.year,
          last.month,
          closingDay.clamp(1, last.day),
        );
        final current = cardSpendingPeriod(closing, closingDay);
        final tomorrow = DateTime(closing.year, closing.month, closing.day + 1);
        final next = cardSpendingPeriod(tomorrow, closingDay);
        expect(DateTime.parse(current.end), closing);
        expect(DateTime.parse(next.start), tomorrow);
        expect(current.start.compareTo(current.end), lessThanOrEqualTo(0));
      }
    }
  });

  test('closing day is inclusive and the following day is billed next', () {
    final bill = calculateCardBilling(
      today: DateTime(2026, 11, 19),
      paymentDay: 25,
      closingDay: 10,
      initialBalance: 0,
      entries: const [
        CardBillingEntry('2026-11-10', -10000),
        CardBillingEntry('2026-11-11', -20000),
        CardBillingEntry('2026-12-10', -30000),
      ],
    );
    expect(bill.closingDate, '2026-11-10');
    expect(bill.dueAmount, 10000);
    expect(bill.laterAmount, 50000);
    final plan = cardInstallmentSchedule(
      purchaseDate: '2026-11-11',
      amount: 90000,
      months: 3,
      paymentDay: 25,
      closingDay: 10,
    );
    expect(plan.first.nominalDate, DateTime(2026, 12, 25));
  });

  test(
    'month-end cutoff includes previous month last day and excludes this month first day',
    () {
      for (final entry in [
        (DateTime(2026, 11, 10), '2026-10-31', '2026-11-01'),
        (DateTime(2027, 3, 10), '2027-02-28', '2027-03-01'),
        (DateTime(2028, 3, 10), '2028-02-29', '2028-03-01'),
      ]) {
        final bill = calculateCardBilling(
          today: entry.$1,
          paymentDay: 14,
          closingDay: 31,
          initialBalance: 0,
          entries: [
            CardBillingEntry(entry.$2, -10000),
            CardBillingEntry(entry.$3, -20000),
          ],
        );
        expect(bill.closingDate, entry.$2);
        expect(bill.dueAmount, 10000);
        expect(bill.laterAmount, 20000);
      }
    },
  );

  test(
    'closing boundary and repayments split the next bill from later bills',
    () {
      final bill = calculateCardBilling(
        today: DateTime(2026, 11, 10),
        paymentDay: 14,
        closingDay: 31,
        initialBalance: -10000,
        entries: const [
          CardBillingEntry('2026-10-31', -100000),
          CardBillingEntry('2026-11-01', -30000),
          CardBillingEntry('2026-11-02', 20000),
          CardBillingEntry('2026-11-16', 90000),
          CardBillingEntry('2026-12-05', -50000),
        ],
      );
      expect(bill.paymentDate, '2026-11-16');
      expect(bill.closingDate, '2026-10-31');
      expect(bill.dueAmount, 90000);
      expect(bill.laterAmount, 80000);
    },
  );

  test('refund in excess of the closed bill pays later charges', () {
    final bill = calculateCardBilling(
      today: DateTime(2026, 11, 10),
      paymentDay: 14,
      closingDay: 31,
      initialBalance: 0,
      entries: const [
        CardBillingEntry('2026-10-20', -100000),
        CardBillingEntry('2026-11-01', -50000),
        CardBillingEntry('2026-11-02', 120000),
      ],
    );
    expect(bill.dueAmount, 0);
    expect(bill.laterAmount, 30000);
  });

  test('payment day itself remains current then advances after that day', () {
    CardBillingSummary bill(DateTime today) => calculateCardBilling(
      today: today,
      paymentDay: 14,
      closingDay: 31,
      initialBalance: 0,
      entries: const [CardBillingEntry('2026-11-01', -50000)],
    );
    expect(bill(DateTime(2026, 11, 16)).paymentDate, '2026-11-16');
    final next = bill(DateTime(2026, 11, 17));
    expect(next.paymentDate, '2026-12-14');
    expect(next.closingDate, '2026-11-30');
    expect(next.dueAmount, 50000);
    expect(next.laterAmount, 0);
  });

  test('short month and holiday delay can cross into the following month', () {
    final bill = calculateCardBilling(
      today: DateTime(2027, 3, 1),
      paymentDay: 31,
      closingDay: 15,
      initialBalance: -50000,
      entries: const [],
    );
    expect(bill.paymentDate, '2027-03-02');
    expect(bill.closingDate, '2027-02-15');
    expect(bill.dueAmount, 50000);
  });

  test('same closing and payment day refers to the previous month closing', () {
    final bill = calculateCardBilling(
      today: DateTime(2026, 12, 1),
      paymentDay: 15,
      closingDay: 15,
      initialBalance: 0,
      entries: const [
        CardBillingEntry('2026-11-15', -10000),
        CardBillingEntry('2026-11-16', -20000),
      ],
    );
    expect(bill.closingDate, '2026-11-15');
    expect(bill.dueAmount, 10000);
    expect(bill.laterAmount, 20000);
  });

  test('credit balance never produces a negative bill', () {
    final bill = calculateCardBilling(
      today: DateTime(2026, 11, 10),
      paymentDay: 14,
      closingDay: 31,
      initialBalance: 100000,
      entries: const [CardBillingEntry('2026-11-01', -50000)],
    );
    expect(bill.dueAmount, 0);
    expect(bill.laterAmount, 0);
  });

  test(
    'card settings require a valid pair and are unavailable on bank accounts',
    () {
      expect(
        validateAccount(name: 'card', kind: 'card', cardPaymentDay: 14).isFail,
        isTrue,
      );
      expect(
        validateAccount(
          name: 'card',
          kind: 'card',
          cardPaymentDay: 0,
          cardClosingDay: 31,
        ).isFail,
        isTrue,
      );
      expect(
        validateAccount(
          name: 'bank',
          kind: 'bank',
          cardPaymentDay: 14,
          cardClosingDay: 31,
        ).isFail,
        isTrue,
      );
      expect(
        validateAccount(
          name: 'card',
          kind: 'card',
          cardPaymentDay: 14,
          cardClosingDay: 31,
        ).isOk,
        isTrue,
      );
    },
  );
}
