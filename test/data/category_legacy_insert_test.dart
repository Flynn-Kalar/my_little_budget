import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/categories/validation.dart';

AppDatabase legacyDatabase({bool withExistingRows = false}) {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (raw) {
        // v3 added updated_at without a SQL default to existing databases.
        raw.execute('''
CREATE TABLE categories (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 uuid TEXT UNIQUE,
 name TEXT NOT NULL,
 type TEXT NOT NULL,
 color TEXT NOT NULL DEFAULT '#64748b',
 icon TEXT,
 sort_order INTEGER NOT NULL DEFAULT 0,
 archived_at TEXT,
 created_at TEXT NOT NULL DEFAULT (datetime('now')),
 updated_at TEXT,
 deleted_at TEXT,
 sync_status TEXT NOT NULL DEFAULT 'pending'
)
''');
        if (withExistingRows) {
          raw.execute('''
INSERT INTO categories (id, uuid, name, type, created_at, updated_at)
VALUES (1, 'existing-broken', '기존 카테고리', 'expense', '2026-09-01 12:00:00', NULL),
       (2, 'existing-valid', '정상 카테고리', 'income', '2026-09-01 12:00:00', '2026-09-02 13:00:00')
''');
        }
        raw.execute('PRAGMA user_version = 18');
      },
    ),
  );
}

void main() {
  test(
    'adding categories to an upgraded database keeps the list readable',
    () async {
      final db = legacyDatabase();
      addTearDown(db.close);
      expect(await db.categoriesDao.getAllCategories(), isEmpty);
      for (final type in ['expense', 'income']) {
        await db.categoriesDao.saveCategory(
          draft: CategoryDraft(name: '추가한 $type', type: type, color: '#123456'),
        );
      }
      final categories = await db.categoriesDao.getAllCategories();
      expect(categories, hasLength(2));
      for (final category in categories) {
        expect(category.uuid, isNotEmpty);
        expect(category.createdAt, isNotEmpty);
        expect(category.updatedAt, isNotEmpty);
        expect(category.color, '#123456');
      }
    },
  );

  test(
    'opening an upgraded database repairs existing missing timestamps only',
    () async {
      final db = legacyDatabase(withExistingRows: true);
      addTearDown(db.close);
      final categories = await db.categoriesDao.getAllCategories();
      final repaired = categories.singleWhere((row) => row.id == 1);
      expect(repaired.uuid, 'existing-broken');
      expect(repaired.name, '기존 카테고리');
      expect(repaired.updatedAt, '2026-09-01 12:00:00');
      expect(
        categories.singleWhere((row) => row.id == 2).updatedAt,
        '2026-09-02 13:00:00',
      );
      final queued = await db
          .customSelect(
            "SELECT uuid FROM sync_outbox WHERE entity = 'categories'",
          )
          .get();
      expect(
        queued.map((row) => row.read<String>('uuid')),
        contains('existing-broken'),
      );
    },
  );
}
