import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../features/home/providers.dart';
import '../../../features/budget/providers.dart';
import '../../../features/transactions/providers.dart';
import '../../shared/overview_widgets.dart';
import '../transactions/widgets/transaction_edit_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(homeMonthProvider);
    final date = parseMonthKey(month);
    void openTransactions() {
      ref.read(selectedMonthProvider.notifier).state = month;
      ref.read(typeFilterProvider.notifier).state = null;
      ref.read(searchFilterProvider.notifier).state = const TransactionFilter();
      context.go('/transactions');
    }

    void openBudget() {
      ref.read(budgetMonthProvider.notifier).state = month;
      context.push('/budget');
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          children: [
            const Text(
              '이번 달 가계부',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '차근차근 모으는 나의 일상',
              style: TextStyle(color: context.desktopMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 달',
                  onPressed: () => ref.read(homeMonthProvider.notifier).state =
                      shiftMonth(month, -1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () => ref.read(homeMonthProvider.notifier).state =
                      currentMonthKey(),
                  child: Text('${date.year}년 ${date.month}월'),
                ),
                IconButton(
                  tooltip: '다음 달',
                  onPressed: () => ref.read(homeMonthProvider.notifier).state =
                      shiftMonth(month, 1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: openTransactions,
                  icon: const Icon(Icons.add),
                  label: const Text('내역 추가'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ref
                .watch(homeOverviewProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => OverviewCard(
                    child: Column(
                      children: [
                        const Text('가계부를 불러오지 못했습니다.'),
                        TextButton(
                          onPressed: () => ref.invalidate(homeOverviewProvider),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                  data: (overview) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BudgetOverviewCard(
                        overview: overview,
                        onBudget: openBudget,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OverviewAmountCard(
                              label: '수입',
                              amount: overview.summary.income,
                              color: context.appIncome,
                              icon: Icons.south,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OverviewAmountCard(
                              label: '지출',
                              amount: overview.summary.expense,
                              color: context.appExpense,
                              icon: Icons.north,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      RecentOverviewCard(
                        rows: overview.recent,
                        onAll: openTransactions,
                        onEdit: (row) =>
                            TransactionEditDialog.show(context, row),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
