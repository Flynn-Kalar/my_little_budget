import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_little_budget/features/settings/update_check.dart';

void main() {
  test('RC 버전보다 높은 GitHub prerelease를 새 버전으로 감지한다', () async {
    final service = UpdateCheckService(
      client: MockClient((request) async {
        expect(request.url.path, endsWith('/releases'));
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.0.0-rc.2',
              'name': '1.0.0 RC 2',
              'html_url':
                  'https://github.com/Flynn-Kalar/my_little_budget/releases/tag/v1.0.0-rc.2',
              'draft': false,
              'prerelease': true,
            },
          ]),
          200,
        );
      }),
    );

    final result = await service.check(currentVersion: '1.0.0-rc.1+42');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.latestRelease?.tagName, 'v1.0.0-rc.2');
    expect(result.latestRelease?.prerelease, isTrue);
  });

  test('버전 순서가 아닌 응답에서도 가장 높은 공개 릴리스를 선택한다', () async {
    final service = UpdateCheckService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            _release('v1.0.0'),
            _release('v1.2.0'),
            {..._release('v2.0.0'), 'draft': true},
          ]),
          200,
        ),
      ),
    );

    final result = await service.check(currentVersion: '1.1.0+10');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.latestRelease?.tagName, 'v1.2.0');
  });

  test('릴리스가 없으면 noRelease를 반환한다', () async {
    final service = UpdateCheckService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );

    final result = await service.check(currentVersion: '1.0.0+1');

    expect(result.status, UpdateCheckStatus.noRelease);
    expect(result.latestRelease, isNull);
  });

  test('현재 버전이 같거나 높으면 최신 상태로 판단한다', () async {
    final service = UpdateCheckService(
      client: MockClient(
        (_) async => http.Response(jsonEncode([_release('v1.0.0')]), 200),
      ),
    );

    final result = await service.check(currentVersion: '1.0.0+42');

    expect(result.status, UpdateCheckStatus.upToDate);
  });

  test('GitHub 오류 응답을 사용자용 오류로 변환한다', () async {
    final service = UpdateCheckService(
      client: MockClient((_) async => http.Response('{}', 403)),
    );

    expect(
      () => service.check(currentVersion: '1.0.0+42'),
      throwsA(
        isA<UpdateCheckException>().having(
          (error) => error.message,
          'message',
          contains('403'),
        ),
      ),
    );
  });
}

Map<String, Object> _release(String tag) => {
  'tag_name': tag,
  'name': tag,
  'html_url':
      'https://github.com/Flynn-Kalar/my_little_budget/releases/tag/$tag',
  'draft': false,
  'prerelease': false,
};
