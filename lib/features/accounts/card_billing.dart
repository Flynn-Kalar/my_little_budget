import '../../core/date.dart';
import '../calendar/korean_holidays.dart';

/// A signed account movement. Payments/refunds are positive, spending negative.
class CardBillingEntry {
  const CardBillingEntry(this.date, this.amount, {this.isAdjustment = false});
  final String date;
  final int amount;
  final bool isAdjustment;
}

class CardBillingSummary {
  const CardBillingSummary({
    required this.paymentDate,
    required this.closingDate,
    required this.dueAmount,
    required this.laterAmount,
  });

  final String paymentDate;
  final String closingDate;
  final int dueAmount;
  final int laterAmount;
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
  var closing = _dayInMonth(nominal.year, nominal.month, closingDay);
  if (!closing.isBefore(nominal)) {
    closing = _dayInMonth(nominal.year, nominal.month - 1, closingDay);
  }
  final cutoff = toDateKey(closing);
  final todayKey = toDateKey(day);
  var due = initialBalance < 0 ? -initialBalance : 0;
  var later = 0;
  var credits = initialBalance > 0 ? initialBalance : 0;
  for (final entry in entries) {
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
  );
}
