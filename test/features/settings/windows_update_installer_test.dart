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
}
