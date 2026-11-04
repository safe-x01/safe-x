import 'dart:convert';

import 'models.dart';

/// Builds a [FloorPackage] straight from the floor JSON (no database).
/// Used by unit tests and by the admin "preview floor file" tool.
FloorPackage floorFromJson(String text) {
  final m = jsonDecode(text) as Map<String, dynamic>;
  final f = m['floor'] as Map<String, dynamic>;
  final floorId = f['floor_id'] as String;
  double d(Object? v) => (v as num).toDouble();

  final zones = <String, Zone>{
    for (final z in (m['zones'] as List).cast<Map<String, dynamic>>())
      z['zone_id'] as String: Zone(
        id: z['zone_id'] as String,
        code: z['zone_code'] as String,
        name: z['zone_name'] as String,
        type: z['zone_type'] as String,
        floorId: floorId,
        isEvacuationRoute: z['is_evacuation_route'] == 1,
        polygon: (z['polygon'] as List).map((p) => P(d(p[0]), d(p[1]))).toList(),
      ),
  };
  final beacons = <String, Beacon>{
    for (final b in (m['beacons'] as List).cast<Map<String, dynamic>>())
      b['beacon_uid'] as String: Beacon(
        uid: b['beacon_uid'] as String,
        floorId: floorId,
        zoneId: b['zone_id'] as String,
        major: b['major'] as int,
        minor: b['minor'] as int,
        pos: P(d(b['pos_x']), d(b['pos_y'])),
        txPower: b['tx_power'] as int,
        rssi1m: b['rssi_1m'] as int,
        pathLossN: d(b['path_loss_n']),
      ),
  };
  final nodes = <String, NavNode>{
    for (final n in (m['nodes'] as List).cast<Map<String, dynamic>>())
      n['node_id'] as String: NavNode(
        id: n['node_id'] as String,
        zoneId: n['zone_id'] as String,
        type: n['node_type'] as String,
        label: n['label'] as String,
        pos: P(d(n['pos_x']), d(n['pos_y'])),
        isExit: n['is_exit'] == 1,
        exitPriority: n['exit_priority'] as int?,
      ),
  };
  final edges = [
    for (final e in (m['edges'] as List).cast<Map<String, dynamic>>())
      NavEdge(
        id: e['edge_id'] as String,
        from: e['from_node'] as String,
        to: e['to_node'] as String,
        zoneId: e['zone_id'] as String,
        type: e['edge_type'] as String,
        distanceM: d(e['distance_m']),
        baseFactor: d(e['base_factor']),
        bidirectional: e['is_bidirectional'] == 1,
      ),
  ];
  return FloorPackage(
    floorId: floorId,
    label: f['label'] as String,
    floorNumber: f['floor_number'] as int,
    mapVersion: f['map_version'] as int,
    widthM: d(f['width_m']),
    heightM: d(f['height_m']),
    zones: zones,
    beacons: beacons,
    nodes: nodes,
    edges: edges,
  );
}
