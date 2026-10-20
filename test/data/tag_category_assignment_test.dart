import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/tag_category_links.dart';

void main() {
  test(
    'assignments persist, validate, survive backup, and clear on category deletion',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final categories = await db.categoriesDao.getActiveCategories('expense');
      final ids = [categories[0].id, categories[1].id]..sort();
      final id = await db.tagsDao.createTag(
        '여행',
        '#123456',
        categoryIds: [...ids, ids.first],
      );
      await db.tagsDao.updateTag(id, '출장', '#654321');
      expect(
        readTagCategoryIds((await db.tagsDao.getTags()).single.categoryIdsJson),
        ids,
      );
      await expectLater(
        db.tagsDao.updateTag(id, '출장', '#654321', categoryIds: [-1]),
        throwsArgumentError,
      );
      final backup = await db.backupDao.exportBackup();
      final parsed = parseBackup(backup.toJsonString());
      expect(parsed.isOk, isTrue, reason: parsed.error);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.backupDao.importBackup(parsed.backup!);
      expect(
        readTagCategoryIds(
          (await target.tagsDao.getTags()).single.categoryIdsJson,
        ),
        ids,
      );
      expect(await target.categoriesDao.deleteCategory(ids.first), isNull);
      expect(
        readTagCategoryIds(
          (await target.tagsDao.getTags()).single.categoryIdsJson,
        ),
        [ids.last],
      );
      final json = backup.toJson();
      final tag = (json['data'] as Map)['tags'][0] as Map;
      tag.remove('categoryIdsJson');
      expect(
        parseBackup(jsonEncode(json)).backup!.tags.single.categoryIdsJson,
        '[]',
      );
      tag['categoryIdsJson'] = '["bad"]';
      expect(parseBackup(jsonEncode(json)).isOk, isFalse);
    },
  );

  test('v22 migration adds assignments without changing existing tags', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(
            '''CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT UNIQUE, name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL DEFAULT '#64748b', sort_order INTEGER NOT NULL DEFAULT 0,
        usage_count INTEGER NOT NULL DEFAULT 0, last_used_at TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL, deleted_at TEXT, sync_status TEXT NOT NULL DEFAULT 'pending')''',
          );
          raw.execute(
            "INSERT INTO tags (uuid,name,color,created_at,updated_at) VALUES ('old','기존','#123456','2026-10-01','2026-10-01')",
          );
          raw.execute('PRAGMA user_version = 22');
        },
      ),
    );
    addTearDown(db.close);
    final tag = (await db.tagsDao.getTags()).single;
    expect(tag.name, '기존');
    expect(tag.color, '#123456');
    expect(tag.categoryIdsJson, '[]');
  });
}
