import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../shell/layout_policy.dart';
export '../../shell/layout_policy.dart' show mobileBreakpoint;

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.desktop,
    required this.mobile,
  });

  final Widget desktop;
  final Widget mobile;

  @override
  Widget build(BuildContext context) {
    final layout = ShellLayoutScope.maybeOf(context);
    final width = layout?.viewportWidth ?? MediaQuery.sizeOf(context).width;
    final page = (layout?.mobile ?? usesMobileLayout(width)) ? mobile : desktop;
    if (!usesHomeBackNavigation(width)) return page;
    final location = GoRouterState.of(context).matchedLocation;
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
