import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/calendar/calendar_time_zones.dart';

void main() {
  final winter = DateTime(2026, 1, 15, 12), summer = DateTime(2026, 7, 15, 12);
  test(
    'region labels use fractional offsets and date-specific daylight time',
    () {
      expect(calendarZoneLabel('Asia/Seoul', winter), '서울 / UTC +9');
      expect(calendarZoneLabel('UTC', winter), '협정 세계시 / UTC +0');
      expect(calendarZoneLabel('Asia/Kolkata', winter), '콜카타 / UTC +5:30');
      expect(calendarZoneLabel('Asia/Kathmandu', winter), '카트만두 / UTC +5:45');
      expect(calendarZoneLabel('America/New_York', winter), '뉴욕 / UTC -5');
      expect(calendarZoneLabel('America/New_York', summer), '뉴욕 / UTC -4');
      expect(calendarZoneLabel('Etc/GMT-9', winter), '고정 시간대 / UTC +9');
      expect(calendarZoneLabel('Etc/GMT+3', winter), '고정 시간대 / UTC -3');
      for (final id in calendarTimeZoneIds) {
        expect(calendarZoneLabel(id, summer), contains(' / UTC '));
      }
    },
  );
  test('Korean, local scripts, English and identifiers are searchable', () {
    for (final text in ['서울', 'Asia/Seoul', 'seoul', '한국', '서울 / UTC +9']) {
      expect(resolveCalendarZone(text, winter), 'Asia/Seoul');
    }
    for (final pair in {
      '東京': 'Asia/Tokyo',
      '上海': 'Asia/Shanghai',
      'Москва': 'Europe/Moscow',
      'دبي': 'Asia/Dubai',
      'Roma': 'Europe/Rome',
      'New York': 'America/New_York',
      '臺北': 'Asia/Taipei',
    }.entries) {
      expect(resolveCalendarZone(pair.key, summer), pair.value);
      expect(
        calendarZoneSearchText(pair.value, summer),
        contains(pair.key.toLowerCase()),
      );
    }
    expect(resolveCalendarZone('missing location', summer), isNull);
    expect(resolveCalendarZone('고정 시간대', summer), isNull);
    expect(calendarTimeZoneIds.first, 'Asia/Seoul');
  });
}
