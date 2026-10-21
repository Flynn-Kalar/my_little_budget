import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/bulk_manage_button.dart';

import '../../shell/layout_policy.dart';
export '../../shell/layout_policy.dart' show mobileBreakpoint;

class ResponsivePage extends ConsumerWidget {
  const ResponsivePage({
    super.key,
    required this.desktop,
    required this.mobile,
  });

  final Widget desktop;
  final Widget mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ShellLayoutScope.maybeOf(context);
    final width = layout?.viewportWidth ?? MediaQuery.sizeOf(context).width;
    final page = (layout?.mobile ?? usesMobileLayout(width)) ? mobile : desktop;
    if (!usesHomeBackNavigation(width)) return page;
    final location = GoRouterState.of(context).matchedLocation;
    final bulkEntity = switch (location) {
      '/notes' => BulkEntity.notes,
      '/accounts' => BulkEntity.accounts,
      '/calendar' => BulkEntity.calendar,
      _ => null,
    };
    final selecting =
        bulkEntity != null &&
        ref.watch(bulkSelectionProvider(bulkEntity)) != null;
    const tabs = {
      '/home',
      '/transactions',
      '/stats',
      '/accounts',
      '/notes',
      '/settings',
      '/calendar',
    };
    if (!tabs.contains(location)) return page;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (selecting) {
          if (!bulkSelectionIsBusy(ref, bulkEntity)) {
            ref.read(bulkSelectionProvider(bulkEntity).notifier).state = null;
          }
          return;
        }
        if (location == '/home') {
          SystemNavigator.pop();
        } else {
          context.go('/home');
        }
      },
      child: page,
    );
  }
}
