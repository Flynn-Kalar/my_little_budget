import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    final palettes = ref.watch(themeProvider);
    final mode = ref.watch(themeModeProvider);
    ref.watch(recurringBackfillProvider);
    return MaterialApp.router(
      title: 'my_little_budget',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(colors: palettes.light),
      darkTheme: buildAppTheme(
        colors: palettes.dark,
        brightness: Brightness.dark,
      ),
      themeMode: mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      routerConfig: router,
    );
  }
}
