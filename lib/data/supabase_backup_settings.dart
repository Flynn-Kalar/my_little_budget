import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseBackupSettings {
  static const defaultPathPrefix = 'my_little_budget';

  const SupabaseBackupSettings({
    required this.url,
    required this.anonKey,
    required this.bucket,
    this.authEmail = '',
    this.pathPrefix = defaultPathPrefix,
    this.lastBackupAt,
    this.lastRestoreAt,
  });

  final String url;
  final String anonKey;
  final String bucket;
  final String authEmail;
  final String pathPrefix;
  final String? lastBackupAt;
  final String? lastRestoreAt;

  bool get isConfigured =>
      url.trim().isNotEmpty &&
      anonKey.trim().isNotEmpty &&
      bucket.trim().isNotEmpty;

  bool get isTableSyncConfigured =>
      url.trim().isNotEmpty &&
      anonKey.trim().isNotEmpty &&
      authEmail.trim().isNotEmpty;

  SupabaseBackupSettings normalized() {
    return SupabaseBackupSettings(
      url: normalizeProjectUrl(url),
      anonKey: anonKey.trim(),
      bucket: bucket.trim(),
      authEmail: authEmail.trim(),
      pathPrefix: _normalizePrefix(pathPrefix),
      lastBackupAt: lastBackupAt,
      lastRestoreAt: lastRestoreAt,
    );
  }

  static const empty = SupabaseBackupSettings(url: '', anonKey: '', bucket: '');

  SupabaseBackupSettings copyWith({
    String? url,
    String? anonKey,
    String? bucket,
    String? authEmail,
    String? pathPrefix,
    String? lastBackupAt,
    String? lastRestoreAt,
  }) {
    return SupabaseBackupSettings(
      url: url ?? this.url,
      anonKey: anonKey ?? this.anonKey,
      bucket: bucket ?? this.bucket,
      authEmail: authEmail ?? this.authEmail,
      pathPrefix: pathPrefix ?? this.pathPrefix,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
    );
  }

  static String _normalizePrefix(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultPathPrefix;
    return trimmed.split('/').where((part) => part.trim().isNotEmpty).join('/');
  }

  static String normalizeProjectUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

class SupabaseBackupSettingsNotifier extends Notifier<SupabaseBackupSettings> {
  static const _urlKey = 'mlb-supabase-backup-url-v1';
  static const _anonKeyKey = 'mlb-supabase-backup-anon-key-v1';
  static const _bucketKey = 'mlb-supabase-backup-bucket-v1';
  static const _authEmailKey = 'mlb-supabase-auth-email-v1';
  static const _pathPrefixKey = 'mlb-supabase-backup-path-prefix-v1';
  static const _lastBackupAtKey = 'mlb-supabase-backup-last-backup-at-v1';
  static const _lastRestoreAtKey = 'mlb-supabase-backup-last-restore-at-v1';

  final _ready = Completer<void>();

  Future<void> get whenReady => _ready.future;

  @override
  SupabaseBackupSettings build() {
    unawaited(_load());
    return SupabaseBackupSettings.empty;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = SupabaseBackupSettings(
        url: prefs.getString(_urlKey) ?? '',
        anonKey: prefs.getString(_anonKeyKey) ?? '',
        bucket: prefs.getString(_bucketKey) ?? '',
        authEmail: prefs.getString(_authEmailKey) ?? '',
        pathPrefix: SupabaseBackupSettings.defaultPathPrefix,
        lastBackupAt: prefs.getString(_lastBackupAtKey),
        lastRestoreAt: prefs.getString(_lastRestoreAtKey),
      ).normalized();
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> save(SupabaseBackupSettings settings) async {
    final normalized = settings.normalized();
    state = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, normalized.url);
    await prefs.setString(_anonKeyKey, normalized.anonKey);
    await prefs.setString(_bucketKey, normalized.bucket);
    await prefs.setString(_authEmailKey, normalized.authEmail);
    await prefs.setString(
      _pathPrefixKey,
      SupabaseBackupSettings.defaultPathPrefix,
    );
    if (normalized.lastBackupAt == null) {
      await prefs.remove(_lastBackupAtKey);
    } else {
      await prefs.setString(_lastBackupAtKey, normalized.lastBackupAt!);
    }
    if (normalized.lastRestoreAt == null) {
      await prefs.remove(_lastRestoreAtKey);
    } else {
      await prefs.setString(_lastRestoreAtKey, normalized.lastRestoreAt!);
    }
  }

  Future<void> markBackupNow({DateTime? now}) async {
    final updated = state.copyWith(
      lastBackupAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
    await save(updated);
  }

  Future<void> markRestoreNow({DateTime? now}) async {
    final updated = state.copyWith(
      lastRestoreAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
    await save(updated);
  }

  Future<void> clear() async {
    state = SupabaseBackupSettings.empty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey);
    await prefs.remove(_anonKeyKey);
    await prefs.remove(_bucketKey);
    await prefs.remove(_authEmailKey);
    await prefs.remove(_pathPrefixKey);
    await prefs.remove(_lastBackupAtKey);
    await prefs.remove(_lastRestoreAtKey);
  }
}

final supabaseBackupSettingsProvider =
    NotifierProvider<SupabaseBackupSettingsNotifier, SupabaseBackupSettings>(
      SupabaseBackupSettingsNotifier.new,
    );

String? validateSupabaseBackupSettings(SupabaseBackupSettings settings) {
  final projectError = validateSupabaseProjectSettings(settings);
  if (projectError != null) return projectError;

  final normalized = settings.normalized();
  if (normalized.bucket.isEmpty) {
    return 'Storage bucket 이름을 입력해주세요.';
  }
  return null;
}

String? validateSupabaseProjectSettings(SupabaseBackupSettings settings) {
  final normalized = settings.normalized();
  final uri = Uri.tryParse(normalized.url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Supabase URL을 확인해주세요.';
  }
  if (uri.scheme != 'https') {
    return 'Supabase URL은 https 주소여야 합니다.';
  }
  if (normalized.anonKey.isEmpty) {
    return 'anon key를 입력해주세요.';
  }
  if (_isPrivilegedSupabaseKey(normalized.anonKey)) {
    return 'service_role key는 앱에 저장하지 마세요. anon/publishable key만 입력하세요.';
  }
  return null;
}

String? validateSupabaseSyncSettings(SupabaseBackupSettings settings) {
  final normalized = settings.normalized();
  final projectError = validateSupabaseProjectSettings(normalized);
  if (projectError != null) return projectError;
  if (normalized.authEmail.isEmpty || !normalized.authEmail.contains('@')) {
    return 'Supabase Auth 이메일을 확인해주세요.';
  }
  return null;
}

/// The database sync and the JSON backup share the same Supabase project, but
/// either feature can be configured independently.
String? validateSupabaseConnectionSettings(SupabaseBackupSettings settings) {
  final normalized = settings.normalized();
  final projectError = validateSupabaseProjectSettings(normalized);
  if (projectError != null) return projectError;

  if (normalized.bucket.isNotEmpty) {
    final backupError = validateSupabaseBackupSettings(normalized);
    if (backupError != null) return backupError;
  }
  return validateSupabaseSyncSettings(normalized);
}

bool _isPrivilegedSupabaseKey(String key) {
  final normalized = key.trim();
  if (normalized.toLowerCase().contains('service_role') ||
      normalized.startsWith('sb_secret_')) {
    return true;
  }

  final parts = normalized.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(payload);
    return json is Map && json['role'] == 'service_role';
  } catch (_) {
    return false;
  }
}
