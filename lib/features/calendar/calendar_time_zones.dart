import 'package:timezone/timezone.dart' as tz;
import 'calendar_schedule.dart';

const _regionNames = <String, String>{
  'Asia/Seoul': '서울',
  'Asia/Tokyo': '도쿄',
  'Asia/Shanghai': '상하이',
  'Asia/Hong_Kong': '홍콩',
  'Asia/Taipei': '타이베이',
  'Asia/Singapore': '싱가포르',
  'Asia/Bangkok': '방콕',
  'Asia/Ho_Chi_Minh': '호찌민',
  'Asia/Jakarta': '자카르타',
  'Asia/Manila': '마닐라',
  'Asia/Kolkata': '콜카타',
  'Asia/Kathmandu': '카트만두',
  'Asia/Dubai': '두바이',
  'Asia/Tehran': '테헤란',
  'Asia/Jerusalem': '예루살렘',
  'Europe/London': '런던',
  'Europe/Paris': '파리',
  'Europe/Berlin': '베를린',
  'Europe/Rome': '로마',
  'Europe/Madrid': '마드리드',
  'Europe/Moscow': '모스크바',
  'Europe/Istanbul': '이스탄불',
  'America/New_York': '뉴욕',
  'America/Chicago': '시카고',
  'America/Denver': '덴버',
  'America/Los_Angeles': '로스앤젤레스',
  'America/Vancouver': '밴쿠버',
  'America/Toronto': '토론토',
  'America/Mexico_City': '멕시코시티',
  'America/Sao_Paulo': '상파울루',
  'America/Argentina/Buenos_Aires': '부에노스아이레스',
  'Pacific/Honolulu': '호놀룰루',
  'Pacific/Auckland': '오클랜드',
  'Australia/Sydney': '시드니',
  'Australia/Melbourne': '멜버른',
  'Australia/Adelaide': '애들레이드',
  'Australia/Perth': '퍼스',
  'Africa/Cairo': '카이로',
  'Africa/Johannesburg': '요하네스버그',
};

List<String>? _zoneIds;
List<String> get calendarTimeZoneIds => _zoneIds ??= (() {
  calendarZone('UTC');
  return List<String>.unmodifiable({
    'Asia/Seoul',
    'UTC',
    ..._regionNames.keys,
    ...tz.timeZoneDatabase.locations.keys.toList()..sort(),
  });
})();

String calendarZoneRegion(String id) {
  if (_regionNames.containsKey(id)) return _regionNames[id]!;
  if (['UTC', 'GMT', 'Etc/UTC', 'Etc/GMT', 'Etc/GMT0'].contains(id)) {
    return '협정 세계시';
  }
  if (id.startsWith('Etc/GMT')) return '고정 시간대';
  final parts = id.replaceAll('_', ' ').split('/');
  return parts.length == 1
      ? parts.single
      : '${parts.last} (${parts.take(parts.length - 1).join('/')})';
}

String calendarZoneLabel(String id, DateTime date) {
  final zone = calendarZone(id);
  final offset = tz.TZDateTime(
    zone,
    date.year,
    date.month,
    date.day,
    date.hour,
    date.minute,
  ).timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  final fraction = minutes % 60 == 0
      ? ''
      : ':${(minutes % 60).toString().padLeft(2, '0')}';
  return '${calendarZoneRegion(id)} / UTC ${offset.isNegative ? '-' : '+'}${minutes ~/ 60}$fraction';
}

String? resolveCalendarZone(String text, DateTime date) {
  final query = text.trim().toLowerCase();
  if (query.isEmpty) return null;
  for (final id in calendarTimeZoneIds) {
    if (id.toLowerCase() == query ||
        (!id.startsWith('Etc/GMT') &&
            calendarZoneRegion(id).toLowerCase() == query) ||
        id.split('/').last.replaceAll('_', ' ').toLowerCase() == query ||
        (_nativeRegionNames[id] ?? const <String>[]).any(
          (name) => name.toLowerCase() == query,
        ) ||
        calendarZoneLabel(id, date).toLowerCase() == query) {
      return id;
    }
  }
  return null;
}

const _nativeRegionNames = <String, List<String>>{
  'Asia/Seoul': ['서울', '대한민국', '한국'],
  'Asia/Tokyo': ['東京', '日本', '东京'],
  'Asia/Shanghai': ['上海', '中国', '中國'],
  'Asia/Hong_Kong': ['香港'],
  'Asia/Taipei': ['臺北', '台北', '臺灣', '台湾'],
  'Asia/Singapore': ['新加坡', 'Singapura'],
  'Asia/Bangkok': ['กรุงเทพ', 'กรุงเทพมหานคร', 'ประเทศไทย'],
  'Asia/Ho_Chi_Minh': ['Hồ Chí Minh', 'Việt Nam'],
  'Asia/Jakarta': ['Jakarta', 'Indonesia'],
  'Asia/Manila': ['Maynila', 'Pilipinas'],
  'Asia/Kolkata': ['কলকাতা', 'कोलकाता', 'भारत'],
  'Asia/Kathmandu': ['काठमाडौं', 'नेपाल'],
  'Asia/Dubai': ['دبي', 'الإمارات'],
  'Asia/Tehran': ['تهران', 'ایران'],
  'Asia/Jerusalem': ['ירושלים', 'القدس'],
  'Europe/London': ['London', '영국'],
  'Europe/Paris': ['Paris', 'France', '프랑스'],
  'Europe/Berlin': ['Berlin', 'Deutschland', '독일'],
  'Europe/Rome': ['Roma', 'Italia', '이탈리아'],
  'Europe/Madrid': ['Madrid', 'España', '스페인'],
  'Europe/Moscow': ['Москва', 'Россия', '러시아'],
  'Europe/Istanbul': ['İstanbul', 'Türkiye', '터키'],
  'Europe/Vienna': ['Wien', 'Österreich', '빈'],
  'Europe/Athens': ['Αθήνα', 'Ελλάδα', '아테네'],
  'Europe/Kyiv': ['Київ', 'Україна', '키이우'],
  'Europe/Warsaw': ['Warszawa', 'Polska', '바르샤바'],
  'Europe/Prague': ['Praha', 'Česko', '프라하'],
  'Europe/Lisbon': ['Lisboa', 'Portugal', '리스본'],
  'Europe/Helsinki': ['Helsinki', 'Suomi', '헬싱키'],
  'Europe/Stockholm': ['Stockholm', 'Sverige', '스톡홀름'],
  'Africa/Cairo': ['القاهرة', 'مصر'],
  'Africa/Johannesburg': ['Johannesburg'],
  'America/Mexico_City': ['Ciudad de México', 'México'],
  'America/Sao_Paulo': ['São Paulo', 'Brasil'],
  'America/Argentina/Buenos_Aires': ['Buenos Aires', 'Argentina'],
};

String calendarZoneSearchText(String id, DateTime date) =>
    '${calendarZoneLabel(id, date)} $id ${(_nativeRegionNames[id] ?? const <String>[]).join(' ')}'
        .toLowerCase()
        .replaceAll('_', ' ');
