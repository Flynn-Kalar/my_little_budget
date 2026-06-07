import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shell/sidebar_shell.dart';
import '../responsive_page.dart';

class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= mobileBreakpoint) {
          return SidebarShell(child: child);
        }
        return MobileShell(child: child);
      },
    );
  }
}

class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    _MobileNavItem('/transactions', '내역', Icons.receipt_long_outlined),
    _MobileNavItem('/budget', '예산', Icons.savings_outlined),
    _MobileNavItem('/stats', '통계', Icons.bar_chart_outlined),
    _MobileNavItem('/accounts', '자산', Icons.account_balance_wallet_outlined),
    _MobileNavItem('/investments', '투자', Icons.trending_up),
    _MobileNavItem('/settings', '설정', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _items.indexWhere(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );

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
        child: NavigationBar(
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => context.go(_items[index].path),
          destinations: [
            for (final item in _items)
              NavigationDestination(icon: Icon(item.icon), label: item.label),
          ],
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
