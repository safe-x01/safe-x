import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safealert/data/floor_json.dart';
import 'package:safealert/data/models.dart';
import 'package:safealert/navigation/route_planner.dart';

/// Same scenario as the design document: fire in room 203, smoke in the corridor in front of it.
void main() {
  final floor = floorFromJson(File('assets/maps/floor2.json').readAsStringSync());
  final planner = RoutePlanner(floor);
  const hazards = {'Z-203': Hazard.blocked, 'Z-CORR-MID-W': Hazard.smoke};

  test('in front of room 201: route A goes to stair E (21.3 m), lift is blocked', () {
    final plan = planner.plan('C05', hazards, mode: IncidentMode.fire);
    expect(plan.options.first.exitNodeId, 'EXIT_E');
    expect(plan.options.first.distanceM, closeTo(21.3, 0.05));
    expect(plan.options.first.nodeIds, ['C05', 'C06', 'C07', 'C08', 'EXIT_E']);
    expect(plan.options[1].exitNodeId, 'EXIT_W');
    expect(plan.options[1].passesSmoke, isTrue);
    expect(plan.blocked, contains('LIFT'));
  });

  test('at the Lab 212 door (already in smoke): the nearest way out of the smoke is stair W', () {
    final plan = planner.plan('D_LAB', hazards, mode: IncidentMode.fire);
    expect(plan.options.first.exitNodeId, 'EXIT_W');
    expect(plan.options.first.distanceM, closeTo(21.9, 0.05));
  });

  test('turn-by-turn text', () {
    final steps = buildSteps(floor, ['C05', 'C06', 'C07', 'C08', 'EXIT_E']);
    expect(steps.map((s) => s.text), [
      'เดิน 15 ม. แล้วเลี้ยวซ้ายที่โถงหน้าบันได E',
      'เดินต่อ 6 ม. ถึงบันไดหนีไฟ E',
    ]);
  });

  test('no incident: the lift is still not offered as an exit, nothing is blocked by hazard', () {
    final plan = planner.plan('C05', const {}, mode: IncidentMode.none);
    expect(plan.options.first.exitNodeId, 'EXIT_E');
    expect(plan.options.any((o) => o.passesSmoke), isFalse);
  });

  test('off-route distance', () {
    final route = ['C05', 'C06', 'C07', 'C08', 'EXIT_E'];
    expect(planner.distanceToRoute(const P(30, 0), route), closeTo(0, 0.01));
    expect(planner.distanceToRoute(const P(30, -6), route), closeTo(6, 0.01));
  });
}
