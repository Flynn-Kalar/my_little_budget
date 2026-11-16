import 'package:flutter/widgets.dart';

import '../ui/mobile/shell/mobile_shell.dart';
import 'layout_policy.dart';
import '../ui/desktop/shell/sidebar_shell.dart';

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
