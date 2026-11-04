import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

/// Opens the phone's SQLite file (safealert.db in the app's private folder)
/// and creates the 14 tables on first start.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open({String fileName = 'safealert.db', DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final path = fileName == inMemoryDatabasePath ? fileName : p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kSchemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final s in kSchemaStatements) {
            batch.execute(s);
          }
          await batch.commit(noResult: true);
        },
      ),
    );
    return AppDatabase._(db);
  }

  /// Is a floor package already stored?
  Future<bool> hasFloor(String floorId) async {
    final r = await db.query('FLOOR_MAP', where: 'floor_id = ?', whereArgs: [floorId], limit: 1);
    return r.isNotEmpty;
  }

  /// Writes a floor package (the JSON format of assets/maps/floor2.json, which is
  /// also what GET /sync/static returns) into FLOOR_MAP, ZONE_CACHE, BEACON_CACHE,
  /// NAV_NODE and NAV_EDGE. Replaces the old rows of that floor.
  Future<void> importFloorPackage(String jsonText, {String? mapFilePath}) async {
    final m = jsonDecode(jsonText) as Map<String, dynamic>;
    final floor = m['floor'] as Map<String, dynamic>;
    final floorId = floor['floor_id'] as String;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Update-then-insert ("put") instead of DELETE/REPLACE: other tables point at these
      // rows (BLE_CALIBRATION, LOCATION_FIX, NAV_SESSION) and foreign keys are ON.
      // Works on old Android SQLite versions that have no UPSERT.
      await put(txn, 'FLOOR_MAP', 'floor_id', {
        'floor_id': floorId,
        'building_name': floor['building_name'],
        'floor_number': floor['floor_number'],
        'label': floor['label'],
        'map_version': floor['map_version'],
        'map_file_path': mapFilePath ?? 'bundled',
        'width_m': (floor['width_m'] as num).toDouble(),
        'height_m': (floor['height_m'] as num).toDouble(),
        'downloaded_at': now,
      });
      for (final z in (m['zones'] as List).cast<Map<String, dynamic>>()) {
        await put(
          txn,
          'ZONE_CACHE',
          'zone_id',
          {
            'zone_id': z['zone_id'],
            'floor_id': floorId,
            'zone_code': z['zone_code'],
            'zone_name': z['zone_name'],
            'zone_type': z['zone_type'],
            'is_evacuation_route': z['is_evacuation_route'],
            'polygon_json': jsonEncode(z['polygon']),
          },
          // a new zone starts as "normal"; an existing zone keeps its current hazard level
          insertOnly: {'hazard_level': 0},
        );
      }
      for (final x in (m['beacons'] as List).cast<Map<String, dynamic>>()) {
        await put(txn, 'BEACON_CACHE', 'beacon_uid', {
          'beacon_uid': x['beacon_uid'],
          'floor_id': floorId,
          'zone_id': x['zone_id'],
          'major': x['major'],
          'minor': x['minor'],
          'pos_x': (x['pos_x'] as num).toDouble(),
          'pos_y': (x['pos_y'] as num).toDouble(),
          'tx_power': x['tx_power'],
          'rssi_1m': x['rssi_1m'],
          'path_loss_n': (x['path_loss_n'] as num).toDouble(),
          'is_active': 1,
        });
      }
      for (final n in (m['nodes'] as List).cast<Map<String, dynamic>>()) {
        await put(txn, 'NAV_NODE', 'node_id', {
          'node_id': n['node_id'],
          'floor_id': floorId,
          'zone_id': n['zone_id'],
          'node_type': n['node_type'],
          'label': n['label'],
          'pos_x': (n['pos_x'] as num).toDouble(),
          'pos_y': (n['pos_y'] as num).toDouble(),
          'is_exit': n['is_exit'],
          'exit_priority': n['exit_priority'],
        });
      }
      for (final e in (m['edges'] as List).cast<Map<String, dynamic>>()) {
        await put(txn, 'NAV_EDGE', 'edge_id', {
          'edge_id': e['edge_id'],
          'from_node': e['from_node'],
          'to_node': e['to_node'],
          'zone_id': e['zone_id'],
          'distance_m': (e['distance_m'] as num).toDouble(),
          'edge_type': e['edge_type'],
          'is_bidirectional': e['is_bidirectional'],
          'base_factor': (e['base_factor'] as num).toDouble(),
        });
      }
      await put(txn, 'SYNC_STATE', 'entity', {
        'entity': 'floor_map:$floorId',
        'last_seq': 0,
        'last_version': floor['map_version'],
        'last_sync_at': now,
        'last_status': 'ok',
      });
    });
  }

  /// Update-then-insert. Safe with foreign keys ON and on old Android SQLite (no UPSERT).
  static Future<void> put(
    Transaction txn,
    String table,
    String pk,
    Map<String, Object?> row, {
    Map<String, Object?> insertOnly = const {},
  }) async {
    final changed = await txn.update(table, row, where: '$pk = ?', whereArgs: [row[pk]]);
    if (changed == 0) {
      await txn.insert(table, {...row, ...insertOnly});
    }
  }

  Future<void> close() => db.close();
}
