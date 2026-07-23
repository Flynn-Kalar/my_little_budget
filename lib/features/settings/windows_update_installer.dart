import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'update_check.dart';

final windowsUpdateInstallerProvider = Provider<WindowsUpdateInstaller>(
  (ref) => WindowsUpdateInstaller(),
);

typedef UpdateProgressCallback = void Function(double progress);
typedef InstallerLauncher =
    Future<void> Function(String executable, List<String> arguments);
typedef AppExitCallback = void Function(int code);
typedef TemporaryDirectoryProvider = Future<Directory> Function();

class WindowsUpdateException implements Exception {
  const WindowsUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WindowsUpdateInstaller {
  WindowsUpdateInstaller({
    http.Client? client,
    TemporaryDirectoryProvider? temporaryDirectoryProvider,
    InstallerLauncher? launcher,
    AppExitCallback? exitApp,
    bool? isWindows,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _launcher = launcher ?? _launchInstaller,
       _exitApp = exitApp ?? exit,
       _isWindows = isWindows ?? Platform.isWindows;

  final http.Client? _client;
  final TemporaryDirectoryProvider _temporaryDirectoryProvider;
  final InstallerLauncher _launcher;
  final AppExitCallback _exitApp;
  final bool _isWindows;
  final Duration requestTimeout;

  Future<void> install(
    GitHubReleaseAsset asset, {
    UpdateProgressCallback? onProgress,
  }) async {
    if (!_isWindows) {
      throw const WindowsUpdateException('Windows에서만 자동 업데이트할 수 있습니다.');
    }
    final expectedDigest = asset.sha256;
    if (expectedDigest == null ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedDigest)) {
      throw const WindowsUpdateException(
        'Setup 파일의 SHA-256 검증값이 없어 업데이트를 중단했습니다.',
      );
    }

    final client = _client ?? http.Client();
    File? installer;
    try {
      final tempRoot = await _temporaryDirectoryProvider();
      final updateDir = Directory.fromUri(
        tempRoot.uri.resolve('my_little_budget_updates/'),
      );
      await updateDir.create(recursive: true);
      installer = File.fromUri(updateDir.uri.resolve(asset.name));
      if (await installer.exists()) await installer.delete();

      final request = http.Request('GET', asset.downloadUrl)
        ..headers.addAll(const {
          'Accept': 'application/octet-stream',
          'User-Agent': 'my_little_budget-windows-updater',
        });
      final response = await client.send(request).timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw WindowsUpdateException(
          'Setup 파일을 다운로드하지 못했습니다. (${response.statusCode})',
        );
      }

      final totalBytes = asset.size > 0
          ? asset.size
          : response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = installer.openWrite();
      try {
        await for (final chunk in response.stream.timeout(requestTimeout)) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call((receivedBytes / totalBytes).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (asset.size > 0 && receivedBytes != asset.size) {
        throw const WindowsUpdateException('Setup 파일의 크기가 릴리스 정보와 일치하지 않습니다.');
      }
      final actualDigest = (await sha256.bind(installer.openRead()).first)
          .toString()
          .toLowerCase();
      if (actualDigest != expectedDigest) {
        throw const WindowsUpdateException(
          'Setup 파일의 SHA-256 검증에 실패해 업데이트를 중단했습니다.',
        );
      }

      onProgress?.call(1);
      await _launcher(installer.path, const [
        '/SP-',
        '/SILENT',
        '/CLOSEAPPLICATIONS',
        '/NORESTART',
      ]);
      _exitApp(0);
    } on WindowsUpdateException {
      await _deleteIfExists(installer);
      rethrow;
    } on TimeoutException {
      await _deleteIfExists(installer);
      throw const WindowsUpdateException('Setup 파일 다운로드 시간이 초과되었습니다.');
    } on http.ClientException {
      await _deleteIfExists(installer);
      throw const WindowsUpdateException('Setup 파일을 다운로드할 수 없습니다.');
    } on ProcessException {
      await _deleteIfExists(installer);
      throw const WindowsUpdateException('Setup 파일을 실행할 수 없습니다.');
    } on FileSystemException {
      await _deleteIfExists(installer);
      throw const WindowsUpdateException('Setup 파일을 저장하거나 실행할 수 없습니다.');
    } finally {
      if (_client == null) client.close();
    }
  }

  static Future<void> _deleteIfExists(File? file) async {
    if (file != null && await file.exists()) await file.delete();
  }

  static Future<void> _launchInstaller(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}
