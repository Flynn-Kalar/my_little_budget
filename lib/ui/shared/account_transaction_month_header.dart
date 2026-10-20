import 'package:flutter/material.dart';
import '../../core/date.dart';
import '../../core/theme/app_theme.dart';

class AccountTransactionMonthHeader extends StatelessWidget {
  const AccountTransactionMonthHeader({super.key, required this.monthKey});
  final String monthKey;

  @override
  Widget build(BuildContext context) {
    final month = parseMonthKey(monthKey);
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appAccent.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${month.year}년 ${month.month}월',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
