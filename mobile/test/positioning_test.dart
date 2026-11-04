import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:safealert/ble/ibeacon.dart';
import 'package:safealert/data/floor_json.dart';
import 'package:safealert/data/models.dart';
import 'package:safealert/positioning/positioning_engine.dart';

void main() {
  final floor = floorFromJson(File('assets/maps/floor2.json').readAsStringSync());

  /// RSSI each beacon would give at [p] with no noise (log-distance model).
  Map<String, double> idealWindow(P p) => {
        for (final b in floor.beacons.values)
          if (b.pos.dist(p) < 20) b.uid: b.rssi1m - 10 * b.pathLossN * math.log(math.max(0.5, b.pos.dist(p))) / math.ln10,
      };

  test('standing in front of room 201: zone is the middle corridor, error under 2 m', () {
    final engine = PositioningEngine(floor);
    const truth = P(28.5, 0);
    LocationFix? fix;
    var t = DateTime(2026, 11, 4, 10);
    for (var i = 0; i < 5; i++) {
      fix = engine.process(idealWindow(truth), now: t);
      t = t.add(const Duration(seconds: 1));
    }
    expect(fix, isNotNull);
    expect(fix!.zoneId, 'Z-CORR-MID');
    expect(fix.pos.dist(truth), lessThan(2.0));
    expect(fix.method, 'wcl');
  });

  test('a jump faster than walking speed is rejected', () {
    final engine = PositioningEngine(floor);
    final t0 = DateTime(2026, 11, 4, 10);
    final a = engine.process(idealWindow(const P(6, 0)), now: t0)!;
    final b = engine.process(idealWindow(const P(43, 0)), now: t0.add(const Duration(seconds: 1)))!;
    expect(b.pos.dist(a.pos), lessThan(3.1)); // stayed near the first fix
  });

  test('unknown beacons and an empty window give no fix', () {
    final engine = PositioningEngine(floor);
    expect(engine.process(const {}), isNull);
    expect(engine.process(const {'00000000-0000-0000-0000-000000000000-9-9': -50}), isNull);
  });

  test('rssi -59 at 1 m means 1 m; -84 dBm with n = 2.5 means 10 m', () {
    expect(rssiToMeters(-59, rssi1m: -59, n: 2.5), closeTo(1, 1e-9));
    expect(rssiToMeters(-84, rssi1m: -59, n: 2.5), closeTo(10, 1e-6));
  });

  test('iBeacon frame parsing', () {
    // 0x02 0x15 | UUID 44BC8758-5427-4729-B840-3AEA56C2B4FB | major 2 | minor 7 | power -59 (0xC5)
    final bytes = [
      0x02, 0x15,
      0x44, 0xBC, 0x87, 0x58, 0x54, 0x27, 0x47, 0x29, 0xB8, 0x40, 0x3A, 0xEA, 0x56, 0xC2, 0xB4, 0xFB,
      0x00, 0x02, 0x00, 0x07, 0xC5,
    ];
    final f = parseIBeacon({kAppleCompanyId: bytes});
    expect(f, isNotNull);
    expect(f!.uid, '44BC8758-5427-4729-B840-3AEA56C2B4FB-2-7');
    expect(f.measuredPower, -59);
    expect(floor.beacons.containsKey(f.uid), isTrue); // the lift beacon B07
    expect(parseIBeacon({0x0059: bytes}), isNull); // not Apple data
  });
}
