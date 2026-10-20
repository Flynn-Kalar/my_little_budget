import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const mobileBreakpoint = 900.0;
const desktopCompactBreakpoint = 1200.0;

/// Carries the shell's viewport decision into pages, whose available content
/// width may be smaller after reserving room for the sidebar.
class ShellLayoutScope extends InheritedWidget {
  const ShellLayoutScope({
    super.key,
    required this.mobile,
    required this.viewportWidth,
    required super.child,
  });

  final bool mobile;
  final double viewportWidth;

  static ShellLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellLayoutScope>();

  @override
  bool updateShouldNotify(ShellLayoutScope oldWidget) =>
      mobile != oldWidget.mobile || viewportWidth != oldWidget.viewportWidth;
}

bool get isMobileAppPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// Native mobile navigation keeps its back behavior even when a tablet uses
// the wide shell. Desktop browsers retain their usual navigation behavior.
bool usesHomeBackNavigation(double width) =>
    isMobileAppPlatform || usesMobileLayout(width);

// Web keeps its existing width-based behavior, including desktop browsers.
bool get isDesktopPlatform =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };

bool usesMobileLayout(double width) =>
    !isDesktopPlatform && width < mobileBreakpoint;

bool isCompactDesktop(BuildContext context) =>
    isDesktopPlatform &&
    MediaQuery.sizeOf(context).width < desktopCompactBreakpoint;
