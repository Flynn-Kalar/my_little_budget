import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'data/providers.dart';
import 'data/sync_models.dart';
import 'router/app_router.dart';
import 'features/notes/providers.dart';
import 'features/sync/invalidate_synced_data.dart';

class MyLittleBudgetApp extends ConsumerStatefulWidget {
  const MyLittleBudgetApp({super.key});

  @override
  ConsumerState<MyLittleBudgetApp> createState() => _MyLittleBudgetAppState();
}

class _MyLittleBudgetAppState extends ConsumerState<MyLittleBudgetApp>
    with WidgetsBindingObserver {
  Timer? _resetTimer;
  bool _notesSyncing = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resumeApp());
  }

  Future<void> _initializeApp() async {
    if (_initializing || !mounted) return;
    _initializing = true;
    try {
      final coordinator = ref.read(supabaseSyncCoordinatorProvider);
      coordinator.start(onResult: _handleSyncResult);
      final syncResult = await coordinator.synchronizeNow();
      if (syncResult.isOk) {
        await _runRecurringBackfillAfterPull();
        await coordinator.pushNow();
      }
      await _syncNotes();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _resumeApp() async {
    if (!mounted) return;
    final coordinator = ref.read(supabaseSyncCoordinatorProvider);
    final syncResult = await coordinator.synchronizeNow();
    if (syncResult.isOk) {
      await _runRecurringBackfillAfterPull();
      await coordinator.pushNow();
    }
    await _syncNotes();
  }

  void _handleSyncResult(SyncRunResult result) {
    if (!mounted || !result.changedLocalData) return;
    invalidateSyncedData(ref);
  }

  Future<void> _runRecurringBackfillAfterPull() async {
    // Run a fresh pass after every successful pull. Keeping this out of screen
    // providers prevents the initial /transactions route from racing startup.
    ref.invalidate(recurringBackfillProvider);
    final generated = await ref.read(recurringBackfillProvider.future);
    if (generated > 0 && mounted) invalidateSyncedData(ref);
  }

  Future<void> _syncNotes() async {
    if (_notesSyncing || !mounted) return;
    _notesSyncing = true;
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
      _notesSyncing = false;
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
