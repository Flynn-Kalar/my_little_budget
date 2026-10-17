import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_little_budget/features/settings/update_check.dart';
import 'package:my_little_budget/features/settings/windows_update_installer.dart';

void main() {
  test('Setup을 다운로드하고 SHA-256 검증 후 자동 설치 옵션으로 실행한다', () async {
    final bytes = utf8.encode('verified installer');
    final tempDirectory = await Directory.systemTemp.createTemp(
      'my_little_budget_update_test_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    String? launchedExecutable;
    List<String>? launchedArguments;
    int? exitCode;
    final progress = <double>[];
    final installer = WindowsUpdateInstaller(
      client: MockClient(
        (_) async => http.Response.bytes(
          bytes,
          HttpStatus.ok,
          headers: {'content-type': 'application/octet-stream'},
        ),
      ),
      temporaryDirectoryProvider: () async => tempDirectory,
      launcher: (executable, arguments) async {
        launchedExecutable = executable;
        launchedArguments = arguments;
      },
      exitApp: (code) => exitCode = code,
      isWindows: true,
    );

    await installer.install(
      GitHubReleaseAsset(
        name: 'MyLittleBudget-Setup-1.0.0-rc.2.exe',
        downloadUrl: Uri.parse(
          'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-Setup-1.0.0-rc.2.exe',
        ),
        size: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
      onProgress: progress.add,
    );

    expect(launchedExecutable, endsWith('MyLittleBudget-Setup-1.0.0-rc.2.exe'));
    expect(launchedArguments, [
      '/SP-',
      '/SILENT',
      '/CLOSEAPPLICATIONS',
      '/NORESTART',
    ]);
    expect(exitCode, 0);
    expect(progress.last, 1);
  });

  test('SHA-256이 다르면 Setup을 실행하지 않는다', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'my_little_budget_update_test_',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    var launched = false;
    final installer = WindowsUpdateInstaller(
      client: MockClient((_) async => http.Response('tampered', HttpStatus.ok)),
      temporaryDirectoryProvider: () async => tempDirectory,
      launcher: (_, _) async => launched = true,
      exitApp: (_) {},
      isWindows: true,
    );

    await expectLater(
      () => installer.install(
        GitHubReleaseAsset(
          name: 'MyLittleBudget-Setup-1.0.0-rc.2.exe',
          downloadUrl: Uri.parse(
            'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-Setup-1.0.0-rc.2.exe',
          ),
          size: utf8.encode('tampered').length,
          sha256:
              '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      ),
      throwsA(isA<WindowsUpdateException>()),
    );
    expect(launched, isFalse);
  });

  test('다운로드 크기가 다르면 설치와 앱 종료를 하지 않는다', () async {
    final bytes = utf8.encode('truncated installer');
    final directory = await Directory.systemTemp.createTemp(
      'update_size_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    var launched = false;
    var exited = false;
    final installer = WindowsUpdateInstaller(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      temporaryDirectoryProvider: () async => directory,
      launcher: (_, _) async => launched = true,
      exitApp: (_) => exited = true,
      isWindows: true,
    );
    final asset = _asset(bytes, size: bytes.length + 1);
    await expectLater(
      installer.install(asset),
      throwsA(isA<WindowsUpdateException>()),
    );
    expect(launched, isFalse);
    expect(exited, isFalse);
    expect(
      await directory
          .list(recursive: true)
          .where((entry) => entry.path.endsWith('.exe'))
          .isEmpty,
      isTrue,
    );
  });

  test('설치 프로그램 실행 실패 시 앱을 종료하지 않는다', () async {
    final bytes = utf8.encode('valid installer');
    final directory = await Directory.systemTemp.createTemp(
      'update_launch_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    var exited = false;
    final installer = WindowsUpdateInstaller(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      temporaryDirectoryProvider: () async => directory,
      launcher: (_, _) async =>
          throw const ProcessException('setup.exe', [], 'launch failed'),
      exitApp: (_) => exited = true,
      isWindows: true,
    );
    await expectLater(
      installer.install(_asset(bytes)),
      throwsA(isA<WindowsUpdateException>()),
    );
    expect(exited, isFalse);
    expect(
      await directory
          .list(recursive: true)
          .where((entry) => entry.path.endsWith('.exe'))
          .isEmpty,
      isTrue,
    );
  });

  test('경로를 포함한 파일명은 다운로드 전에 거부한다', () async {
    var requested = false;
    final installer = WindowsUpdateInstaller(
      client: MockClient((_) async {
        requested = true;
        return http.Response('unexpected', 200);
      }),
      exitApp: (_) => fail('must not exit'),
      isWindows: true,
    );
    await expectLater(
      installer.install(
        GitHubReleaseAsset(
          name: '../outside.exe',
          downloadUrl: Uri.parse(
            'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/outside.exe',
          ),
          size: 1,
          sha256: 'a' * 64,
        ),
      ),
      throwsA(isA<WindowsUpdateException>()),
    );
    expect(requested, isFalse);
  });

  test('Update.exe도 검증 후 업데이트 옵션으로 실행한다', () async {
    final bytes = utf8.encode('verified update package');
    final directory = await Directory.systemTemp.createTemp(
      'update_asset_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    String? launched;
    var exited = false;
    final installer = WindowsUpdateInstaller(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
      temporaryDirectoryProvider: () async => directory,
      launcher: (file, args) async {
        launched = file;
        expect(args, contains('/SILENT'));
      },
      exitApp: (_) => exited = true,
      isWindows: true,
    );
    await installer.install(
      GitHubReleaseAsset(
        name: 'MyLittleBudget-Update-1.0.0-rc.2.exe',
        downloadUrl: Uri.parse(
          'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-Update-1.0.0-rc.2.exe',
        ),
        size: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    );
    expect(launched, endsWith('MyLittleBudget-Update-1.0.0-rc.2.exe'));
    expect(exited, isTrue);
  });
}

GitHubReleaseAsset _asset(List<int> bytes, {int? size}) => GitHubReleaseAsset(
  name: 'MyLittleBudget-Setup-1.0.0-rc.2.exe',
  downloadUrl: Uri.parse(
    'https://github.com/Flynn-Kalar/my_little_budget/releases/download/v1.0.0-rc.2/MyLittleBudget-Setup-1.0.0-rc.2.exe',
  ),
  size: size ?? bytes.length,
  sha256: sha256.convert(bytes).toString(),
);
