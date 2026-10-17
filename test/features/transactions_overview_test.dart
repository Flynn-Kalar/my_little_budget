import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/features/transactions/overview.dart';

TransactionRow row(
  int id,
  String type,
  String date,
  int amount, {
  String time = '12:00',
}) => TransactionRow(
  id: id,
  type: type,
  occurredOn: date,
  occurredTime: time,
  amount: amount,
);

void main() {
  test(
    'overview includes future income and expenses once and ignores transfers in net',
    () {
      final overview = TransactionOverview([
        row(1, 'income', '2026-10-01', 1000000),
        row(2, 'expense', '2026-10-17', 100000),
        row(3, 'expense', '2026-10-18', 200000),
        row(4, 'income', '2026-10-19', 50000),
        row(5, 'transfer', '2026-10-18', 999999),
      ], today: '2026-10-17');
      expect(overview.projectedNet, 750000);
      expect(overview.todayExpense, 100000);
      expect(overview.plannedExpense, 200000);
      expect(overview.plannedRows.map((r) => r.id), [3, 5, 4]);
    },
  );

  test(
    'empty and past months have no upcoming expenses; ordering is stable',
    () {
      final empty = TransactionOverview([], today: '2026-10-17');
      expect(empty.projectedNet, 0);
      expect(empty.plannedRows, isEmpty);
      final past = TransactionOverview([
        row(1, 'expense', '2026-09-30', 3000),
      ], today: '2026-10-17');
      expect(past.projectedNet, -3000);
      expect(past.plannedExpense, 0);
      final ordered = TransactionOverview([
        row(9, 'expense', '2026-10-20', 1),
        row(2, 'expense', '2026-10-20', 1),
        row(7, 'expense', '2026-10-20', 1, time: '09:00'),
      ], today: '2026-10-17');
      expect(ordered.plannedRows.map((r) => r.id), [7, 2, 9]);
    },
  );
}
