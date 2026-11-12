import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ble/beacon_scanner.dart';
import 'core/config.dart';
import 'core/i18n.dart';
import 'data/db/app_database.dart';
import 'data/models.dart';
import 'data/repositories/map_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/outbox_repository.dart';
import 'data/repositories/profile_repository.dart';
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
  String email = '';
  String employeeCode = '';
  String? phone;
  String? emergencyContact;

  // settings (LOCAL_PROFILE), changed on page 08
  late ProfileRepository profiles;
  String lang = 'th'; // th / en
  bool bleEnabled = true;
  bool alertSound = true;

  /// Profile tiles: reports sent / reports confirmed / evacuations finished.
  (int, int, int) stats = (0, 0, 0);
  Future<void> refreshStats() async {
    stats = await profiles.stats();
    notifyListeners();
  }

  /// Picks the text for the current language: tr('หน้าหลัก', 'Home').
  String tr(String th, String en) => lang == 'en' ? en : th;

  /// Same for text that comes from data (zone names, notifications): ไทย -> English via core/i18n.dart.
  String d(String th) => lang == 'en' ? translateData(th) : th;

  /// Language can also be picked on the login screen, before anyone is logged in.
  void setLanguageLocal(String l) {
    lang = l;
    notifyListeners();
  }

  /// One navigation step as text in the current language (the planner keeps turn / metres / node).
  String stepText(NavStep st) {
    final m = st.meters.round();
    final at = d(floor.nodes[st.atNodeId]?.label ?? st.atNodeId);
    if (st.turn == 'arrive')
      return tr('เดินต่อ $m ม. ถึง$at', 'Walk $m m to $at');
    if (st.turn == 'left')
      return tr('เดิน $m ม. แล้วเลี้ยวซ้ายที่$at',
          'Walk $m m, then turn left at $at');
    if (st.turn == 'right')
      return tr('เดิน $m ม. แล้วเลี้ยวขวาที่$at',
          'Walk $m m, then turn right at $at');
    return d(st.text);
  }

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
    s.profiles = ProfileRepository(db);
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
  Future<void> login(UserRole r, String name, {String email = ''}) async {
    role = r;
    displayName = name;
    this.email = email;
    final p = await profiles.loadOrCreate(
        userId: email.isEmpty ? name : email,
        displayName: name,
        role: r.name,
        email: email);
    displayName = p['display_name'] as String;
    employeeCode = p['employee_code'] as String;
    phone = p['phone'] as String?;
    emergencyContact = p['emergency_contact'] as String?;
    // the language chosen on the login screen wins and is saved for next time
    await profiles.update(email.isEmpty ? name : email, {'language': lang});
    bleEnabled = p['ble_enabled'] == 1;
    alertSound = p['alert_sound'] == 1;
    stats = await profiles.stats();
    notifyListeners();
    if (bleEnabled) await startScanning();
  }

  String get _userId => email.isEmpty ? displayName : email;

  /// Page 08b "แก้ไขโปรไฟล์": saves name, phone and emergency contact into LOCAL_PROFILE.
  /// The emergency contact is kept in one column as "name · phone".
  Future<void> updateProfile({
    required String name,
    required String phone,
    required String contactName,
    required String contactPhone,
  }) async {
    final contact =
        [contactName, contactPhone].where((x) => x.isNotEmpty).join(' · ');
    final id =
        _userId; // read before the name changes (the id can be the name when there is no email)
    displayName = name;
    this.phone = phone.isEmpty ? null : phone;
    emergencyContact = contact.isEmpty ? null : contact;
    await profiles.update(id, {
      'display_name': name,
      'phone': this.phone,
      'emergency_contact': emergencyContact,
    });
    notifyListeners();
  }

  Future<void> setLanguage(String l) async {
    lang = l;
    await profiles.update(_userId, {'language': l});
    notifyListeners();
  }

  Future<void> setAlertSound(bool on) async {
    alertSound = on;
    await profiles.update(_userId, {'alert_sound': on ? 1 : 0});
    notifyListeners();
  }

  /// Turning BLE off stops scanning; the location card then shows "กำลังหา beacon".
  Future<void> setBleEnabled(bool on) async {
    bleEnabled = on;
    await profiles.update(_userId, {'ble_enabled': on ? 1 : 0});
    if (on) {
      await startScanning(fast: mode != ScanMode.normal);
    } else {
      await _scanSub?.cancel();
      _scanSub = null;
      await scanner.stop();
      fix = null;
    }
    notifyListeners();
  }

  /// Figma has 2 roles: user and เจ้าหน้าที่ความปลอดภัย; the staff role uses the admin screens (ad02-ad14).
  bool get isAdmin => role == UserRole.security || role == UserRole.admin;

  /// Page 08 "ออกจากระบบ": stop scanning and clear this session, back to a clean state.
  /// TODO: when real login exists, also delete the token from flutter_secure_storage.
  Future<void> logout() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await scanner.stop();
    // clear the incident (demo hazards go back to normal)
    for (final z in floor.zones.values) {
      if (z.hazardLevel != Hazard.normal) {
        z.hazardLevel = Hazard.normal;
        await maps.setHazard(z.id, Hazard.normal);
      }
    }
    incident = IncidentMode.none;
    incidentZoneId = null;
    plan = null;
    route = null;
    steps = const [];
    stepIndex = 0;
    arrived = false;
    mode = ScanMode.normal;
    fix = null;
    _lastHeard = null;
    role = UserRole.student;
    displayName = 'ผู้ใช้';
    email = '';
    if (AppConfig.useSimulatedBeacons) await notices.resetDemo();
    inbox = await notices.all();
    notifyListeners();
  }

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
      ? tr('กำลังหาตำแหน่ง…', 'Locating…')
      : d(floor.zones[fix!.zoneId]?.name ?? fix!.zoneId);

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
    unawaited(refreshStats());
    stopNavigation();
  }

  /// When the last SOS was sent (page 10 shows it); null after "ยกเลิก SOS".
  DateTime? sosSentAt;

  Future<void> sos({String? message}) async {
    sosSentAt = DateTime.now();
    await outbox.addAck(
        ackStatus: 'sos', zoneId: fix?.zoneId, message: message);
    unawaited(sync.pushOutbox());
    if (mode == ScanMode.normal) {
      mode = ScanMode.incident;
      await startScanning(fast: true);
    }
    notifyListeners();
  }

  /// Page 10 "ยกเลิก SOS": tells the server it was a mistake (the outbox sends it after the SOS row).
  Future<void> cancelSos() async {
    sosSentAt = null;
    await outbox.addAck(ackStatus: 'cancel_sos', zoneId: fix?.zoneId);
    unawaited(sync.pushOutbox());
    if (incident == IncidentMode.none && mode == ScanMode.incident) {
      mode = ScanMode.normal;
      await startScanning();
    }
    notifyListeners();
  }

  Future<String> sendReport({
    required String type,
    required String severity,
    String? description,
    List<String> photoPaths = const [],
  }) async {
    final id = await outbox.addReport(
      reportType: type,
      severity: severity,
      description: description,
      photoPaths: photoPaths,
      zoneId: fix?.zoneId,
      posX: fix?.pos.x,
      posY: fix?.pos.y,
    );
    unawaited(sync.pushOutbox());
    unawaited(refreshStats());
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
