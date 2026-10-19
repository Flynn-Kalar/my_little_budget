import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The page title stays separate; only the chevron button pops the page.
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null || !router.canPop()) return const SizedBox.shrink();
    return IconButton(
      tooltip: '뒤로가기',
      icon: const Icon(Icons.chevron_left),
      onPressed: () => router.pop(),
    );
  }
}
