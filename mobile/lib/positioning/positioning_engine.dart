import 'dart:math' as math;

import '../ble/beacon_scanner.dart';
import '../core/config.dart';
import '../data/models.dart';

/// 1-D Kalman filter for one beacon's RSSI.
class Kalman1D {
  Kalman1D({this.q = 0.05, this.r = 4.0});
  final double q, r;
  double? _x;
  double _p = 1;

  double update(double z) {
    final x = _x;
    if (x == null) {
      _x = z;
      return z;
    }
    _p += q;
    final k = _p / (_p + r);
    final nx = x + k * (z - x);
    _p *= (1 - k);
    _x = nx;
    return nx;
  }
}

/// Log-distance path loss: d = 10 ^ ((RSSI@1m - RSSI) / (10 n)).
double rssiToMeters(double rssi, {required int rssi1m, required double n}) =>
    math.pow(10, (rssi1m - rssi) / (10 * n)).toDouble();

class _Snap {
  final NavEdge edge;
  final P point;
  const _Snap(this.edge, this.point);
}

/// Turns one scan window into a [LocationFix], once per second:
/// 1 filter (Kalman) -> 2 top-3 beacons -> 3 weighted centroid (w = 1/d²)
/// -> 4 snap onto the walking graph -> 5 zone by polygon + vote of the last 3 windows.
class PositioningEngine {
  PositioningEngine(this.floor);
  final FloorPackage floor;

  final _filters = <String, Kalman1D>{};
  String? _mainBeacon;
  String? _candidate;
  int _candidateCount = 0;
  final _zoneHistory = <String>[];
  LocationFix? _last;

  LocationFix? get last => _last;

  LocationFix? process(ScanWindow window, {DateTime? now}) {
    final t = now ?? DateTime.now();

    // 1. filter every beacon we know
    final filtered = <String, double>{};
    window.forEach((uid, rssi) {
      if (!floor.beacons.containsKey(uid) || rssi < AppConfig.minRssi) return;
      filtered[uid] = _filters.putIfAbsent(uid, Kalman1D.new).update(rssi);
    });
    if (filtered.isEmpty) return null; // caller keeps the last fix; after 5 s ask for manual position

    // 2. strongest three
    final top = filtered.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = top.take(3).toList();

    // main beacon with hysteresis (used when only one beacon is heard)
    final strongest = best.first.key;
    if (_mainBeacon == null) {
      _mainBeacon = strongest;
    } else if (strongest != _mainBeacon &&
        filtered[strongest]! - (filtered[_mainBeacon] ?? -120) >= AppConfig.hysteresisDb) {
      _candidateCount = _candidate == strongest ? _candidateCount + 1 : 1;
      _candidate = strongest;
      if (_candidateCount >= AppConfig.hysteresisWindows) {
        _mainBeacon = strongest;
        _candidateCount = 0;
      }
    }

    // only one beacon: proximity
    if (best.length == 1) {
      final b = floor.beacons[_mainBeacon]!;
      return _accept(b.pos, null, b.zoneId, 5.0, 'proximity', 1, t);
    }

    // 3. weighted centroid
    var wSum = 0.0, x = 0.0, y = 0.0;
    for (final e in best) {
      final b = floor.beacons[e.key]!;
      final d = math.max(0.5, rssiToMeters(e.value, rssi1m: b.rssi1m, n: b.pathLossN));
      final w = 1 / (d * d);
      wSum += w;
      x += w * b.pos.x;
      y += w * b.pos.y;
    }
    final raw = P(x / wSum, y / wSum);

    // 4. snap onto the nearest walkable edge
    final snap = _snap(raw);
    final pos = snap?.point ?? raw;

    // 5. zone by polygon, else zone of the nearest graph node, then majority vote
    var zoneId = floor.zoneAt(pos)?.id;
    if (zoneId == null && snap != null) {
      final a = floor.nodes[snap.edge.from]!, b = floor.nodes[snap.edge.to]!;
      zoneId = pos.dist(a.pos) <= pos.dist(b.pos) ? a.zoneId : b.zoneId;
    }
    zoneId ??= floor.beacons[_mainBeacon]!.zoneId;
    _zoneHistory.add(zoneId);
    if (_zoneHistory.length > AppConfig.zoneVoteWindows) _zoneHistory.removeAt(0);
    final voted = _majority(_zoneHistory);

    final accuracy = best.length >= 3 ? 2.5 : 4.0; // estimate; measure in the real building
    return _accept(pos, snap?.edge.id, voted, accuracy, 'wcl', best.length, t);
  }

  LocationFix? _accept(P pos, String? edgeId, String zoneId, double acc, String method, int n, DateTime t) {
    final prev = _last;
    if (prev != null) {
      final dt = t.difference(prev.measuredAt).inMilliseconds / 1000;
      // reject a jump faster than walking speed (allow 1 m of noise)
      if (dt > 0 && pos.dist(prev.pos) > AppConfig.maxWalkSpeedMps * dt + 1.0) return prev;
    }
    final fix = LocationFix(
      floorId: floor.floorId,
      zoneId: zoneId,
      edgeId: edgeId,
      pos: pos,
      accuracyM: acc,
      method: method,
      beaconCount: n,
      measuredAt: t,
    );
    _last = fix;
    return fix;
  }

  _Snap? _snap(P p) {
    _Snap? best;
    var bestCost = double.infinity;
    for (final e in floor.edges) {
      final a = floor.nodes[e.from]?.pos, b = floor.nodes[e.to]?.pos;
      if (a == null || b == null) continue;
      final q = projectOnSegment(p, a, b);
      final cost = p.dist(q) + (e.type == 'door' ? AppConfig.doorSnapPenaltyM : 0);
      if (cost < bestCost) {
        bestCost = cost;
        best = _Snap(e, q);
      }
    }
    return best;
  }

  static String _majority(List<String> xs) {
    final c = <String, int>{};
    for (final x in xs) {
      c[x] = (c[x] ?? 0) + 1;
    }
    var best = xs.last;
    c.forEach((k, v) {
      if (v > c[best]!) best = k;
    });
    return best;
  }
}

/// Closest point to [p] on the segment a-b.
P projectOnSegment(P p, P a, P b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final l2 = dx * dx + dy * dy;
  if (l2 == 0) return a;
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / l2).clamp(0.0, 1.0).toDouble();
  return P(a.x + t * dx, a.y + t * dy);
}
