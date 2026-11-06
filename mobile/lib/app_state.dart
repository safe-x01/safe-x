import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ble/beacon_scanner.dart';
import 'core/config.dart';
import 'data/db/app_database.dart';
import 'data/models.dart';
import 'data/repositories/map_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/outbox_repository.dart';
import 'navigation/route_planner.dart';
import 'positioning/positioning_engine.dart';
import 'sync/sync_service.dart';

enum UserRole { student, security, admin }

enum ScanMode { normal, incident, navigating }

/// Wires the pieces together (scanner -> positioning -> navigation -> UI / DB / server).
/// Screens read this object and call its methods; they never touch the DB directly.
class AppState extends ChangeNotifier {
  AppState._(this.db, this.maps, this.outbox, this.sync);

  final AppDatabase db;
  final MapRepository maps;
  final OutboxRepository outbox;
  final SyncService sync;

  late FloorPackage floor;
  late PositioningEngine _engine;
  late RoutePlanner planner;
  late BeaconScanner scanner;
  StreamSubscription<ScanWindow>? _scanSub;

  // page 05: NOTIFICATION_INBOX, newest first
  late NotificationRepository notices;
  List<AppNotice> inbox = const [];

  UserRole role = UserRole.student;
  String displayName = 'ผู้ใช้';
  ScanMode mode = ScanMode.normal;
  LocationFix? fix;
  DateTime? _lastHeard;
  DateTime? _lastUpload;

  // incident + navigation
  IncidentMode incident = IncidentMode.none;
  String? incidentZoneId;
  RoutePlan? plan;
  RouteOption? route;
  List<NavStep> steps = const [];
  int stepIndex = 0;
  bool arrived = false;
  DateTime? _offRouteSince;
  int rerouteCount = 0;

  static Future<AppState> create() async {
    final db = await AppDatabase.open();
    final outbox = OutboxRepository(db);
    final s =
        AppState._(db, MapRepository(db), outbox, SyncService(db, outbox));
    await s._loadFloor();
    s.notices = NotificationRepository(db);
    if (AppConfig.useSimulatedBeacons) await s.notices.resetDemo();
    s.inbox = await s.notices.all();
    return s;
  }

  Future<void> _loadFloor() async {
    const floorId = 'F2';
    if (!await db.hasFloor(floorId)) {
      // first start: import the floor bundled with the app (later: GET /sync/static)
      await db.importFloorPackage(
          await rootBundle.loadString(AppConfig.bundledFloorAsset));
    }
    floor = (await maps.loadFloor(floorId))!;
    _engine = PositioningEngine(floor);
    planner = RoutePlanner(floor);
    scanner = AppConfig.useSimulatedBeacons
        ? SimulatedBeaconScanner(
            beacons: floor.beacons.values.toList(),
            // demo walk: from Lab 212's door to the corridor in front of room 201, then stand there
            path: [
              floor.nodes['D_LAB']!.pos,
              floor.nodes['C03']!.pos,
              floor.nodes['C05']!.pos
            ],
          )
        : BlePlusBeaconScanner();
  }

  // ---------------------------------------------------------------- login
  void login(UserRole r, String name) {
    role = r;
    displayName = name;
    notifyListeners();
    startScanning();
  }

  bool get isAdmin => role == UserRole.admin;

  // ---------------------------------------------------------------- scanning
  Future<void> startScanning({bool fast = false}) async {
    await _scanSub?.cancel();
    _scanSub = scanner.windows.listen(_onWindow);
    await scanner.start(fast: fast);
  }

  Future<void> _onWindow(ScanWindow w) async {
    final now = DateTime.now();
    final f = _engine.process(w, now: now);
    if (f == null) {
      // nothing heard: after 5 s the UI offers "เลือกตำแหน่งเอง"
      notifyListeners();
      return;
    }
    _lastHeard = now;
    final zoneChanged = fix?.zoneId != f.zoneId;
    fix = f;
    await maps.saveFix(f);

    // upload: on zone change in normal mode, every 5 s during an incident
    final dueByTime = _lastUpload == null ||
        now.difference(_lastUpload!) >= AppConfig.locationUploadInIncident;
    if ((mode == ScanMode.normal && zoneChanged) ||
        (mode != ScanMode.normal && dueByTime)) {
      _lastUpload = now;
      unawaited(sync.uploadLocation(f));
    }
    if (mode == ScanMode.navigating) _updateNavigation(f, now);
    notifyListeners();
  }

  bool get lostSignal =>
      _lastHeard != null &&
      DateTime.now().difference(_lastHeard!) > const Duration(seconds: 5);

  String get zoneName => fix == null
      ? 'กำลังหาตำแหน่ง…'
      : (floor.zones[fix!.zoneId]?.name ?? fix!.zoneId);

  // ---------------------------------------------------------------- incident
  /// Demo button / push handler: "ไฟไหม้ห้อง 203, ควันในโถงหน้าห้อง 203".
  Future<void> onIncident({
    required IncidentMode type,
    required String zoneId,
    Map<String, int> hazards = const {},
  }) async {
    incident = type;
    incidentZoneId = zoneId;
    for (final e in hazards.entries) {
      floor.zones[e.key]?.hazardLevel = e.value;
      await maps.setHazard(e.key, e.value);
    }
    mode = ScanMode.incident;
    final what = switch (type) {
      IncidentMode.fire => 'ตรวจพบไฟไหม้',
      IncidentMode.gas => 'ตรวจพบแก๊สรั่ว',
      IncidentMode.quake => 'แผ่นดินไหว',
      IncidentMode.none => 'เหตุการณ์',
    };
    await notices.add(
      category: 'incident',
      title: '$what ${floor.zones[zoneId]?.name ?? zoneId}',
      body:
          '${floor.label} อาคาร ICT · ออกทางบันไดหนีไฟ ห้ามใช้ลิฟต์\n✓ ยืนยันโดย MQ-2 และกล้อง AI',
      priority: 'critical',
    );
    inbox = await notices.all();
    await startScanning(fast: true);
    replan();
  }

