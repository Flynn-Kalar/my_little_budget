import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/date.dart';
import '../calendar/korean_holidays.dart';

class StatementPeriod {
  const StatementPeriod({
    this.day = 1,
    this.adjustment = 'same',
    this.labelByEnd = false,
  });
  final bool labelByEnd;
  final int day; // 0 = month end
  final String adjustment;

  StatementPeriod copyWith({int? day, String? adjustment, bool? labelByEnd}) =>
      StatementPeriod(
        day: day ?? this.day,
        adjustment: adjustment ?? this.adjustment,
        labelByEnd: labelByEnd ?? this.labelByEnd,
      );

  String anchorForDate(DateTime date) {
    final key = toDateKey(date);
    final nominal = toMonthKey(date);
    for (final offset in [0, -1, 1, -2, 2]) {
      final anchor = shiftMonth(nominal, offset);
      final bounds = range(anchor);
      if (key.compareTo(bounds.start) >= 0 && key.compareTo(bounds.end) <= 0) {
        return anchor;
      }
    }
    throw StateError('No statement period for $key');
  }

  List<String> anchorsForYear(int year) => [
    for (var offset = -1; offset <= 12; offset++)
      if (displayMonth(shiftMonth('$year-01', offset)).startsWith('$year-'))
        shiftMonth('$year-01', offset),
  ];

  ({String start, String end}) yearRange(int year) {
    final anchors = anchorsForYear(year);
    return (start: range(anchors.first).start, end: range(anchors.last).end);
  }

  String displayMonth(String month) {
    final dates = range(month);
    return (labelByEnd ? dates.end : dates.start).substring(0, 7);
  }

  String anchorForDisplay(String selected, String current) {
    if (displayMonth(current) == selected) return current;
    final currentDate = parseMonthKey(current);
    final displayDate = parseMonthKey(displayMonth(current));
    final offset =
        (currentDate.year - displayDate.year) * 12 +
        currentDate.month -
        displayDate.month;
    final guess = shiftMonth(selected, offset);
    for (final delta in [0, -1, 1, -2, 2]) {
      final candidate = shiftMonth(guess, delta);
      if (displayMonth(candidate) == selected) return candidate;
    }
    return guess;
  }

  DateTime start(String month) {
    final anchor = parseMonthKey(month);
    final last = DateTime(anchor.year, anchor.month + 1, 0).day;
    var date = DateTime(
      anchor.year,
      anchor.month,
      day == 0 ? last : day.clamp(1, last),
    );
    if (adjustment != 'same') {
      final step = adjustment == 'previous' ? -1 : 1;
      while (date.weekday >= 6 || isKoreanHoliday(date)) {
        date = DateTime(date.year, date.month, date.day + step);
      }
    }
    return date;
  }

  ({String start, String end}) range(String month) {
    final next = start(shiftMonth(month, 1));
    return (
      start: toDateKey(start(month)),
      end: toDateKey(DateTime(next.year, next.month, next.day - 1)),
    );
  }
}

final statementPeriodProvider =
    AsyncNotifierProvider<StatementPeriodController, StatementPeriod>(
      StatementPeriodController.new,
    );

class StatementPeriodController extends AsyncNotifier<StatementPeriod> {
  @override
  Future<StatementPeriod> build() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } on MissingPluginException {
      return const StatementPeriod();
    }
    final value = prefs.getString('transaction_statement_period')?.split(':');
    final day = int.tryParse(value?.first ?? '') ?? 1;
    final adjustment = value != null && value.length >= 2 ? value[1] : 'same';
    return StatementPeriod(
      day: day.clamp(0, 31),
      labelByEnd: value != null && value.length >= 3 && value[2] == 'end',
      adjustment: ['same', 'previous', 'next'].contains(adjustment)
          ? adjustment
          : 'same',
    );
  }

  Future<void> save(StatementPeriod value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'transaction_statement_period',
      '${value.day}:${value.adjustment}:${value.labelByEnd ? 'end' : 'start'}',
    )) {
      throw StateError('설정을 저장하지 못했습니다.');
    }
    state = AsyncData(value);
  }
}

final statementTodayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
final currentStatementMonthProvider = Provider<String>((ref) {
  final today = ref.watch(statementTodayProvider);
  final policy =
      ref.watch(statementPeriodProvider).asData?.value ??
      const StatementPeriod();
  return policy.anchorForDate(today);
});

/// Follow the current period until the user explicitly selects a month.
/// Preference loading and midnight refreshes must not overwrite that choice.
class StatementMonthController extends StateController<String> {
  StatementMonthController(super.state);

  bool _selected = false;

  @override
  set state(String value) {
    _selected = true;
    super.state = value;
  }

  void followCurrent(String value) {
    if (!_selected) super.state = value;
  }
}

StatementMonthController createStatementMonthController(Ref ref) {
  final controller = StatementMonthController(
    ref.read(currentStatementMonthProvider),
  );
  ref.listen(currentStatementMonthProvider, (_, next) {
    controller.followCurrent(next);
  });
  return controller;
}
