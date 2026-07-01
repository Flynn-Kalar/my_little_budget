import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseBackupSettings {
  const SupabaseBackupSettings({
    required this.url,
    required this.anonKey,
    required this.bucket,
    this.pathPrefix = 'my_little_budget',
    this.lastBackupAt,
    this.lastRestoreAt,
  });

  final String url;
  final String anonKey;
  final String bucket;
  final String pathPrefix;
  final String? lastBackupAt;
  final String? lastRestoreAt;

  bool get isConfigured =>
      url.trim().isNotEmpty &&
      anonKey.trim().isNotEmpty &&
      bucket.trim().isNotEmpty;

  SupabaseBackupSettings normalized() {
    return SupabaseBackupSettings(
      url: url.trim(),
      anonKey: anonKey.trim(),
      bucket: bucket.trim(),
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
    String? pathPrefix,
    String? lastBackupAt,
    String? lastRestoreAt,
  }) {
    return SupabaseBackupSettings(
      url: url ?? this.url,
      anonKey: anonKey ?? this.anonKey,
      bucket: bucket ?? this.bucket,
      pathPrefix: pathPrefix ?? this.pathPrefix,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
    );
  }

  static String _normalizePrefix(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'my_little_budget';
    return trimmed.split('/').where((part) => part.trim().isNotEmpty).join('/');
  }
}

class SupabaseBackupSettingsNotifier extends Notifier<SupabaseBackupSettings> {
  static const _urlKey = 'mlb-supabase-backup-url-v1';
  static const _anonKeyKey = 'mlb-supabase-backup-anon-key-v1';
  static const _bucketKey = 'mlb-supabase-backup-bucket-v1';
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
        pathPrefix: prefs.getString(_pathPrefixKey) ?? 'my_little_budget',
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
    await prefs.setString(_pathPrefixKey, normalized.pathPrefix);
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
  if (normalized.anonKey.toLowerCase().contains('service_role')) {
    return 'service_role key는 앱에 저장하지 마세요. anon/publishable key만 입력하세요.';
  }
  return null;
}
