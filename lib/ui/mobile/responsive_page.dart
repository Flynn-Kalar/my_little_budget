import 'package:flutter/widgets.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        return usesMobileLayout(constraints.maxWidth) ? mobile : desktop;
      },
    );
  }
}
