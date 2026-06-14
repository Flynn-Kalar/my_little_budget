import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'data/providers.dart';
import 'router/app_router.dart';

class MyLittleBudgetApp extends ConsumerWidget {
  const MyLittleBudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final colors = ref.watch(themeProvider);
    final mode = ref.watch(themeModeProvider);
    ref.watch(recurringBackfillProvider);
    return MaterialApp.router(
      title: 'my_little_budget',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(colors: colors),
      darkTheme: buildAppTheme(colors: colors, brightness: Brightness.dark),
      themeMode: mode,
      routerConfig: router,
    );
  }
}
