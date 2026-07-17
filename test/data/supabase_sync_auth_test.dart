// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_sync_auth.dart';
import 'package:supabase/supabase.dart';

const _settings = SupabaseBackupSettings(
  url: 'https://example.supabase.co',
  anonKey: 'publishable-key',
  bucket: '',
  authEmail: 'user@example.com',
);

void main() {
  test('signs in with email and stores the session user id', () async {
    var signInCount = 0;
    final tokenStore = _FakeTokenStore();
    final service = SupabaseSyncAuthService(
      tokenStore: tokenStore,
      clientFactory: (url, anonKey) => SupabaseClient(
        url,
        anonKey,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/token');
          expect(request.url.queryParameters['grant_type'], 'password');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'user@example.com');
          expect(body['password'], 'correct-password');
          signInCount++;
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'email-user', email: 'user@example.com'),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(service.dispose);

    final client = await service.signInWithPassword(
      _settings,
      email: 'user@example.com',
      password: 'correct-password',
    );

    expect(client.auth.currentUser?.isAnonymous, isFalse);
    expect(client.auth.currentUser?.email, 'user@example.com');
    expect(signInCount, 1);
    expect(tokenStore.session?.projectUrl, _settings.url);
    expect(tokenStore.session?.userId, 'email-user');
    expect(tokenStore.session?.refreshToken, 'refresh-token');
  });

  test('restore requires a previously stored email session', () async {
    final service = SupabaseSyncAuthService(tokenStore: _FakeTokenStore());
    addTearDown(service.dispose);

    await expectLater(
      service.restoreClient(_settings),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('이메일'),
        ),
      ),
    );
  });

  test('restores only the stored email user id', () async {
    final tokenStore = _FakeTokenStore()
      ..session = const SupabaseStoredSession(
        projectUrl: 'https://example.supabase.co',
        userId: 'expected-user',
        refreshToken: 'refresh-token',
      );
    final service = SupabaseSyncAuthService(
      tokenStore: tokenStore,
      clientFactory: (url, anonKey) => SupabaseClient(
        url,
        anonKey,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/token');
          expect(request.url.queryParameters['grant_type'], 'refresh_token');
          return http.Response(
            jsonEncode(
              _sessionJson(userId: 'different-user', email: 'user@example.com'),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.restoreClient(_settings),
      throwsA(isA<AuthException>()),
    );
    expect(tokenStore.session?.userId, 'expected-user');
  });

  test('rejects an anonymous response for email sign-in', () async {
    final tokenStore = _FakeTokenStore();
    final service = SupabaseSyncAuthService(
      tokenStore: tokenStore,
      clientFactory: (url, anonKey) => SupabaseClient(
        url,
        anonKey,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode(
              _sessionJson(
                userId: 'anonymous-user',
                email: null,
                isAnonymous: true,
              ),
            ),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.signInWithPassword(
        _settings,
        email: 'user@example.com',
        password: 'correct-password',
      ),
      throwsA(isA<AuthException>()),
    );
    expect(tokenStore.session, isNull);
  });
}

Map<String, Object?> _sessionJson({
  required String userId,
  required String? email,
  bool isAnonymous = false,
}) {
  final expiresAt = DateTime.now().add(const Duration(hours: 1));
  final accessToken = [
    _base64UrlJson(const {'alg': 'none', 'typ': 'JWT'}),
    _base64UrlJson({'exp': expiresAt.millisecondsSinceEpoch ~/ 1000}),
    'signature',
  ].join('.');
  return {
    'access_token': accessToken,
    'refresh_token': 'refresh-token',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'app_metadata': const <String, Object?>{},
      'user_metadata': const <String, Object?>{},
      'aud': 'authenticated',
      'email': email,
      'is_anonymous': isAnonymous,
      'created_at': '2026-01-01T00:00:00.000Z',
    },
  };
}

String _base64UrlJson(Map<String, Object?> value) {
  return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
}

class _FakeTokenStore implements SupabaseSyncTokenStore {
  SupabaseStoredSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<SupabaseStoredSession?> read() async => session;

  @override
  Future<void> write(SupabaseStoredSession session) async {
    this.session = session;
  }
}
