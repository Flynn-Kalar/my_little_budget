import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

const _releasesApiUrl =
    'https://api.github.com/repos/Flynn-Kalar/my_little_budget/releases?per_page=30';

final appPackageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

final updateCheckServiceProvider = Provider<UpdateCheckService>(
  (ref) => UpdateCheckService(),
);

enum UpdateCheckStatus { updateAvailable, upToDate, noRelease }

class GitHubAppRelease {
  const GitHubAppRelease({
    required this.version,
    required this.tagName,
    required this.name,
    required this.pageUrl,
    required this.prerelease,
    this.windowsInstaller,
  });

  final Version version;
  final String tagName;
  final String name;
  final Uri pageUrl;
  final bool prerelease;
  final GitHubReleaseAsset? windowsInstaller;
}

class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.sha256,
  });

  final String name;
  final Uri downloadUrl;
  final int size;
  final String? sha256;
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.latestRelease,
  });

  final UpdateCheckStatus status;
  final Version currentVersion;
  final GitHubAppRelease? latestRelease;
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateCheckService {
  UpdateCheckService({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _client = client;

  final http.Client? _client;
  final Duration requestTimeout;

  Future<UpdateCheckResult> check({required String currentVersion}) async {
    final installed = _parseVersion(currentVersion);
    if (installed == null) {
      throw const UpdateCheckException('현재 앱 버전을 확인할 수 없습니다.');
    }

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse(_releasesApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'my_little_budget-update-checker',
            },
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw UpdateCheckException(
          'GitHub에서 버전 정보를 가져오지 못했습니다. (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const UpdateCheckException('GitHub 응답 형식이 올바르지 않습니다.');
      }

      final releases =
          decoded
              .whereType<Map<String, dynamic>>()
              .map(_releaseFromJson)
              .whereType<GitHubAppRelease>()
              .toList()
            ..sort((a, b) => b.version.compareTo(a.version));

      if (releases.isEmpty) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.noRelease,
          currentVersion: installed,
        );
      }

      final latest = releases.first;
      return UpdateCheckResult(
        status: latest.version > installed
            ? UpdateCheckStatus.updateAvailable
            : UpdateCheckStatus.upToDate,
        currentVersion: installed,
        latestRelease: latest,
      );
    } on TimeoutException {
      throw const UpdateCheckException('GitHub 연결 시간이 초과되었습니다.');
    } on http.ClientException {
      throw const UpdateCheckException('GitHub에 연결할 수 없습니다.');
    } on FormatException {
      throw const UpdateCheckException('GitHub 응답을 해석할 수 없습니다.');
    } finally {
      if (_client == null) client.close();
    }
  }
}

GitHubAppRelease? _releaseFromJson(Map<String, dynamic> json) {
  if (json['draft'] == true) return null;
  final tagName = json['tag_name'] as String?;
  final pageUrl = Uri.tryParse(json['html_url'] as String? ?? '');
  final version = _parseVersion(tagName);
  if (tagName == null || version == null || pageUrl == null) return null;
  final rawName = (json['name'] as String?)?.trim();
  return GitHubAppRelease(
    version: version,
    tagName: tagName,
    name: rawName == null || rawName.isEmpty ? tagName : rawName,
    pageUrl: pageUrl,
    prerelease: json['prerelease'] == true,
    windowsInstaller: _windowsInstallerFromJson(json['assets'], tagName),
  );
}

GitHubReleaseAsset? _windowsInstallerFromJson(
  Object? rawAssets,
  String tagName,
) {
  if (rawAssets is! List) return null;
  final versionLabel = tagName.replaceFirst(RegExp(r'^[vV]'), '');
  final expectedName = 'MyLittleBudget-Setup-$versionLabel.exe';
  for (final rawAsset in rawAssets.whereType<Map<String, dynamic>>()) {
    final name = rawAsset['name'] as String?;
    final downloadUrl = Uri.tryParse(
      rawAsset['browser_download_url'] as String? ?? '',
    );
    if (name == null ||
        name.toLowerCase() != expectedName.toLowerCase() ||
        downloadUrl == null ||
        downloadUrl.scheme != 'https' ||
        downloadUrl.host != 'github.com') {
      continue;
    }
    final digest = rawAsset['digest'] as String?;
    final sha256 = digest?.startsWith('sha256:') == true
        ? digest!.substring('sha256:'.length).toLowerCase()
        : null;
    return GitHubReleaseAsset(
      name: name,
      downloadUrl: downloadUrl,
      size: (rawAsset['size'] as num?)?.toInt() ?? 0,
      sha256: sha256,
    );
  }
  return null;
}

Version? _parseVersion(String? raw) {
  if (raw == null) return null;
  final normalized = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
  try {
    return Version.parse(normalized);
  } on FormatException {
    return null;
  }
}

String packageVersionLabel(PackageInfo info) {
  final build = info.buildNumber.trim();
  return build.isEmpty ? info.version : '${info.version}+$build';
}
