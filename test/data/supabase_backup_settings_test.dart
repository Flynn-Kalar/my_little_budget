import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';

void main() {
  group('SupabaseBackupSettings', () {
    test('normalizes whitespace and path prefix', () {
      final settings = const SupabaseBackupSettings(
        url: ' https://example.supabase.co ',
        anonKey: ' key ',
        bucket: ' backups ',
        pathPrefix: '/my_little_budget//device/',
      ).normalized();

      expect(settings.url, 'https://example.supabase.co');
      expect(settings.anonKey, 'key');
      expect(settings.bucket, 'backups');
      expect(settings.pathPrefix, 'my_little_budget/device');
    });

    test('validates required fields and https URL', () {
      expect(
        validateSupabaseBackupSettings(SupabaseBackupSettings.empty),
        isNotNull,
      );
      expect(
        validateSupabaseBackupSettings(
          const SupabaseBackupSettings(
            url: 'http://example.supabase.co',
            anonKey: 'anon',
            bucket: 'backups',
          ),
        ),
        contains('https'),
      );
      expect(
        validateSupabaseBackupSettings(
          const SupabaseBackupSettings(
            url: 'https://example.supabase.co',
            anonKey: 'anon',
            bucket: 'backups',
          ),
        ),
        isNull,
      );
    });

    test('rejects service role key text', () {
      expect(
        validateSupabaseBackupSettings(
          const SupabaseBackupSettings(
            url: 'https://example.supabase.co',
            anonKey: 'service_role_secret',
            bucket: 'backups',
          ),
        ),
        contains('service_role'),
      );
    });

    test('copyWith can store last backup and restore timestamps', () {
      final settings =
          const SupabaseBackupSettings(
            url: 'https://example.supabase.co',
            anonKey: 'anon',
            bucket: 'backups',
          ).copyWith(
            lastBackupAt: '2026-06-17T00:00:00Z',
            lastRestoreAt: '2026-06-18T00:00:00Z',
          );

      expect(settings.lastBackupAt, '2026-06-17T00:00:00Z');
      expect(settings.lastRestoreAt, '2026-06-18T00:00:00Z');
    });
  });
}
