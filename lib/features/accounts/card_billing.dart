import '../../core/date.dart';
import '../calendar/korean_holidays.dart';

/// A signed account movement. Payments/refunds are positive, spending negative.
class CardBillingEntry {
  const CardBillingEntry(
    this.date,
    this.amount, {
    this.isAdjustment = false,
    this.installmentMonths,
    this.title,
  });
  final String date;
  final int amount;
  final bool isAdjustment;
  final int? installmentMonths;
  final String? title;
}

class CardInstallment {
  const CardInstallment({
    required this.round,
    required this.amount,
    required this.nominalDate,
    required this.paymentDate,
  });
  final int round;
  final int amount;
  final DateTime nominalDate;
  final String paymentDate;
}

class CardInstallmentPlan {
  const CardInstallmentPlan({
    required this.title,
    required this.purchaseDate,
    required this.totalAmount,
    required this.months,
    required this.current,
    required this.future,
  });
  final String title;
  final String purchaseDate;
  final int totalAmount;
  final int months;
  final CardInstallment? current;
  final List<CardInstallment> future;
  int get laterPrincipal =>
      future.fold(0, (total, item) => total + item.amount);
}

class CardBillingSummary {
  const CardBillingSummary({
    required this.paymentDate,
    required this.closingDate,
    required this.dueAmount,
    required this.laterAmount,
    this.installments = const [],
  });

  final String paymentDate;
  final String closingDate;
  final int dueAmount;
  final int laterAmount;
  final List<CardInstallmentPlan> installments;
}

DateTime _dayInMonth(int year, int month, int day) {
  final first = DateTime(year, month);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, day.clamp(1, last));
}

DateTime _paymentDate(DateTime nominal) {
  var date = nominal;
  while (date.weekday >= 6 || isKoreanHoliday(date)) {
    date = DateTime(date.year, date.month, date.day + 1);
  }
  return date;
}

DateTime _closingDate(DateTime nominal, int closingDay) {
  final closing = _dayInMonth(nominal.year, nominal.month, closingDay);
  return closing.isBefore(nominal)
      ? closing
      : _dayInMonth(nominal.year, nominal.month - 1, closingDay);
}

/// Principal only. Keep each original payment day when crossing short months.
/// A payment cycle's identity is its nominal month, not its shifted holiday date.
List<CardInstallment> cardInstallmentSchedule({
  required String purchaseDate,
  required int amount,
  required int months,
  required int paymentDay,
  required int closingDay,
}) {
  if (months < 2 ||
      months > 60 ||
      amount < months ||
      paymentDay < 1 ||
      paymentDay > 31 ||
      closingDay < 1 ||
      closingDay > 31) {
    throw ArgumentError('할부 금액·개월 수·결제 설정을 확인해주세요.');
  }
  final purchase = DateTime.parse(purchaseDate);
  var first = _dayInMonth(purchase.year, purchase.month, paymentDay);
  while (_closingDate(first, closingDay).isBefore(purchase)) {
    first = _dayInMonth(first.year, first.month + 1, paymentDay);
  }
  return [
    for (var i = 0; i < months; i++)
      CardInstallment(
        round: i + 1,
        amount: amount ~/ months + (i == 0 ? amount % months : 0),
        nominalDate: _dayInMonth(first.year, first.month + i, paymentDay),
        paymentDate: toDateKey(
          _paymentDate(_dayInMonth(first.year, first.month + i, paymentDay)),
        ),
      ),
  ];
}

/// Estimates the next bill from recorded movements, without creating payments.
/// Credits already received pay the oldest debt first. Future repayments must
/// not make an unpaid bill disappear before money actually leaves the bank.
CardBillingSummary calculateCardBilling({
  required DateTime today,
  required int paymentDay,
  required int closingDay,
  required int initialBalance,
  required Iterable<CardBillingEntry> entries,
}) {
  final day = DateTime(today.year, today.month, today.day);
  var nominal = _dayInMonth(day.year, day.month - 1, paymentDay);
  while (_paymentDate(nominal).isBefore(day)) {
    nominal = _dayInMonth(nominal.year, nominal.month + 1, paymentDay);
  }
  final closing = _closingDate(nominal, closingDay);
  final cutoff = toDateKey(closing);
  final todayKey = toDateKey(day);
  var due = initialBalance < 0 ? -initialBalance : 0;
  var later = 0;
  var credits = initialBalance > 0 ? initialBalance : 0;
  final plans = <CardInstallmentPlan>[];
  for (final entry in entries) {
    final months = entry.installmentMonths ?? 1;
    if (!entry.isAdjustment &&
        entry.amount < 0 &&
        months >= 2 &&
        months <= 60 &&
        -entry.amount >= months) {
      final schedule = cardInstallmentSchedule(
        purchaseDate: entry.date,
        amount: -entry.amount,
        months: months,
        paymentDay: paymentDay,
        closingDay: closingDay,
      );
      for (final part in schedule) {
        if (part.nominalDate.isAfter(nominal)) {
          later += part.amount;
        } else {
          due += part.amount;
        }
      }
      final current = schedule
          .where((p) => p.nominalDate == nominal)
          .firstOrNull;
      final future = schedule
          .where((p) => p.nominalDate.isAfter(nominal))
          .toList();
      if (current != null || future.isNotEmpty) {
        plans.add(
          CardInstallmentPlan(
            title: entry.title ?? '카드 할부',
            purchaseDate: entry.date,
            totalAmount: -entry.amount,
            months: months,
            current: current,
            future: future,
          ),
        );
      }
      continue;
    }
    if (entry.isAdjustment) {
      if (entry.date.compareTo(cutoff) <= 0) {
        due -= entry.amount;
      } else {
        later -= entry.amount;
      }
      continue;
    }
    if (entry.amount < 0) {
      if (entry.date.compareTo(cutoff) <= 0) {
        due -= entry.amount;
      } else {
        later -= entry.amount;
      }
    } else if (entry.date.compareTo(todayKey) <= 0) {
      credits += entry.amount;
    }
  }
  // A usage correction belongs to its own statement, unlike a repayment.
  // Any excess credit can still offset the remaining debt.
  if (due < 0) {
    credits -= due;
    due = 0;
  }
  if (later < 0) {
    credits -= later;
    later = 0;
  }
  final remainingCredits = credits > due ? credits - due : 0;
  due = due > credits ? due - credits : 0;
  later = later > remainingCredits ? later - remainingCredits : 0;
  return CardBillingSummary(
    paymentDate: toDateKey(_paymentDate(nominal)),
    closingDate: cutoff,
    dueAmount: due,
    laterAmount: later,
    installments: plans,
  );
}
