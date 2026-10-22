import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<int> create(String title, {bool pinned = false}) =>
      db.notesDao.saveNote(title: title, content: '', pinned: pinned);
  Future<List<int>> order() async =>
      (await db.notesDao.watchNotesWithChecklist().first)
          .map((e) => e.note.id)
          .toList();

  test(
    'pin groups retain independent order after editing, and reject stale/cross-group writes',
    () async {
      final a = await create('A', pinned: true),
          b = await create('B', pinned: true);
      final c = await create('C'), d = await create('D');
      await db.notesDao.updateNoteOrder(true, [b, a]);
      await db.notesDao.updateNoteOrder(false, [c, d]);
      expect(await order(), [b, a, c, d]);
      await db.notesDao.saveNote(
        id: a,
        title: 'A edited',
        content: 'body',
        pinned: true,
      );
      expect(await order(), [b, a, c, d]);
      expect((await db.notesDao.watchNotes().first).map((n) => n.id), [
        b,
        a,
        c,
        d,
      ]);
      await expectLater(
        db.notesDao.updateNoteOrder(true, [b, c]),
        throwsStateError,
      );
      await expectLater(
        db.notesDao.updateNoteOrder(false, [c, c]),
        throwsStateError,
      );
      await expectLater(
        db.notesDao.updateNoteOrder(false, [c]),
        throwsStateError,
      );
      expect(await order(), [b, a, c, d]);
      // A late storage error must roll back the first move as well.
      await db.customStatement(
        'CREATE TRIGGER reject_order BEFORE UPDATE OF sort_order ON notes WHEN NEW.id=$c BEGIN SELECT RAISE(ABORT, \'test\'); END',
      );
      await expectLater(
        db.notesDao.updateNoteOrder(false, [d, c]),
        throwsA(anything),
      );
      expect(await order(), [b, a, c, d]);
    },
  );

  test(
    'backup roundtrip includes order and legacy backups default to zero',
    () async {
      final a = await create('A'), b = await create('B');
      await db.notesDao.updateNoteOrder(false, [a, b]);
      final backup = await db.backupDao.exportBackup();
      final parsed = parseBackup(backup.toJsonString()).backup!;
      expect(parsed.notes.map((n) => n.sortOrder), [1, 2]);
      await db.backupDao.importBackup(parsed);
      expect(await order(), [a, b]);
      final json = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      for (final row in (json['data'] as Map)['notes'] as List) {
        (row as Map).remove('sortOrder');
      }
      expect(
        parseBackup(
          jsonEncode(json),
        ).backup!.notes.every((n) => n.sortOrder == 0),
        isTrue,
      );
    },
  );

  test('sync transmits order; older clients preserve local order', () async {
    final a = await create('A'), b = await create('B');
    final store = LocalSyncStore(db);
    for (final pending in await store.pendingEntries()) {
      await store.acknowledge(pending);
    }
    await db.notesDao.updateNoteOrder(false, [a, b]);
    final note = (await db.notesDao.getNote(a))!;
    final payload = (await store.buildPayload('notes', note.uuid))!;
    expect(payload['sort_order'], 1);
    expect(await store.currentEntry('notes', note.uuid), isNotNull);
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    final remoteStore = LocalSyncStore(other);
    await remoteStore.applyRemotePage(
      entity: 'notes',
      bootstrap: false,
      rows: [
        RemoteSyncRow(
          uuid: note.uuid,
          payload: payload,
          updatedAt: '2026-10-22T00:00:00Z',
          deletedAt: null,
          revision: 1,
        ),
      ],
    );
    expect((await other.notesDao.watchNotes().first).single.sortOrder, 1);
    for (final pending in await store.pendingEntries()) {
      await store.acknowledge(pending);
    }
    final legacy = {...payload}..remove('sort_order');
    await store.applyRemotePage(
      entity: 'notes',
      bootstrap: false,
      rows: [
        RemoteSyncRow(
          uuid: note.uuid,
          payload: legacy,
          updatedAt: '2026-10-22T00:01:00Z',
          deletedAt: null,
          revision: 2,
        ),
      ],
    );
    expect((await db.notesDao.getNote(a))!.sortOrder, 1);
  });

  test('v25 migration preserves notes and acquires zero order', () async {
    final dir = await Directory.systemTemp.createTemp('note-order-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');
    final old = AppDatabase.forTesting(NativeDatabase(file));
    final id = await old.notesDao.saveNote(title: 'existing', content: 'keep');
    await old.customStatement('DROP TRIGGER notes_sync_content_update');
    await old.customStatement('ALTER TABLE notes DROP COLUMN sort_order');
    await old.customStatement('PRAGMA user_version=25');
    await old.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final note = (await upgraded.notesDao.getNote(id))!;
      expect(note.content, 'keep');
      expect(note.sortOrder, 0);
      await upgraded.notesDao.updateNoteOrder(false, [id]);
      expect((await upgraded.notesDao.getNote(id))!.sortOrder, 1);
    } finally {
      await upgraded.close();
    }
  });
}
