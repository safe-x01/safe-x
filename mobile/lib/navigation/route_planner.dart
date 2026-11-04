import 'dart:math' as math;

import '../core/config.dart';
import '../data/models.dart';
import '../positioning/positioning_engine.dart' show projectOnSegment;

/// Weight multiplier by hazard level. infinity = the edge is removed.
const Map<int, double> kHazardFactor = {
  Hazard.normal: 1.0,
  Hazard.watch: 1.5,
  Hazard.smoke: 5.0,
  Hazard.blocked: double.infinity,
};

enum IncidentMode { none, fire, gas, quake }

class RouteOption {
  final String exitNodeId;
  final List<String> nodeIds;
  final double cost;
  final double distanceM;
  final bool passesSmoke;
  const RouteOption(this.exitNodeId, this.nodeIds, this.cost, this.distanceM, this.passesSmoke);
}

class RoutePlan {
  /// Sorted by cost: index 0 = route A, 1 = B ...
  final List<RouteOption> options;

  /// Exits (and the lift) that cannot be reached safely: shown as "ห้ามใช้".
  final List<String> blocked;
  const RoutePlan(this.options, this.blocked);
}

class _Arc {
  final String to;
  final double weight, distance;
  final bool smoke;
  const _Arc(this.to, this.weight, this.distance, this.smoke);
}

/// Hazard-weighted Dijkstra on NAV_NODE / NAV_EDGE.
/// weight = distance × base_factor × hazard factor of the edge's zone.
class RoutePlanner {
  RoutePlanner(this.floor);
  final FloorPackage floor;

  Map<String, List<_Arc>> _graph(Map<String, int> hazards, IncidentMode mode) {
    final g = <String, List<_Arc>>{};
    for (final e in floor.edges) {
      var h = hazards[e.zoneId] ?? Hazard.normal;
      if (e.type == 'lift' && mode != IncidentMode.none) h = Hazard.blocked; // never evacuate by lift
      final f = kHazardFactor[h]!;
      if (f.isInfinite) continue;
      final w = e.distanceM * e.baseFactor * f;
      final smoke = h == Hazard.smoke;
      g.putIfAbsent(e.from, () => []).add(_Arc(e.to, w, e.distanceM, smoke));
      if (e.bidirectional) g.putIfAbsent(e.to, () => []).add(_Arc(e.from, w, e.distanceM, smoke));
    }
    return g;
  }

  /// Routes from [startNodeId] to every exit, best first.
  RoutePlan plan(String startNodeId, Map<String, int> hazards, {IncidentMode mode = IncidentMode.fire}) {
    final g = _graph(hazards, mode);
    final options = <RouteOption>[];
    final blocked = <String>[];
    // only real exits are destinations; during an incident the lift is listed as "ห้ามใช้"
    for (final t in floor.nodes.values.where((n) => n.isExit).map((n) => n.id)) {
      final r = _dijkstra(g, startNodeId, t);
      if (r == null) {
        blocked.add(t);
      } else {
        options.add(r);
      }
    }
    if (mode != IncidentMode.none) {
      blocked.addAll(floor.nodes.values.where((n) => n.type == 'lift').map((n) => n.id));
    }
    options.sort((a, b) => a.cost.compareTo(b.cost));
    return RoutePlan(options, blocked);
  }

  RouteOption? _dijkstra(Map<String, List<_Arc>> g, String src, String dst) {
    // the graph is small (tens of nodes), so a simple O(V²) Dijkstra is enough (< 1 ms)
    final cost = <String, double>{src: 0};
    final dist = <String, double>{src: 0};
    final smoke = <String, bool>{src: false};
    final prev = <String, String>{};
    final done = <String>{};
    while (true) {
      String? u;
      var best = double.infinity;
      cost.forEach((k, v) {
        if (!done.contains(k) && v < best) {
          best = v;
          u = k;
        }
      });
      final cur = u;
      if (cur == null) return null;
      if (cur == dst) break;
      done.add(cur);
      for (final a in g[cur] ?? const <_Arc>[]) {
        final nc = best + a.weight;
        if (nc < (cost[a.to] ?? double.infinity)) {
          cost[a.to] = nc;
          dist[a.to] = dist[cur]! + a.distance;
          smoke[a.to] = smoke[cur]! || a.smoke;
          prev[a.to] = cur;
        }
      }
    }
    final path = <String>[dst];
    while (path.last != src) {
      path.add(prev[path.last]!);
    }
    return RouteOption(dst, path.reversed.toList(), _r1(cost[dst]!), _r1(dist[dst]!), smoke[dst]!);
  }

  /// Nearest graph node to a position (start of a route).
  String nearestNode(P p, {bool corridorFirst = true}) {
    String? best;
    var bd = double.infinity;
    for (final n in floor.nodes.values) {
      if (n.type == 'exit' || n.type == 'lift') continue;
      final d = n.pos.dist(p) + (corridorFirst && n.type == 'door' ? AppConfig.doorSnapPenaltyM : 0);
      if (d < bd) {
        bd = d;
        best = n.id;
      }
    }
    return best!;
  }

  /// Distance from [p] to the route line; > offRouteMeters for 3 s = re-plan.
  double distanceToRoute(P p, List<String> nodeIds) {
    var best = double.infinity;
    for (var i = 1; i < nodeIds.length; i++) {
      final a = floor.nodes[nodeIds[i - 1]]!.pos, b = floor.nodes[nodeIds[i]]!.pos;
      best = math.min(best, p.dist(projectOnSegment(p, a, b)));
    }
    return best;
  }

  static double _r1(double v) => (v * 10).roundToDouble() / 10;
}

/// One spoken / shown step: "เดิน 15 ม. แล้วเลี้ยวซ้ายที่โถงหน้าบันได E".
class NavStep {
  final String text;
  final String atNodeId;
  final double meters;
  final String turn; // straight / left / right / arrive
  const NavStep(this.text, this.atNodeId, this.meters, this.turn);
}

/// Turns a node path into steps. A heading change under 30° = keep walking.
/// Coordinates: x east, y north, so a positive (counter-clockwise) turn is a LEFT turn.
List<NavStep> buildSteps(FloorPackage floor, List<String> path) {
  final steps = <NavStep>[];
  var seg = 0.0;
  for (var i = 1; i < path.length; i++) {
    final a = floor.nodes[path[i - 1]]!, b = floor.nodes[path[i]]!;
    seg += a.pos.dist(b.pos);
    if (i == path.length - 1) {
      steps.add(NavStep('เดินต่อ ${seg.round()} ม. ถึง${b.label}', b.id, seg, 'arrive'));
      break;
    }
    final c = floor.nodes[path[i + 1]]!;
    final h1 = math.atan2(b.pos.y - a.pos.y, b.pos.x - a.pos.x);
    final h2 = math.atan2(c.pos.y - b.pos.y, c.pos.x - b.pos.x);
    var turn = (h2 - h1) * 180 / math.pi;
    turn = (turn + 540) % 360 - 180;
    if (turn.abs() < AppConfig.turnThresholdDeg) continue;
    final side = turn > 0 ? 'ซ้าย' : 'ขวา';
    steps.add(NavStep('เดิน ${seg.round()} ม. แล้วเลี้ยว$sideที่${b.label}', b.id, seg, turn > 0 ? 'left' : 'right'));
    seg = 0;
  }
  return steps;
}
