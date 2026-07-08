import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/notes/providers.dart';

class _NavItem {
  const _NavItem({required this.path, required this.label, required this.icon});
  final String path;
  final String label;
  final IconData icon;
}

const _topItems = <_NavItem>[
  _NavItem(
    path: '/transactions',
    label: '내역',
    icon: Icons.receipt_long_outlined,
  ),
  _NavItem(path: '/stats', label: '통계', icon: Icons.bar_chart_outlined),
  _NavItem(
    path: '/accounts',
    label: '자산',
    icon: Icons.account_balance_wallet_outlined,
  ),
  _NavItem(path: '/notes', label: '메모', icon: Icons.note_alt_outlined),
];

const _bottomItems = <_NavItem>[
  _NavItem(path: '/settings', label: '설정', icon: Icons.settings_outlined),
];

class SidebarShell extends ConsumerWidget {
  const SidebarShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final pendingReminders =
        ref.watch(pendingReminderCountProvider).asData?.value ?? 0;
    final sidebarBg = context.desktopSidebarBackground;
    final border = context.desktopBorder;
    final background = context.desktopBackground;
    final muted = context.desktopMuted;

    int badgeFor(String path) => switch (path) {
      '/notes' => pendingReminders,
      _ => 0,
    };

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 224,
              decoration: BoxDecoration(
                color: sidebarBg,
                border: Border(right: BorderSide(color: border)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'my_little_budget',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '나만의 작은 가계부',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  ..._topItems.map(
                    (item) => _NavTile(
                      item: item,
                      current: location,
                      badge: badgeFor(item.path),
                    ),
                  ),
                  const Spacer(),
                  ..._bottomItems.map(
                    (item) => _NavTile(item: item, current: location),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: background,
                child: Padding(padding: const EdgeInsets.all(32), child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.current, this.badge = 0});
  final _NavItem item;
  final String current;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final active = current == item.path || current.startsWith('${item.path}/');
    final foreground = Theme.of(context).colorScheme.onSurface;
    final muted = context.desktopMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? context.desktopSelectedSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(item.icon, size: 16, color: active ? foreground : muted),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active ? foreground : muted,
                    ),
                  ),
                ),
                if (badge > 0) _Badge(count: badge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 빨간 카운트 배지 (SPEC §2.1).
class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: red),
      ),
    );
  }
}
