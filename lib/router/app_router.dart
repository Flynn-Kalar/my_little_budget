import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/budget/budget_page.dart';
import '../features/investments/investments_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stats/stats_page.dart';
import '../shell/sidebar_shell.dart';
import '../ui/desktop/accounts/account_detail_screen.dart';
import '../ui/desktop/accounts/accounts_screen.dart';
import '../ui/desktop/settings/categories_screen.dart';
import '../ui/desktop/settings/data_management_screen.dart';
import '../ui/desktop/settings/recurring_screen.dart';
import '../ui/desktop/settings/tags_screen.dart';
import '../ui/desktop/settings/theme_screen.dart';
import '../ui/desktop/stats/yearly_stats_screen.dart';
import '../ui/desktop/transactions/transactions_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/transactions',
    routes: [
      ShellRoute(
        builder: (context, state, child) => SidebarShell(child: child),
        routes: [
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/budget',
            builder: (context, state) => const BudgetPage(),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const StatsPage(),
            routes: [
              GoRoute(
                path: 'yearly',
                builder: (context, state) => const YearlyStatsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountsScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return AccountDetailScreen(accountId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/investments',
            builder: (context, state) => const InvestmentsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
              GoRoute(
                path: 'tags',
                builder: (context, state) => const TagsScreen(),
              ),
              GoRoute(
                path: 'recurring',
                builder: (context, state) => const RecurringScreen(),
              ),
              GoRoute(
                path: 'data',
                builder: (context, state) => const DataManagementScreen(),
              ),
              GoRoute(
                path: 'theme',
                builder: (context, state) => const ThemeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
