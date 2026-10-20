import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../data/daos/transactions_dao.dart';
import '../../features/home/providers.dart';
import 'category_icon.dart';

class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key, required this.child, this.padding = 24});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class BudgetOverviewCard extends StatelessWidget {
  const BudgetOverviewCard({
    super.key,
    required this.overview,
    required this.onBudget,
  });
  final HomeOverview overview;
  final VoidCallback onBudget;

  @override
  Widget build(BuildContext context) {
    final hasBudget = overview.budgets.isNotEmpty;
    final ratio = overview.budget > 0 ? overview.spent / overview.budget : 0.0;
    final color = overview.remaining < 0
        ? context.appExpense
        : context.appIncome;
    return OverviewCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '남은 예산',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        hasBudget
                            ? formatKRW(overview.remaining)
                            : '예산을 설정해 보세요',
                        style: TextStyle(
                          fontSize: hasBudget ? 36 : 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: overview.remaining < 0 ? color : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '차근차근 모으는 나의 일상',
                      style: TextStyle(color: context.desktopMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 86,
                height: 100,
                child: CustomPaint(painter: _PiggyPainter()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: color.withValues(alpha: .12),
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '사용 ${formatKRW(overview.spent)}',
                  style: TextStyle(color: context.desktopMuted),
                ),
              ),
              Flexible(
                child: Text(
                  '예산 ${formatKRW(overview.budget)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: context.desktopMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onBudget,
            icon: const Icon(Icons.tune, size: 16),
            label: Text(hasBudget ? '예산 보기 · 조정' : '예산 설정'),
          ),
        ],
      ),
    );
  }
}

class OverviewAmountCard extends StatelessWidget {
  const OverviewAmountCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });
  final String label;
  final int amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => OverviewCard(
    padding: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: color, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatKRW(amount),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class RecentOverviewCard extends StatelessWidget {
  const RecentOverviewCard({
    super.key,
    required this.rows,
    required this.onAll,
    required this.onEdit,
  });
  final List<TransactionRow> rows;
  final VoidCallback onAll;
  final ValueChanged<TransactionRow> onEdit;

  @override
  Widget build(BuildContext context) => OverviewCard(
    padding: 20,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '최근 내역',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onAll, child: const Text('전체보기 ›')),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              '아직 기록이 없어요. 첫 내역을 남겨 보세요.',
              style: TextStyle(color: context.desktopMuted),
            ),
          ),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _RecentRow(row: rows[i], onTap: () => onEdit(rows[i])),
        ],
      ],
    ),
  );
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.row, required this.onTap});
  final TransactionRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final income = row.type == 'income';
    final transfer = row.type == 'transfer';
    final color = income
        ? context.appIncome
        : transfer
        ? context.appTransfer
        : context.appExpense;
    final prefix = income
        ? '+'
        : transfer
        ? ''
        : '-';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      leading: CategoryIconBadge(
        name: row.categoryName,
        iconId: row.categoryIcon,
        colorHex: row.categoryColor,
        type: row.type,
        size: 42,
      ),
      title: Text(
        row.memo?.trim().isNotEmpty == true
            ? row.memo!
            : row.categoryName ?? (transfer ? '이체' : '거래'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${row.occurredOn.substring(5).replaceAll('-', '.')} · ${row.accountName ?? row.fromAccountName ?? '계좌 없음'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.desktopMuted),
      ),
      trailing: Text(
        '$prefix${formatKRW(row.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: income ? color : null,
        ),
      ),
    );
  }
}

class _PiggyPainter extends CustomPainter {
  const _PiggyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 110);
    final paint = Paint()..color = const Color(0xFFE8F6E9);
    canvas.drawOval(const Rect.fromLTWH(0, 35, 100, 65), paint);
    paint.color = const Color(0xFFFFBDB6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 49, 66, 47),
        const Radius.circular(23),
      ),
      paint,
    );
    canvas.drawOval(const Rect.fromLTWH(22, 42, 14, 22), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, 83, 12, 18),
        const Radius.circular(5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(68, 83, 12, 18),
        const Radius.circular(5),
      ),
      paint,
    );
    paint.color = const Color(0xFFFF9E9C);
    canvas.drawOval(const Rect.fromLTWH(13, 67, 26, 19), paint);
    paint.color = const Color(0xFFD8797D);
    canvas.drawOval(const Rect.fromLTWH(20, 73, 3, 7), paint);
    canvas.drawOval(const Rect.fromLTWH(28, 73, 3, 7), paint);
    paint.color = const Color(0xFF4D4148);
    canvas.drawCircle(const Offset(37, 65), 2.5, paint);
    paint
      ..color = const Color(0xFF65B88C)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(57, 51), const Offset(57, 26), paint);
    canvas.drawOval(const Rect.fromLTWH(36, 20, 22, 12), paint);
    canvas.drawOval(const Rect.fromLTWH(58, 14, 22, 12), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PiggyPainter oldDelegate) => false;
}
