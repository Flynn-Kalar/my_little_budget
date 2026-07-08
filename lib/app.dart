import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'data/providers.dart';
import 'router/app_router.dart';
import 'features/notes/providers.dart';

class MyLittleBudgetApp extends ConsumerStatefulWidget {
  const MyLittleBudgetApp({super.key});

  @override
  ConsumerState<MyLittleBudgetApp> createState() => _MyLittleBudgetAppState();
}

class _MyLittleBudgetAppState extends ConsumerState<MyLittleBudgetApp>
    with WidgetsBindingObserver {
  Timer? _resetTimer;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncNotes());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncNotes();
  }

  Future<void> _syncNotes() async {
    if (_syncing || !mounted) return;
    _syncing = true;
    try {
      final service = ref.read(noteNotificationServiceProvider);
      await service.initialize(
        onNoteTap: (noteId) {
          final tap = DateTime.now().microsecondsSinceEpoch;
          ref.read(appRouterProvider).go('/notes?open=$noteId&tap=$tap');
        },
      );
      final dao = ref.read(notesDaoProvider);
      final changed = await dao.reconcileRecurringNotes(DateTime.now());
      await service.rebuild(await dao.listNotificationEntries());
      if (changed > 0) {
        ref.invalidate(notesProvider);
        ref.invalidate(pendingReminderCountProvider);
      }
      _scheduleNextReset(await dao.earliestNextReset());
    } finally {
      _syncing = false;
    }
  }

  void _scheduleNextReset(DateTime? next) {
    _resetTimer?.cancel();
    if (next == null) return;
    final delay = next.difference(DateTime.now());
    _resetTimer = Timer(
      delay.isNegative ? Duration.zero : delay + const Duration(seconds: 1),
      _syncNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(noteScheduleRevisionProvider, (_, _) => _syncNotes());
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
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      routerConfig: router,
    );
  }
}
