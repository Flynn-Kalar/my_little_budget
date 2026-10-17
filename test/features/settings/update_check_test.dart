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
              'assets': [
                {
                  'name': 'MyLittleBudget-Setup-1.0.0-rc.2.exe',
                  'browser_download_url':
                      'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-Setup-1.0.0-rc.2.exe',
                  'size': 1234,
                  'digest':
                      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                },
              ],
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
    expect(
      result.latestRelease?.windowsInstaller?.name,
      'MyLittleBudget-Setup-1.0.0-rc.2.exe',
    );
    expect(result.latestRelease?.windowsInstaller?.size, 1234);
    expect(
      result.latestRelease?.windowsInstaller?.sha256,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
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

  test('빌드 번호가 올라간 태그와 기본 버전명 설치본을 함께 인식한다', () async {
    final service = UpdateCheckService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              ..._release('v1.0.0-rc.1+54'),
              'assets': [
                {
                  'name': 'MyLittleBudget-Setup-1.0.0-rc.1.exe',
                  'browser_download_url':
                      'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.1%2B54/MyLittleBudget-Setup-1.0.0-rc.1.exe',
                  'size': 100,
                  'digest': 'sha256:${'a' * 64}',
                },
              ],
            },
          ]),
          200,
        ),
      ),
    );
    final result = await service.check(currentVersion: '1.0.0-rc.1+53');
    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(
      result.latestRelease!.windowsInstaller!.name,
      'MyLittleBudget-Setup-1.0.0-rc.1.exe',
    );
    expect(
      hasVerifiedWindowsInstaller(result.latestRelease!.windowsInstaller),
      isTrue,
    );
  });

  for (final updateVerified in [true, false]) {
    test('Update 우선 선택, 검증 정보가 없으면 기존 Setup 사용: $updateVerified', () async {
      Map<String, Object?> asset(String kind, bool verified) => {
        'name': 'MyLittleBudget-$kind-1.0.0-rc.2.exe',
        'browser_download_url':
            'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-$kind-1.0.0-rc.2.exe',
        'size': 100,
        'digest': verified ? 'sha256:${'a' * 64}' : null,
      };
      final service = UpdateCheckService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                ..._release('v1.0.0-rc.2'),
                'assets': [
                  asset('Setup', true),
                  asset('Update', updateVerified),
                ],
              },
            ]),
            200,
          ),
        ),
      );
      final release = (await service.check(
        currentVersion: '1.0.0-rc.1+53',
      )).latestRelease!;
      expect(
        release.windowsInstaller!.name,
        'MyLittleBudget-${updateVerified ? 'Update' : 'Setup'}-1.0.0-rc.2.exe',
      );
    });
  }

  test('다른 저장소의 설치 파일 URL과 없는 검증 정보는 자동 설치 대상으로 보지 않는다', () async {
    final service = UpdateCheckService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              ..._release('v1.0.0-rc.2'),
              'assets': [
                {
                  'name': 'MyLittleBudget-Setup-1.0.0-rc.2.exe',
                  'browser_download_url':
                      'https://github.com/elsewhere/app/releases/download/v1.0.0-rc.2/MyLittleBudget-Setup-1.0.0-rc.2.exe',
                  'size': 100,
                  'digest': 'sha256:${'a' * 64}',
                },
              ],
            },
          ]),
          200,
        ),
      ),
    );
    expect(
      (await service.check(
        currentVersion: '1.0.0-rc.1+53',
      )).latestRelease!.windowsInstaller,
      isNull,
    );
    expect(
      hasVerifiedWindowsInstaller(
        GitHubReleaseAsset(
          name: 'file.exe',
          downloadUrl: Uri(),
          size: 10,
          sha256: null,
        ),
      ),
      isFalse,
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
