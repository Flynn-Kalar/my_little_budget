import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/home/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/router/app_router.dart';
import 'package:my_little_budget/ui/desktop/home/home_screen.dart';
import 'package:my_little_budget/ui/mobile/home/mobile_home_screen.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_DESIGN');
  const boundaryKey = ValueKey('design-capture');
  late AppDatabase db;
  late int account;
  late int category;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    account = (await db.accountsDao.getActiveAccounts()).first.id;
    category = (await db.categoriesDao.getActiveCategories('expense')).first.id;
    await db.budgetDao.createBudgetGroup(
      name: '생활 예산',
      month: currentMonthKey(),
      amount: 3000000,
      categoryIds: [category],
    );
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 4800,
        occurredOn: currentDateKey(),
        occurredTime: '12:00',
        accountId: account,
        categoryId: category,
        memo: '카페',
      ),
      tagNames: ['카페'],
    );
  });
  tearDown(() => db.close());

  Future<ProviderContainer> boot(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (capture) {
      await tester.runAsync(() async {
        final font = ByteData.sublistView(
          await File('C:/Windows/Fonts/malgun.ttf').readAsBytes(),
        );
        for (final family in ['Roboto', 'Segoe UI', 'Malgun Gothic']) {
          await (FontLoader(family)..addFont(Future.value(font))).load();
        }
        final icons = ByteData.sublistView(
          await File(
            'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes(),
        );
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(icons))).load();
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const RepaintBoundary(
          key: boundaryKey,
          child: MyLittleBudgetApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!capture) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.scratch/mint-redesign/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'mobile starts on home without a home tab; every tab returns home; one back exits',
    (tester) async {
      final container = await boot(tester, const Size(390, 844));
      final router = container.read(appRouterProvider);
      expect(find.byType(MobileHomeScreen), findsOneWidget);
      expect(find.text('홈'), findsNothing);
      expect(find.text(formatKRW(2995200)), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-tab-home')), findsNothing);
      await screenshot(tester, 'mobile-home');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      for (final tab in [
        'transactions',
        'stats',
        'accounts',
        'notes',
        'settings',
      ]) {
        await tester.tap(find.byKey(ValueKey('mobile-tab-$tab')));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/$tab');
        if (tab == 'stats' || tab == 'transactions') {
          await screenshot(tester, 'mobile-$tab');
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/home');
        expect(find.byType(MobileHomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(
        calls.where((call) => call.method == 'SystemNavigator.pop'),
        isEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'mobile modal back closes the modal before navigating to home',
    (tester) async {
      final container = await boot(tester, const Size(390, 844));
      await tester.tap(find.byKey(const ValueKey('mobile-tab-transactions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('거래 추가'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/transactions',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MobileHomeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'desktop has a home menu and keeps desktop pages at narrow widths',
    (tester) async {
      final container = await boot(tester, const Size(1440, 1000));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('홈'), findsOneWidget);
      await screenshot(tester, 'desktop-home');
      for (final route in ['/transactions', '/stats', '/stats/yearly']) {
        container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        await screenshot(tester, 'desktop-${route.split('/').last}');
        expect(tester.takeException(), isNull);
      }
      for (final width in [800.0, 500.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.binding.setSurfaceSize(Size(width, 900));
        for (final route in [
          '/home',
          '/transactions',
          '/stats',
          '/stats/yearly',
        ]) {
          container.read(appRouterProvider).go(route);
          await tester.pumpAndSettle();
          expect(find.text('홈'), findsOneWidget);
          expect(find.byType(MobileHomeScreen), findsNothing);
          expect(tester.takeException(), isNull, reason: '$route at $width');
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'wide mobile uses the wide shell without a home button and back still returns home',
    (tester) async {
      final container = await boot(tester, const Size(1000, 900));
      final router = container.read(appRouterProvider);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('홈'), findsNothing);
      router.go('/stats');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'home refreshes after transaction and budget changes and ignores transaction filters',
    (tester) async {
      final container = await boot(tester, const Size(390, 844));
      container.read(typeFilterProvider.notifier).state = 'income';
      container.read(searchFilterProvider.notifier).state =
          const TransactionFilter(q: 'no match');
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 10000,
          occurredOn: currentDateKey(),
          occurredTime: '13:00',
          accountId: account,
          categoryId: category,
          memo: '점심',
        ),
      );
      await tester.pumpAndSettle();
      final overview = container.read(homeOverviewProvider).requireValue;
      expect(overview.summary.expense, 14800);
      expect(overview.remaining, 2985200);
      expect(overview.recent.first.memo, '점심');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
