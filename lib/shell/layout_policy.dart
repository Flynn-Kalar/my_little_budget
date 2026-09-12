import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const mobileBreakpoint = 900.0;
const desktopCompactBreakpoint = 1200.0;

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
