import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/config.dart';
import '../data/models.dart';
import 'ibeacon.dart';

/// One scan window: beacon uid -> average RSSI (dBm) heard in that window.
typedef ScanWindow = Map<String, double>;

abstract class BeaconScanner {
  /// Emits once per [AppConfig.scanWindow].
  Stream<ScanWindow> get windows;

  /// fast = incident / navigation mode (low latency). false = normal mode (saves battery).
  Future<void> start({bool fast = false});
  Future<void> stop();
}

/// Real scanner (Android). Reads iBeacon frames from BLE advertisements.
/// iOS hides iBeacon frames from CoreBluetooth: on iOS replace this class with a
/// CoreLocation ranging plugin that emits the same [ScanWindow] (see README).
class BlePlusBeaconScanner implements BeaconScanner {
  BlePlusBeaconScanner({this.projectUuid = AppConfig.projectUuid});
  final String projectUuid;

  final _out = StreamController<ScanWindow>.broadcast();
  final _buffer = <String, List<int>>{};
  StreamSubscription<List<ScanResult>>? _sub;
  Timer? _timer;

  @override
  Stream<ScanWindow> get windows => _out.stream;

  @override
  Future<void> start({bool fast = false}) async {
    await stop();
    _sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final f = parseIBeacon(r.advertisementData.manufacturerData);
        if (f == null || f.uuid != projectUuid) continue;
        if (r.rssi < AppConfig.minRssi) continue;
        _buffer.putIfAbsent(f.uid, () => []).add(r.rssi);
      }
    });
    await FlutterBluePlus.startScan(
      continuousUpdates: true,
      androidScanMode: fast ? AndroidScanMode.lowLatency : AndroidScanMode.balanced,
    );
    _timer = Timer.periodic(AppConfig.scanWindow, (_) => _flush());
  }

  void _flush() {
    if (_buffer.isEmpty) {
      _out.add(const {});
      return;
    }
    final w = <String, double>{};
    _buffer.forEach((uid, list) => w[uid] = list.reduce((a, b) => a + b) / list.length);
    _buffer.clear();
    _out.add(w);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    _buffer.clear();
  }
}

/// Fake scanner for the emulator and for demos: a person walks along [path]
/// at [speedMps] and hears every beacon through the log-distance model + noise.
class SimulatedBeaconScanner implements BeaconScanner {
  SimulatedBeaconScanner({
    required this.beacons,
    required this.path,
    this.speedMps = 1.2,
    this.noiseDb = 4,
    int seed = 7,
  }) : _rnd = math.Random(seed);

  final List<Beacon> beacons;
  List<P> path;
  final double speedMps, noiseDb;
  final math.Random _rnd;
  final _out = StreamController<ScanWindow>.broadcast();
  Timer? _timer;
  double _walked = 0;

  /// Where the simulated person is now (for drawing the "true" position in debug mode).
  P truePosition = const P(0, 0);

  @override
  Stream<ScanWindow> get windows => _out.stream;

  @override
  Future<void> start({bool fast = false}) async {
    await stop();
    _timer = Timer.periodic(AppConfig.scanWindow, (_) => _tick());
    _tick();
  }

  void restartAlong(List<P> newPath) {
    path = newPath;
    _walked = 0;
  }

  void _tick() {
    truePosition = _pointAt(_walked);
    _walked += speedMps * AppConfig.scanWindow.inMilliseconds / 1000;
    final w = <String, double>{};
    for (final b in beacons) {
      final d = math.max(0.5, b.pos.dist(truePosition));
      if (d > 20) continue;
      final rssi = b.rssi1m - 10 * b.pathLossN * math.log(d) / math.ln10 + _gauss() * noiseDb;
      if (rssi >= AppConfig.minRssi) w[b.uid] = rssi;
    }
    _out.add(w);
  }

  P _pointAt(double s) {
    if (path.length < 2) return path.isEmpty ? const P(0, 0) : path.first;
    var left = s;
    for (var i = 1; i < path.length; i++) {
      final seg = path[i - 1].dist(path[i]);
      if (left <= seg) {
        final t = seg == 0 ? 0.0 : left / seg;
        return P(path[i - 1].x + (path[i].x - path[i - 1].x) * t, path[i - 1].y + (path[i].y - path[i - 1].y) * t);
      }
      left -= seg;
    }
    return path.last; // stays at the end of the path
  }

  double _gauss() {
    // Box-Muller
    final u1 = math.max(1e-9, _rnd.nextDouble()), u2 = _rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}
