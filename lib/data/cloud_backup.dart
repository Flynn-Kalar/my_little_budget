import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

const googleDriveBackupMimeType = 'application/json';

final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  return GoogleDriveBackupService();
});

class CloudBackupAccount {
  const CloudBackupAccount({required this.email, this.displayName});

  final String email;
  final String? displayName;
}

class CloudBackupFile {
  const CloudBackupFile({
    required this.id,
    required this.name,
    this.modifiedAt,
  });

  final String id;
  final String name;
  final DateTime? modifiedAt;
}

class CloudBackupResult<T> {
  const CloudBackupResult.ok(this.value) : error = null;
  const CloudBackupResult.fail(String this.error) : value = null;

  final T? value;
  final String? error;

  bool get isOk => error == null;
}

abstract class CloudBackupService {
  bool get isSupported;

  Future<CloudBackupAccount?> currentAccount();
  Future<CloudBackupAccount?> signIn();
  Future<void> signOut();
  Future<CloudBackupResult<CloudBackupFile>> uploadBackup({
    required String filename,
    required String json,
  });
  Future<CloudBackupResult<List<CloudBackupFile>>> listBackups();
  Future<CloudBackupResult<String>> downloadBackup(CloudBackupFile file);
}

class GoogleDriveBackupService implements CloudBackupService {
  GoogleDriveBackupService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(scopes: const [drive.DriveApi.driveAppdataScope]);

  final GoogleSignIn _googleSignIn;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<CloudBackupAccount?> currentAccount() async {
    if (!isSupported) return null;
    final account = await _googleSignIn.signInSilently();
    return _toAccount(account);
  }

  @override
  Future<CloudBackupAccount?> signIn() async {
    if (!isSupported) return null;
    final account = await _googleSignIn.signIn();
    return _toAccount(account);
  }

  @override
  Future<void> signOut() async {
    if (!isSupported) return;
    await _googleSignIn.signOut();
  }

  @override
  Future<CloudBackupResult<CloudBackupFile>> uploadBackup({
    required String filename,
    required String json,
  }) async {
    if (!isSupported) {
      return const CloudBackupResult.fail(
        'Google Drive backup is only available on Android.',
      );
    }

    try {
      final api = await _driveApi();
      if (api == null) {
        return const CloudBackupResult.fail(
          'Google account sign-in was cancelled.',
        );
      }

      final media = drive.Media(
        Stream<List<int>>.value(utf8.encode(json)),
        utf8.encode(json).length,
        contentType: googleDriveBackupMimeType,
      );
      final metadata = drive.File()
        ..name = filename
        ..mimeType = googleDriveBackupMimeType
        ..parents = const ['appDataFolder'];

      final created = await api.files.create(
        metadata,
        uploadMedia: media,
        $fields: 'id,name,modifiedTime',
      );
      final id = created.id;
      if (id == null || id.isEmpty) {
        return const CloudBackupResult.fail(
          'Google Drive did not return a backup file id.',
        );
      }
      return CloudBackupResult.ok(_toFile(created));
    } catch (e) {
      return CloudBackupResult.fail('Google Drive backup upload failed: $e');
    }
  }

  @override
  Future<CloudBackupResult<List<CloudBackupFile>>> listBackups() async {
    if (!isSupported) {
      return const CloudBackupResult.fail(
        'Google Drive backup is only available on Android.',
      );
    }

    try {
      final api = await _driveApi();
      if (api == null) {
        return const CloudBackupResult.fail(
          'Google account sign-in was cancelled.',
        );
      }

      final result = await api.files.list(
        spaces: 'appDataFolder',
        q:
            "mimeType = '$googleDriveBackupMimeType' and "
            "name contains 'my_little_budget-backup-' and trashed = false",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name,modifiedTime)',
      );
      final files = result.files?.map(_toFile).toList() ?? const [];
      return CloudBackupResult.ok(files);
    } catch (e) {
      return CloudBackupResult.fail('Google Drive backup list failed: $e');
    }
  }

  @override
  Future<CloudBackupResult<String>> downloadBackup(CloudBackupFile file) async {
    if (!isSupported) {
      return const CloudBackupResult.fail(
        'Google Drive backup is only available on Android.',
      );
    }

    try {
      final api = await _driveApi();
      if (api == null) {
        return const CloudBackupResult.fail(
          'Google account sign-in was cancelled.',
        );
      }

      final media = await api.files.get(
        file.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );
      if (media is! drive.Media) {
        return const CloudBackupResult.fail(
          'Google Drive did not return backup content.',
        );
      }

      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }
      return CloudBackupResult.ok(utf8.decode(chunks));
    } catch (e) {
      return CloudBackupResult.fail('Google Drive backup download failed: $e');
    }
  }

  Future<drive.DriveApi?> _driveApi() async {
    var account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    if (account == null) return null;

    final headers = await account.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  static CloudBackupAccount? _toAccount(GoogleSignInAccount? account) {
    if (account == null) return null;
    return CloudBackupAccount(
      email: account.email,
      displayName: account.displayName,
    );
  }

  static CloudBackupFile _toFile(drive.File file) {
    return CloudBackupFile(
      id: file.id ?? '',
      name: file.name ?? 'Google Drive backup',
      modifiedAt: file.modifiedTime,
    );
  }
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
