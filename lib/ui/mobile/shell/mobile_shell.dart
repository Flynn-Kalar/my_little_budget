import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shell/sidebar_shell.dart';
import 'package:my_little_budget/features/notes/providers.dart';
import '../../../shell/layout_policy.dart';
import '../../../core/theme/app_theme.dart';

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = usesMobileLayout(constraints.maxWidth);
        return ShellLayoutScope(
          mobile: mobile,
          viewportWidth: constraints.maxWidth,
          child: mobile
              ? MobileShell(child: child)
              : SidebarShell(child: child),
        );
      },
    );
  }
}

class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    _MobileNavItem('/transactions', '내역', Icons.receipt_long_outlined),
    _MobileNavItem('/stats', '통계', Icons.bar_chart_outlined),
    _MobileNavItem('/accounts', '자산', Icons.account_balance_wallet_outlined),
    _MobileNavItem('/notes', '메모', Icons.note_alt_outlined),
    _MobileNavItem('/settings', '설정', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final pendingReminders =
        ref.watch(pendingReminderCountProvider).asData?.value ?? 0;
    final selectedIndex = _items.indexWhere((item) {
      if (location == '/calendar' || location.startsWith('/calendar/')) {
        return item.path == '/notes';
      }
      return location == item.path || location.startsWith('${item.path}/');
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: child,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Material(
            key: const ValueKey('mobile-bottom-navigation'),
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: Semantics(
                      selected: index == selectedIndex,
                      button: true,
                      child: InkWell(
                        key: ValueKey(
                          'mobile-tab-${_items[index].path.substring(1)}',
                        ),
                        onTap: () => context.go(_items[index].path),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: index == selectedIndex
                                      ? context.appIncome.withValues(alpha: .12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Badge(
                                  isLabelVisible:
                                      _items[index].path == '/notes' &&
                                      pendingReminders > 0,
                                  label: Text('$pendingReminders'),
                                  child: Icon(
                                    _items[index].icon,
                                    size: 24,
                                    color: index == selectedIndex
                                        ? context.appIncome
                                        : context.desktopMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _items[index].label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: index == selectedIndex
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: index == selectedIndex
                                      ? context.appIncome
                                      : context.desktopMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem {
  const _MobileNavItem(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}
