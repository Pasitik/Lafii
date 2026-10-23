import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:visit_schema/visit_schema.dart';

/// Encrypted local storage. SQLCipher, keyed from the Android Keystore.
///
/// Two tables:
///   docs    current state of each record; scalar corrections overwrite.
///   events  append-only clinical log. There is no update or delete path.
class Store {
  Store._(this._db);
  final Database _db;

  static Future<Store> open() async {
    const secure = FlutterSecureStorage();
    var key = await secure.read(key: 'db_key');
    if (key == null) {
      final r = Random.secure();
      key = base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256)));
      await secure.write(key: 'db_key', value: key);
    }
    final path = p.join(await getDatabasesPath(), 'lafii.db');
    final db = await openDatabase(
      path,
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE docs (kind TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, '
            'PRIMARY KEY (kind, id))');
        await db.execute(
            'CREATE TABLE events (id TEXT PRIMARY KEY, at TEXT NOT NULL, kind TEXT NOT NULL, '
            'entity_id TEXT NOT NULL, json TEXT NOT NULL)');
        // Enforce append-only at the storage layer as well.
        await db.execute(
            "CREATE TRIGGER events_no_update BEFORE UPDATE ON events "
            "BEGIN SELECT RAISE(ABORT, 'events are append-only'); END");
        await db.execute(
            "CREATE TRIGGER events_no_delete BEFORE DELETE ON events "
            "BEGIN SELECT RAISE(ABORT, 'events are append-only'); END");
      },
    );
    return Store._(db);
  }

  Future<Map<String, List<Map<String, Object?>>>> loadAll() async {
    final rows = await _db.query('docs');
    final out = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      out.putIfAbsent(r['kind'] as String, () => []).add(
          (jsonDecode(r['json'] as String) as Map).cast<String, Object?>());
    }
    return out;
  }

  Future<void> put(String kind, String id, Map<String, Object?> json) => _db.insert(
        'docs',
        {'kind': kind, 'id': id, 'json': jsonEncode(json)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> append(ClinicalEvent e) => _db.insert(
        'events',
        {
          'id': e.id,
          'at': e.at.toIso8601String(),
          'kind': e.kind,
          'entity_id': e.entityId,
          'json': jsonEncode(e.data),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

  Future<List<ClinicalEvent>> events({String? kind}) async {
    final rows = await _db.query('events',
        where: kind == null ? null : 'kind = ?',
        whereArgs: kind == null ? null : [kind],
        orderBy: 'at, id');
    return [
      for (final r in rows)
        ClinicalEvent(
          id: r['id'] as String,
          at: DateTime.parse(r['at'] as String),
          kind: r['kind'] as String,
          entityId: r['entity_id'] as String,
          data: (jsonDecode(r['json'] as String) as Map).cast<String, Object?>(),
        )
    ];
  }
}