  // ---------------------------------------------------------------- notifications (page 05)
  int get unreadCount => inbox.where((n) => !n.isRead).length;
  int countPriority(String p) => inbox.where((n) => n.priority == p).length;

  Future<void> markRead(AppNotice n) async {
    if (n.isRead) return;
    await notices.markRead(n.id);
    inbox = await notices.all();
    notifyListeners();
  }

  /// "รับทราบ" on an emergency card: mark read and tell the server this person got the alert.
  Future<void> acknowledge(AppNotice n) async {
    await notices.markRead(n.id);
    await outbox.addAck(ackStatus: 'received', zoneId: fix?.zoneId);
    unawaited(sync.pushOutbox());
    inbox = await notices.all();
    notifyListeners();
  }

  Future<void> simulateFire() => onIncident(
        type: IncidentMode.fire,
        zoneId: 'Z-203',
        hazards: const {'Z-203': Hazard.blocked, 'Z-CORR-MID-W': Hazard.smoke},
      );

  /// Routes A / B / C from where the user is now (page 07).
  void replan() {
    final here = fix?.pos ?? floor.nodes['C05']!.pos;
    plan =
        planner.plan(planner.nearestNode(here), floor.hazards, mode: incident);
    notifyListeners();
  }

  // ---------------------------------------------------------------- navigation (pages 11a-11d)
  void startNavigation(int optionIndex) {
    final p = plan;
    if (p == null || optionIndex >= p.options.length) return;
    route = p.options[optionIndex];
    steps = buildSteps(floor, route!.nodeIds);
    stepIndex = 0;
    arrived = false;
    mode = ScanMode.navigating;
    final s = scanner;
    if (s is SimulatedBeaconScanner) {
      // the simulated person now walks the chosen route
      s.restartAlong([
        if (fix != null) fix!.pos,
        ...route!.nodeIds.map((id) => floor.nodes[id]!.pos)
      ]);
    }
    notifyListeners();
  }

  void _updateNavigation(LocationFix f, DateTime now) {
    final r = route;
    if (r == null || arrived) return;
    // arrived?
    if (f.pos.dist(floor.nodes[r.exitNodeId]!.pos) <= AppConfig.arriveMeters) {
      arrived = true;
      return;
    }
    // next step reached?
    while (stepIndex < steps.length - 1 &&
        f.pos.dist(floor.nodes[steps[stepIndex].atNodeId]!.pos) <=
            AppConfig.arriveMeters) {
      stepIndex++;
    }
    // off route for 3 s, or hazard changed -> plan again
    if (planner.distanceToRoute(f.pos, r.nodeIds) > AppConfig.offRouteMeters) {
      _offRouteSince ??= now;
      if (now.difference(_offRouteSince!) >= AppConfig.offRouteFor) {
        _offRouteSince = null;
        rerouteCount++;
        replan();
        startNavigation(0);
      }
    } else {
      _offRouteSince = null;
    }
  }

  double get remainingMeters {
    final r = route, f = fix;
    if (r == null || f == null) return 0;
    // from the user to the next step node, then along the rest of the path
    final idx = r.nodeIds
        .indexOf(steps.isEmpty ? r.exitNodeId : steps[stepIndex].atNodeId);
    var d = f.pos.dist(
        floor.nodes[r.nodeIds[idx < 0 ? r.nodeIds.length - 1 : idx]]!.pos);
    for (var i = (idx < 0 ? r.nodeIds.length - 1 : idx) + 1;
        i < r.nodeIds.length;
        i++) {
      d += floor.nodes[r.nodeIds[i - 1]]!.pos
          .dist(floor.nodes[r.nodeIds[i]]!.pos);
    }
    return d;
  }

  void stopNavigation() {
    route = null;
    steps = const [];
    mode = incident == IncidentMode.none ? ScanMode.normal : ScanMode.incident;
    notifyListeners();
  }

  // ---------------------------------------------------------------- outbox (pages 04, 10, 11d)
  Future<void> imSafe() async {
    await outbox.addAck(ackStatus: 'safe', zoneId: fix?.zoneId);
    unawaited(sync.pushOutbox());
    stopNavigation();
  }

  Future<void> sos({String? message}) async {
    await outbox.addAck(
        ackStatus: 'sos', zoneId: fix?.zoneId, message: message);
    unawaited(sync.pushOutbox());
    if (mode == ScanMode.normal) {
      mode = ScanMode.incident;
      await startScanning(fast: true);
    }
    notifyListeners();
  }

  Future<String> sendReport(
      {required String type,
      required String severity,
      String? description}) async {
    final id = await outbox.addReport(
      reportType: type,
      severity: severity,
      description: description,
      zoneId: fix?.zoneId,
      posX: fix?.pos.x,
      posY: fix?.pos.y,
    );
    unawaited(sync.pushOutbox());
    return id;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    scanner.stop();
    sync.dispose();
    super.dispose();
  }
}
