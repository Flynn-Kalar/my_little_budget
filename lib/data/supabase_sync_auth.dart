import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase/supabase.dart';

import 'supabase_backup_settings.dart';

typedef SupabaseSyncClientFactory =
    SupabaseClient Function(String projectUrl, String anonKey);

final supabaseSyncTokenStoreProvider = Provider<SupabaseSyncTokenStore>((ref) {
  return SecureSupabaseSyncTokenStore();
});

final supabaseSyncAuthServiceProvider = Provider<SupabaseSyncAuthService>((
  ref,
) {
  final service = SupabaseSyncAuthService(
    tokenStore: ref.watch(supabaseSyncTokenStoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

abstract class SupabaseSyncTokenStore {
  Future<SupabaseStoredSession?> read();
  Future<void> write(SupabaseStoredSession session);
  Future<void> clear();
}

class SupabaseStoredSession {
  const SupabaseStoredSession({
    required this.projectUrl,
    required this.userId,
    required this.refreshToken,
  });

  final String projectUrl;
  final String userId;
  final String refreshToken;
}

class SecureSupabaseSyncTokenStore implements SupabaseSyncTokenStore {
  SecureSupabaseSyncTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  static const _sessionKey = 'mlb_supabase_sync_session_v2';
  static const _projectKey = 'mlb_supabase_sync_project_v1';
  static const _userIdKey = 'mlb_supabase_sync_user_id_v1';
  static const _refreshTokenKey = 'mlb_supabase_sync_refresh_token_v1';
  static const _legacyEmailKey = 'mlb_supabase_sync_email_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<SupabaseStoredSession?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final value = jsonDecode(encoded);
        if (value is Map) {
          final projectUrl = value['projectUrl'];
          final userId = value['userId'];
          final refreshToken = value['refreshToken'];
          if (projectUrl is String &&
              projectUrl.isNotEmpty &&
              userId is String &&
              userId.isNotEmpty &&
              refreshToken is String &&
              refreshToken.isNotEmpty) {
            return SupabaseStoredSession(
              projectUrl: projectUrl,
              userId: userId,
              refreshToken: refreshToken,
            );
          }
        }
      } catch (_) {
        // Fall back to the v1 fields so a damaged upgrade remains recoverable.
      }
    }

    // v1 wrote these fields concurrently. Whole-file secure-storage backends
    // could lose one field, most commonly the project URL. The refresh token
    // can still be validated against the configured project during restore.
    final projectUrl = await _storage.read(key: _projectKey) ?? '';
    final userId = await _storage.read(key: _userIdKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (userId == null ||
        userId.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return SupabaseStoredSession(
      projectUrl: projectUrl,
      userId: userId,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> write(SupabaseStoredSession session) async {
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'projectUrl': session.projectUrl,
        'userId': session.userId,
        'refreshToken': session.refreshToken,
      }),
    );
    await _storage.delete(key: _projectKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacyEmailKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _projectKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacyEmailKey);
  }
}

/// Maintains the user's Supabase email Auth identity.
///
/// The password is used only for the sign-in request and is never persisted.
/// The refresh token is kept in secure storage so later app launches can restore
/// the same RLS owner without asking for the password again.
class SupabaseSyncAuthService {
  SupabaseSyncAuthService({
    required SupabaseSyncTokenStore tokenStore,
    SupabaseSyncClientFactory? clientFactory,
  }) : _tokenStore = tokenStore,
       _clientFactory =
           clientFactory ?? ((url, anonKey) => SupabaseClient(url, anonKey));

  final SupabaseSyncTokenStore _tokenStore;
  final SupabaseSyncClientFactory _clientFactory;
  SupabaseClient? _client;
  String? _projectFingerprint;
  String? _userId;
  StreamSubscription<AuthState>? _authSubscription;

  Future<SupabaseClient> signInWithPassword(
    SupabaseBackupSettings settings, {
    required String email,
    required String password,
  }) async {
    final normalized = _validated(settings);
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const AuthException('Supabase Auth 이메일을 확인해주세요.');
    }
    if (password.isEmpty) {
      throw const AuthException('Supabase Auth 비밀번호를 입력해주세요.');
    }

    final client = await _replaceClient(normalized);
    try {
      final response = await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: password,
      );
      final session = _requireEmailSession(response.session);
      _bindIdentity(normalized, session.user.id);
      await _persistSession(normalized.url, session);
      return client;
    } catch (_) {
      await _disposeClient();
      rethrow;
    }
  }

  Future<SupabaseClient> restoreClient(SupabaseBackupSettings settings) async {
    final normalized = _validated(settings);
    final current = _matchingClient(normalized);
    if (current != null) return current;

    final stored = await _tokenStore.read();
    if (stored == null ||
        (stored.projectUrl.isNotEmpty && stored.projectUrl != normalized.url)) {
      throw const AuthException(
        'Supabase 이메일 로그인 세션이 없습니다. 이메일과 비밀번호를 입력한 뒤 설정 저장을 눌러주세요.',
      );
    }
    return _restoreStored(normalized, stored);
  }

  Future<SupabaseClient> _restoreStored(
    SupabaseBackupSettings settings,
    SupabaseStoredSession stored,
  ) async {
    final client = await _replaceClient(settings);
    try {
      final response = await client.auth.setSession(stored.refreshToken);
      final session = _requireEmailSession(response.session);
      if (session.user.id != stored.userId) {
        throw const AuthException('저장된 Supabase 사용자와 복구된 사용자가 다릅니다.');
      }
      _bindIdentity(settings, stored.userId);
      await _persistSession(settings.url, session);
      return client;
    } catch (_) {
      await _disposeClient();
      rethrow;
    }
  }

  SupabaseBackupSettings _validated(SupabaseBackupSettings settings) {
    final error = validateSupabaseSyncSettings(settings);
    if (error != null) throw StateError(error);
    return settings.normalized();
  }

  SupabaseClient? _matchingClient(SupabaseBackupSettings settings) {
    final client = _client;
    final session = client?.auth.currentSession;
    final user = session?.user;
    if (client == null || user == null || user.isAnonymous) return null;
    if (_userId != user.id ||
        _projectFingerprint != _fingerprint(settings, user.id)) {
      return null;
    }
    return client;
  }

  Session _requireEmailSession(Session? session) {
    if (session?.refreshToken == null || session!.refreshToken!.isEmpty) {
      throw const AuthException('Supabase 이메일 로그인 세션을 만들지 못했습니다.');
    }
    if (session.user.isAnonymous || (session.user.email ?? '').isEmpty) {
      throw const AuthException('Supabase 이메일 사용자 세션이 아닙니다.');
    }
    return session;
  }

  void _bindIdentity(SupabaseBackupSettings settings, String userId) {
    _userId = userId;
    _projectFingerprint = _fingerprint(settings, userId);
  }

  Future<SupabaseClient> _replaceClient(SupabaseBackupSettings settings) async {
    await _disposeClient();
    final client = _clientFactory(settings.url, settings.anonKey);
    _client = client;
    _authSubscription = client.auth.onAuthStateChange.listen((event) {
      final session = event.session;
      final userId = _userId;
      if (session?.refreshToken == null ||
          userId == null ||
          session!.user.id != userId ||
          session.user.isAnonymous) {
        return;
      }
      unawaited(_persistSession(settings.url, session));
    });
    return client;
  }

  Future<void> _persistSession(String projectUrl, Session session) {
    return _tokenStore.write(
      SupabaseStoredSession(
        projectUrl: projectUrl,
        userId: session.user.id,
        refreshToken: session.refreshToken!,
      ),
    );
  }

  String _fingerprint(SupabaseBackupSettings settings, String userId) {
    return '${settings.url}\n${settings.anonKey}\n$userId';
  }

  Future<void> disconnect() async {
    await _disposeClient();
    await _tokenStore.clear();
  }

  Future<void> _disposeClient() async {
    final client = _client;
    _client = null;
    _projectFingerprint = null;
    _userId = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
    await client?.dispose();
  }

  Future<void> dispose() => _disposeClient();
}
