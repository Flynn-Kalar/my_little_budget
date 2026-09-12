import 'package:flutter/material.dart';

/// Horizontal scrolling only for dense desktop sections (tables/input rows).
/// The page and sidebar retain their viewport width and normal navigation.
class DesktopSection extends StatefulWidget {
  const DesktopSection({
    super.key,
    required this.minWidth,
    required this.child,
  });

  final double minWidth;
  final Widget child;

  @override
  State<DesktopSection> createState() => _DesktopSectionState();
}

class _DesktopSectionState extends State<DesktopSection> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final needsScroll = constraints.maxWidth < widget.minWidth;
      // Keep the subtree stable across resizing so form state/focus survives.
      return Scrollbar(
        controller: _scroll,
        thumbVisibility: needsScroll,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: needsScroll ? 12 : 0),
          child: SizedBox(
            width: needsScroll ? widget.minWidth : constraints.maxWidth,
            child: widget.child,
          ),
        ),
      );
    },
  );
}
