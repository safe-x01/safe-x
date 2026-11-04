import 'dart:convert';

import '../db/app_database.dart';
import '../models.dart';

/// Reads FLOOR_MAP, ZONE_CACHE, BEACON_CACHE, NAV_NODE and NAV_EDGE into one [FloorPackage].
class MapRepository {
  MapRepository(this._db);
  final AppDatabase _db;

  Future<FloorPackage?> loadFloor(String floorId) async {
    final db = _db.db;
    final f = await db.query('FLOOR_MAP', where: 'floor_id = ?', whereArgs: [floorId], limit: 1);
    if (f.isEmpty) return null;
    final floor = f.first;

    final zones = <String, Zone>{};
    for (final r in await db.query('ZONE_CACHE', where: 'floor_id = ?', whereArgs: [floorId])) {
      final poly = (jsonDecode(r['polygon_json'] as String) as List)
          .map((e) => P((e[0] as num).toDouble(), (e[1] as num).toDouble()))
          .toList();
      zones[r['zone_id'] as String] = Zone(
        id: r['zone_id'] as String,
        code: r['zone_code'] as String,
        name: r['zone_name'] as String,
        type: r['zone_type'] as String,
        floorId: floorId,
        isEvacuationRoute: (r['is_evacuation_route'] as int) == 1,
        polygon: poly,
        hazardLevel: r['hazard_level'] as int,
      );
    }

    final beacons = <String, Beacon>{};
    for (final r in await db.query('BEACON_CACHE', where: 'floor_id = ? AND is_active = 1', whereArgs: [floorId])) {
      final b = Beacon(
        uid: r['beacon_uid'] as String,
        floorId: floorId,
        zoneId: r['zone_id'] as String,
        major: r['major'] as int,
        minor: r['minor'] as int,
        pos: P((r['pos_x'] as num).toDouble(), (r['pos_y'] as num).toDouble()),
        txPower: r['tx_power'] as int,
        rssi1m: r['rssi_1m'] as int,
        pathLossN: (r['path_loss_n'] as num).toDouble(),
      );
      beacons[b.uid] = b;
    }

    final nodes = <String, NavNode>{};
    for (final r in await db.query('NAV_NODE', where: 'floor_id = ?', whereArgs: [floorId])) {
      final n = NavNode(
        id: r['node_id'] as String,
        zoneId: r['zone_id'] as String,
        type: r['node_type'] as String,
        label: (r['label'] as String?) ?? (r['node_id'] as String),
        pos: P((r['pos_x'] as num).toDouble(), (r['pos_y'] as num).toDouble()),
        isExit: (r['is_exit'] as int) == 1,
        exitPriority: r['exit_priority'] as int?,
      );
      nodes[n.id] = n;
    }

    final edges = <NavEdge>[];
    final rows = await db.rawQuery(
      'SELECT e.* FROM NAV_EDGE e JOIN NAV_NODE n ON n.node_id = e.from_node WHERE n.floor_id = ?',
      [floorId],
    );
    for (final r in rows) {
      edges.add(NavEdge(
        id: r['edge_id'] as String,
        from: r['from_node'] as String,
        to: r['to_node'] as String,
        zoneId: r['zone_id'] as String,
        type: r['edge_type'] as String,
        distanceM: (r['distance_m'] as num).toDouble(),
        baseFactor: (r['base_factor'] as num).toDouble(),
        bidirectional: (r['is_bidirectional'] as int) == 1,
      ));
    }

    return FloorPackage(
      floorId: floorId,
      label: floor['label'] as String,
      floorNumber: floor['floor_number'] as int,
      mapVersion: floor['map_version'] as int,
      widthM: (floor['width_m'] as num).toDouble(),
      heightM: (floor['height_m'] as num).toDouble(),
      zones: zones,
      beacons: beacons,
      nodes: nodes,
      edges: edges,
    );
  }

  /// Called when the server pushes new hazard levels (WebSocket / push).
  Future<void> setHazard(String zoneId, int level) async {
    await _db.db.update(
      'ZONE_CACHE',
      {'hazard_level': level, 'hazard_updated_at': DateTime.now().toIso8601String()},
      where: 'zone_id = ?',
      whereArgs: [zoneId],
    );
  }

  Future<void> saveFix(LocationFix fix) async {
    await _db.db.insert('LOCATION_FIX', fix.toRow());
  }
}
