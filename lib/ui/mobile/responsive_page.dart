import 'package:flutter/widgets.dart';

const mobileBreakpoint = 900.0;

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
        return constraints.maxWidth < mobileBreakpoint ? mobile : desktop;
      },
    );
  }
}
