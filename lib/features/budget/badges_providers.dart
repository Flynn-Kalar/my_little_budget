import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date.dart';
import '../../data/providers.dart';

/// SPEC §2.1 — 사이드바 "예산" 옆 빨간 배지. 이번 달 예산 초과(usage ≥ 100%) 그룹 수.
final overBudgetCountProvider = FutureProvider<int>((ref) async {
  final dao = ref.watch(budgetDaoProvider);
  final rows = await dao.budgetGroupVsActual(currentMonthKey());
  return rows.where((r) => r.usagePercent >= 100).length;
});
