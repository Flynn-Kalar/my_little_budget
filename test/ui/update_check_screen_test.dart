import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/settings/settings_page.dart';
import 'package:my_little_budget/features/settings/update_check.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

void main() {
  testWidgets('데스크톱 설정 메인에서 버튼을 눌러 새 버전을 확인한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.textContaining('1.0.0-rc.1+42'), findsOneWidget);
    await tester.tap(find.text('최신 버전 확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    expect(find.textContaining('v1.0.0-rc.2'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  });

  testWidgets('모바일 설정 메인에서 버튼을 눌러 새 버전을 확인한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const MobileSettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('최신 버전 확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('새 버전이 있습니다'), findsOneWidget);
    expect(find.text('Play 스토어에서 보기'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
  });
}

Widget _app(Widget home) {
  return ProviderScope(
    overrides: [
      appPackageInfoProvider.overrideWith(
        (ref) => PackageInfo(
          appName: 'my_little_budget',
          packageName: 'my_little_budget',
          version: '1.0.0-rc.1',
          buildNumber: '42',
        ),
      ),
      updateCheckServiceProvider.overrideWithValue(_FakeUpdateCheckService()),
    ],
    child: MaterialApp(home: Scaffold(body: home)),
  );
}

class _FakeUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateCheckResult> check({required String currentVersion}) async {
    return UpdateCheckResult(
      status: UpdateCheckStatus.updateAvailable,
      currentVersion: Version.parse(currentVersion),
      latestRelease: GitHubAppRelease(
        version: Version.parse('1.0.0-rc.2'),
        tagName: 'v1.0.0-rc.2',
        name: 'RC 2',
        pageUrl: Uri.parse(
          'https://github.com/Flynn-Kalar/my_little_budget/releases/tag/v1.0.0-rc.2',
        ),
        prerelease: true,
      ),
    );
  }
}
