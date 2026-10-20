import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/core/money.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/core/theme/theme_colors.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/daos/transactions_dao.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/stats/providers.dart';
import 'package:my_little_budget/ui/desktop/stats/stats_screen.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_DESIGN');
  const boundaryKey = ValueKey('trend-design-preview');
  final rows = List.generate(
    12,
    (index) => MonthlyTrendRow(
      month: toMonthKey(DateTime(2025, 11 + index)),
      income: [
        1965800,
        1875800,
        1875800,
        3336020,
        2482790,
        2086020,
        3156196,
        2194797,
        5009298,
        2326414,
        3268394,
        2138213,
      ][index],
      expense: [
        993466,
        1233946,
        856966,
        857011,
        1003145,
        939633,
        1200248,
        1495184,
        2151769,
        2059291,
        3900590,
        1105204,
      ][index],
    ),
  );

  Future<void> boot(
    WidgetTester tester,
    List<MonthlyTrendRow> data, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    if (capture) {
      await tester.runAsync(() async {
        final font = ByteData.sublistView(
          await File('C:/Windows/Fonts/malgun.ttf').readAsBytes(),
        );
        for (final family in ['Roboto', 'Segoe UI']) {
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
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          statsMonthProvider.overrideWith((ref) => '2026-10'),
          statsMonthlyTrendProvider.overrideWith((ref) async => data),
          statsExpenseBreakdownProvider.overrideWith((ref) async => []),
        ],
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: buildAppTheme(
              colors: dark ? darkDefaultTheme : defaultTheme,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: const Scaffold(
              body: Padding(padding: EdgeInsets.all(24), child: StatsScreen()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'PC trend has a chart on the left, totals on the right and all twelve months in one table',
    (tester) async {
      await boot(tester, rows);
      final chart = find.byKey(const ValueKey('desktop-trend-chart'));
      final totals = find.byKey(const ValueKey('desktop-trend-totals'));
      final tableFinder = find.byKey(
        const ValueKey('desktop-trend-monthly-table'),
      );
      await tester.ensureVisible(tableFinder);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(totals).dx,
        greaterThan(tester.getTopRight(chart).dx),
      );
      expect(
        tester.getTopLeft(tableFinder).dy,
        greaterThan(tester.getBottomLeft(chart).dy),
      );
      final table = tester.widget<Table>(tableFinder);
      expect(table.children, hasLength(4));
      for (final row in table.children) {
        expect(row.children, hasLength(13));
      }
      expect(
        find.descendant(of: tableFinder, matching: find.text('2025.11')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tableFinder, matching: find.text('2026.10')),
        findsOneWidget,
      );
      final income = rows.fold<int>(0, (sum, row) => sum + row.income);
      expect(
        find.descendant(of: totals, matching: find.text(formatKRW(income))),
        findsOneWidget,
      );
      expect(
        find.byTooltip('2026-09 순액 ${formatKRW(rows[10].net)}'),
        findsOneWidget,
      );
      final graph = tester.widget<LineChart>(find.byType(LineChart));
      expect(graph.data.minY, lessThan(0));
      for (final line in graph.data.lineBarsData) {
        expect(line.spots, hasLength(12));
        expect(line.belowBarData.show, isFalse);
      }
      expect(tester.takeException(), isNull);
      if (capture) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final cardRect = tester.getRect(
          find.ancestor(of: chart, matching: find.byType(Card)).first,
        );
        await tester.runAsync(() async {
          // Capture only the chart card within this test's repaint boundary.
          // ignore: invalid_use_of_protected_member
          final image = await (boundary.layer! as OffsetLayer).toImage(
            cardRect,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('.scratch/mint-redesign/desktop-trend.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'PC trend retains exact amounts in dark mode and handles an empty period',
    (tester) async {
      await boot(tester, [], dark: true);
      expect(find.text('최근 12개월 거래 내역이 없습니다.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-trend-monthly-table')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('desktop-trend-totals')),
          matching: find.text(formatKRW(0)),
        ),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
