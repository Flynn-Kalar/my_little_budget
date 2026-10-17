import '../../data/daos/transactions_dao.dart';

/// The month query already includes future-dated transactions. Each income or
/// expense contributes once; transfers only move money between accounts.
class TransactionOverview {
  TransactionOverview(List<TransactionRow> rows, {required String today}) {
    for (final row in rows) {
      if (row.type == 'income') projectedNet += row.amount;
      if (row.type == 'expense') {
        projectedNet -= row.amount;
        if (row.occurredOn == today) todayExpense += row.amount;
        if (row.occurredOn.compareTo(today) > 0) plannedExpense += row.amount;
      }
      if (row.occurredOn.compareTo(today) > 0) plannedRows.add(row);
    }
    plannedRows.sort((a, b) {
      final date = a.occurredOn.compareTo(b.occurredOn);
      if (date != 0) return date;
      final time = a.occurredTime.compareTo(b.occurredTime);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
  }

  int projectedNet = 0;
  int todayExpense = 0;
  int plannedExpense = 0;
  final List<TransactionRow> plannedRows = [];
}
