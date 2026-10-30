import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/date.dart';
import '../calendar/korean_holidays.dart';

class StatementPeriod {
  const StatementPeriod({this.day = 1, this.adjustment = 'same'});
  final int day; // 0 = month end
  final String adjustment;

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
    final adjustment = value != null && value.length == 2 ? value[1] : 'same';
    return StatementPeriod(
      day: day.clamp(0, 31),
      adjustment: ['same', 'previous', 'next'].contains(adjustment)
          ? adjustment
          : 'same',
    );
  }

  Future<void> save(StatementPeriod value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'transaction_statement_period',
      '${value.day}:${value.adjustment}',
    )) {
      throw StateError('설정을 저장하지 못했습니다.');
    }
    state = AsyncData(value);
  }
}
