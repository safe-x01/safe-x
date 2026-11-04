import 'dart:math' as math;

/// A point on the floor plan, in metres. The corridor runs along y = 0.
class P {
  final double x, y;
  const P(this.x, this.y);
  double dist(P o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));
  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Hazard levels stored in ZONE_CACHE.hazard_level.
class Hazard {
  Hazard._();
  static const normal = 0, watch = 1, smoke = 2, blocked = 3;
}

class Zone {
  final String id, code, name, type, floorId;
  final bool isEvacuationRoute;
  final List<P> polygon;
  int hazardLevel;
  Zone({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.floorId,
    required this.isEvacuationRoute,
    required this.polygon,
    this.hazardLevel = Hazard.normal,
  });

  /// Ray casting point-in-polygon test.
  bool contains(P p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      final crosses = (a.y > p.y) != (b.y > p.y) && p.x <= (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

class Beacon {
  final String uid, floorId, zoneId;
  final int major, minor, txPower, rssi1m;
  final double pathLossN;
  final P pos;
  const Beacon({
    required this.uid,
    required this.floorId,
    required this.zoneId,
    required this.major,
    required this.minor,
    required this.pos,
    required this.txPower,
    required this.rssi1m,
    required this.pathLossN,
  });
}

class NavNode {
  final String id, zoneId, type, label;
  final P pos;
  final bool isExit;
  final int? exitPriority;
  const NavNode({
    required this.id,
    required this.zoneId,
    required this.type,
    required this.label,
    required this.pos,
    required this.isExit,
    this.exitPriority,
  });
}

class NavEdge {
  final String id, from, to, zoneId, type;
  final double distanceM, baseFactor;
  final bool bidirectional;
  const NavEdge({
    required this.id,
    required this.from,
    required this.to,
    required this.zoneId,
    required this.type,
    required this.distanceM,
    required this.baseFactor,
    required this.bidirectional,
  });
}

/// Everything the phone needs to draw a floor and navigate on it.
class FloorPackage {
  final String floorId, label;
  final int floorNumber, mapVersion;
  final double widthM, heightM;
  final Map<String, Zone> zones;
  final Map<String, Beacon> beacons; // key = beacon uid
  final Map<String, NavNode> nodes;
  final List<NavEdge> edges;
  const FloorPackage({
    required this.floorId,
    required this.label,
    required this.floorNumber,
    required this.mapVersion,
    required this.widthM,
    required this.heightM,
    required this.zones,
    required this.beacons,
    required this.nodes,
    required this.edges,
  });

  Zone? zoneAt(P p) {
    for (final z in zones.values) {
      if (z.contains(p)) return z;
    }
    return null;
  }

  Map<String, int> get hazards => {for (final z in zones.values) z.id: z.hazardLevel};
}

/// One row of LOCATION_FIX.
class LocationFix {
  final String floorId, zoneId;
  final String? edgeId;
  final P pos;
  final double accuracyM;
  final String method; // proximity / wcl / manual
  final int beaconCount;
  final DateTime measuredAt;
  const LocationFix({
    required this.floorId,
    required this.zoneId,
    required this.edgeId,
    required this.pos,
    required this.accuracyM,
    required this.method,
    required this.beaconCount,
    required this.measuredAt,
  });

  Map<String, Object?> toRow() => {
        'floor_id': floorId,
        'zone_id': zoneId,
        'edge_id': edgeId,
        'pos_x': pos.x,
        'pos_y': pos.y,
        'accuracy_m': accuracyM,
        'method': method,
        'beacon_count': beaconCount,
        'heading_deg': null,
        'measured_at': measuredAt.toIso8601String(),
        'uploaded': 0,
      };
}
