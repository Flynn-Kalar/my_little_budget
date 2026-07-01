import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/budget/budget_page.dart';
import '../features/investments/investments_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stats/stats_page.dart';
import '../ui/desktop/accounts/account_detail_screen.dart';
import '../ui/desktop/accounts/accounts_screen.dart';
import '../ui/desktop/notes/notes_screen.dart';
import '../ui/desktop/settings/categories_screen.dart';
import '../ui/desktop/settings/data_management_screen.dart';
import '../ui/desktop/settings/recurring_screen.dart';
import '../ui/desktop/settings/tags_screen.dart';
import '../ui/desktop/settings/theme_screen.dart';
import '../ui/desktop/stats/yearly_stats_screen.dart';
import '../ui/desktop/transactions/transactions_screen.dart';
import '../ui/mobile/accounts/mobile_accounts_screen.dart';
import '../ui/mobile/accounts/mobile_account_detail_screen.dart';
import '../ui/mobile/budget/mobile_budget_screen.dart';
import '../ui/mobile/investments/mobile_investments_screen.dart';
import '../ui/mobile/notes/mobile_notes_screen.dart';
import '../ui/mobile/responsive_page.dart';
import '../ui/mobile/settings/mobile_categories_screen.dart';
import '../ui/mobile/settings/mobile_settings_screen.dart';
import '../ui/mobile/settings/mobile_data_management_screen.dart';
import '../ui/mobile/settings/mobile_recurring_screen.dart';
import '../ui/mobile/settings/mobile_tags_screen.dart';
import '../ui/mobile/settings/mobile_theme_screen.dart';
import '../ui/mobile/shell/mobile_shell.dart';
import '../ui/mobile/stats/mobile_stats_screen.dart';
import '../ui/mobile/stats/mobile_yearly_stats_screen.dart';
import '../ui/mobile/transactions/mobile_transactions_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/transactions',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ResponsiveShell(child: child),
        routes: [
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const ResponsivePage(
              desktop: TransactionsScreen(),
              mobile: MobileTransactionsScreen(),
            ),
          ),
          GoRoute(
            path: '/budget',
            builder: (context, state) => const ResponsivePage(
              desktop: BudgetPage(),
              mobile: MobileBudgetScreen(),
            ),
          ),
          GoRoute(
            path: '/stats',
            builder: (context, state) => const ResponsivePage(
              desktop: StatsPage(),
              mobile: MobileStatsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'yearly',
                builder: (context, state) => const ResponsivePage(
                  desktop: YearlyStatsScreen(),
                  mobile: MobileYearlyStatsScreen(),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const ResponsivePage(
              desktop: AccountsScreen(),
              mobile: MobileAccountsScreen(),
            ),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ResponsivePage(
                    desktop: AccountDetailScreen(accountId: id),
                    mobile: MobileAccountDetailScreen(accountId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/investments',
            builder: (context, state) => const ResponsivePage(
              desktop: InvestmentsPage(),
              mobile: MobileInvestmentsScreen(),
            ),
          ),
          GoRoute(
            path: '/notes',
            builder: (context, state) {
              final openNoteId = int.tryParse(
                state.uri.queryParameters['open'] ?? '',
              );
              final openRequest =
                  state.uri.queryParameters['tap'] ??
                  state.uri.queryParameters['open'];
              return ResponsivePage(
                desktop: NotesScreen(
                  openNoteId: openNoteId,
                  openRequest: openRequest,
                ),
                mobile: MobileNotesScreen(
                  openNoteId: openNoteId,
                  openRequest: openRequest,
                ),
              );
            },
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const ResponsivePage(
              desktop: SettingsPage(),
              mobile: MobileSettingsScreen(),
            ),
            routes: [
              GoRoute(
                path: 'categories',
                builder: (context, state) => const ResponsivePage(
                  desktop: CategoriesScreen(),
                  mobile: MobileCategoriesScreen(),
                ),
              ),
              GoRoute(
                path: 'tags',
                builder: (context, state) => const ResponsivePage(
                  desktop: TagsScreen(),
                  mobile: MobileTagsScreen(),
                ),
              ),
              GoRoute(
                path: 'recurring',
                builder: (context, state) => const ResponsivePage(
                  desktop: RecurringScreen(),
                  mobile: MobileRecurringScreen(),
                ),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const ResponsivePage(
                  desktop: DataManagementScreen(),
                  mobile: MobileDataManagementScreen(),
                ),
              ),
              GoRoute(
                path: 'data',
                redirect: (context, state) => '/settings/backup',
              ),
              GoRoute(
                path: 'theme',
                builder: (context, state) => const ResponsivePage(
                  desktop: ThemeScreen(),
                  mobile: MobileThemeScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
