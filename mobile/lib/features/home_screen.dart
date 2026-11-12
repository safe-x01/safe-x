import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';
import '../navigation/route_planner.dart';
import 'report_screen.dart';
import 'sos_screen.dart';

/// Page 02 (user) / ad02 (admin). Same layout as the Figma screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen(
      {super.key, required this.onOpenMap, required this.onOpenNotifications});
  final VoidCallback onOpenMap;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _Header(s: s, onBell: onOpenNotifications),
        const SizedBox(height: 16),
        _LocationCard(s: s),
        if (s.incident != IncidentMode.none) ...[
          const SizedBox(height: 12),
          _IncidentBanner(s: s, onOpenMap: onOpenMap),
        ],
        const SizedBox(height: 20),
        _SectionTitle(t('เหตุการณ์ในอาคาร', 'Incidents in the building'),
            action: t('ดูทั้งหมด', 'See all'), onAction: onOpenNotifications),
        const SizedBox(height: 10),
        _IncidentCounts(s: s),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SosCard(s: s, onOpenMap: onOpenMap)),
          const SizedBox(width: 12),
          Expanded(
              child: _ReportCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ReportScreen())))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _QuickAction(
                  icon: Icons.navigation_rounded,
                  color: SA.teal,
                  label: t('เส้นทางปลอดภัย', 'Safe route'),
                  onTap: () {
                    if (s.plan == null) s.replan();
                    onOpenMap();
                  })),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.call,
                  color: SA.red,
                  label: t('เบอร์ฉุกเฉิน', 'Emergency numbers'),
                  onTap: () => _emergencyNumbers(context, s))),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.groups_rounded,
                  color: SA.blue,
                  label: t('จุดรวมพล', 'Assembly point'),
                  onTap: () => _assembly(context, s))),
        ]),
        if (s.isAdmin) ...[
          const SizedBox(height: 20),
          _SectionTitle(t('งานของผู้ดูแล', 'Staff tasks')),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: saCard(),
            child: Text(
                t('ad02: รายงานรอตรวจ · สถานะอพยพ · อุปกรณ์ · ส่งประกาศ (ยังไม่ได้เขียน)',
                    'ad02: reports to review · evacuation status · devices · broadcast (not built yet)'),
                style: const TextStyle(color: SA.text2)),
          ),
        ],
        const SizedBox(height: 20),
        _SectionTitle(t('สถานะเซนเซอร์ ชั้น 2', 'Sensors · Floor 2'),
            pill: t('ออนไลน์ 24/24', 'Online 24/24')),
        const SizedBox(height: 10),
        const _SensorGrid(),
        if (s.incident == IncidentMode.none) ...[
          const SizedBox(height: 16),
          // demo only: remove when push from the Edge Server is connected
          TextButton.icon(
            onPressed: () async {
              await s.simulateFire();
              onOpenMap();
            },
            icon: const Icon(Icons.science_outlined, size: 18, color: SA.muted),
            label: Text(
                t('เดโม: จำลองเหตุไฟไหม้ห้อง 203',
                    'Demo: simulate a fire in Room 203'),
                style: const TextStyle(color: SA.muted)),
          ),
        ],
      ],
    );
  }

  static void _emergencyNumbers(BuildContext context, AppState s) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => _InfoSheet(
            title: s.tr('เบอร์ฉุกเฉิน', 'Emergency numbers'),
            lines: [
              (
                s.tr('ห้องควบคุม รปภ. อาคาร ICT', 'ICT Building security room'),
                s.tr('02-xxx-xxxx ต่อ 1234', '02-xxx-xxxx ext. 1234')
              ),
              (s.tr('ดับเพลิง / กู้ภัย', 'Fire / rescue'), '199'),
              (s.tr('การแพทย์ฉุกเฉิน', 'Ambulance'), '1669'),
            ]),
      );

  static void _assembly(BuildContext context, AppState s) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) =>
            _InfoSheet(title: s.tr('จุดรวมพล', 'Assembly point'), lines: [
          (
            s.tr('ลานหน้าอาคาร ICT', 'Front yard of the ICT Building'),
            s.tr('ห่างประมาณ 120 เมตร · ทางบันได E',
                'About 120 m · via stairs E')
          ),
        ]),
      );
}

// ---------------------------------------------------------------- header
class _Header extends StatelessWidget {
  const _Header({required this.s, required this.onBell});
  final AppState s;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? s.tr('สวัสดีตอนเช้า', 'Good morning')
        : (hour < 17
            ? s.tr('สวัสดีตอนบ่าย', 'Good afternoon')
            : s.tr('สวัสดีตอนเย็น', 'Good evening'));
    return Row(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: SA.navy,
        child: Text(s.displayName.characters.first,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greet, style: const TextStyle(color: SA.text2, fontSize: 13)),
          Row(children: [
            Text(s.displayName,
                style:
                    const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            if (s.isAdmin) ...[
              const SizedBox(width: 8),
              _Pill(s.tr('เจ้าหน้าที่', 'Staff'), SA.purple, SA.purpleLight)
            ],
          ]),
        ]),
      ),
      Stack(clipBehavior: Clip.none, children: [
        Material(
          color: SA.card,
          shape: const CircleBorder(side: BorderSide(color: SA.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBell,
            child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.notifications_none_rounded, color: SA.text)),
          ),
        ),
        if (s.unreadCount > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: SA.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2))),
          ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- location (LOCATION_FIX)
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final fix = s.fix;
    final zone = fix == null ? null : s.floor.zones[fix.zoneId];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: saCard(),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.location_on, color: SA.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.tr('ตำแหน่งปัจจุบัน', 'Current location'),
                  style: const TextStyle(color: SA.text2, fontSize: 12)),
              Text(
                  s.tr('อาคาร ICT มหาวิทยาลัยมหิดล',
                      'ICT Building, Mahidol University'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: SA.blueLight,
                foregroundColor: SA.blue,
                visualDensity: VisualDensity.compact),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(s.tr('เลือกตำแหน่งเอง ยังไม่ได้เขียน',
                        'Pick location manually is not built yet')))),
            child: Text(s.tr('เปลี่ยน', 'Change'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const Divider(height: 24, color: SA.border),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _kv(s.tr('ชั้น', 'Floor'), '${s.floor.floorNumber}'),
          const SizedBox(width: 28),
          Expanded(
              child: _kv(
                  s.tr('โซน', 'Zone'),
                  zone == null
                      ? s.tr('กำลังหาตำแหน่ง…', 'Locating…')
                      : s.d(zone.name))),
          _BlePill(s: s),
        ]),
      ]),
    );
  }

  Widget _kv(String k, String v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(color: SA.text2, fontSize: 12)),
        Text(v,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            overflow: TextOverflow.ellipsis),
      ]);
}

class _BlePill extends StatelessWidget {
  const _BlePill({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final fix = s.fix;
    final ok = fix != null && !s.lostSignal;
    final fg = ok ? SA.green : SA.amberDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: ok ? SA.greenLight : SA.amberLight,
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              ok
                  ? s.tr('BLE เชื่อมต่อแล้ว', 'BLE connected')
                  : s.tr('กำลังหา beacon', 'Looking for beacons'),
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          Text(
              ok
                  ? s.tr(
                      'แม่นยำ ±${fix!.accuracyM.toStringAsFixed(0)} เมตร · ${fix!.beaconCount} ตัว',
                      '±${fix!.accuracyM.toStringAsFixed(0)} m · ${fix!.beaconCount} beacons')
                  : s.tr('เปิดบลูทูธไว้', 'Keep Bluetooth on'),
              style: const TextStyle(color: SA.text2, fontSize: 10.5)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- incident banner (INCIDENT_CACHE)
class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner({required this.s, required this.onOpenMap});
  final AppState s;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: saCard(
          color: const Color(0xFFFFF5F5), border: const Color(0xFFF6C3C3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_rounded, color: SA.red, size: 20),
          const SizedBox(width: 6),
          Text(s.tr('แจ้งเตือนฉุกเฉิน', 'Emergency alert'),
              style: const TextStyle(
                  color: SA.red, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Text(
            '${s.tr('ไฟไหม้', 'Fire in')} ${s.d(s.floor.zones[s.incidentZoneId]?.name ?? '')}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(
            s.tr('ชั้น 2 อาคาร ICT · ออกทางบันไดหนีไฟ ห้ามใช้ลิฟต์',
                'Floor 2, ICT Building · use the fire stairs, not the lift'),
            style: const TextStyle(color: SA.text2, fontSize: 12.5)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: SA.red, minimumSize: const Size.fromHeight(46)),
          onPressed: onOpenMap,
          child: Text(s.tr('ดูเส้นทางอพยพ', 'View evacuation route')),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- counts
class _IncidentCounts extends StatelessWidget {
  const _IncidentCounts({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    // counted from NOTIFICATION_INBOX by priority
    return Row(children: [
      Expanded(
          child: _CountTile(
              icon: Icons.local_fire_department,
              color: SA.red,
              bg: SA.redLight,
              value: s.countPriority('critical'),
              label: s.tr('วิกฤต', 'Critical'))),
      const SizedBox(width: 10),
      Expanded(
          child: _CountTile(
              icon: Icons.warning_amber_rounded,
              color: SA.amber,
              bg: SA.amberLight,
              value: s.countPriority('high'),
              label: s.tr('เฝ้าระวัง', 'Watch'))),
      const SizedBox(width: 10),
      Expanded(
          child: _CountTile(
              icon: Icons.info_rounded,
              color: SA.blue,
              bg: SA.blueLight,
              value: s.countPriority('info'),
              label: s.tr('ข้อมูล', 'Info'))),
    ]);
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.value,
      required this.label});
  final IconData icon;
  final Color color, bg;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: saCard(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                color: SA.text2, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- big action cards
class _SosCard extends StatelessWidget {
  const _SosCard({required this.s, required this.onOpenMap});
  final AppState s;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SA.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        // page 10: send SOS, then show the overlay (it has "ยกเลิก SOS" in case of a mistaken tap)
        onTap: () async {
          await s.sos();
          if (!context.mounted) return;
          final goMap = await Navigator.of(context)
              .push<bool>(MaterialPageRoute(builder: (_) => const SosScreen()));
          if (goMap == true) {
            s.replan();
            onOpenMap();
          }
        },
        child: _BigCardBody(
            icon: Icons.notifications_active_outlined,
            title: s.tr('SOS ฉุกเฉิน', 'Emergency SOS'),
            sub: s.tr('กดเพื่อขอความช่วยเหลือ', 'Tap to ask for help')),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SA.teal,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: _BigCardBody(
            icon: Icons.photo_camera_outlined,
            title: AppScope.of(context).tr('รายงานเหตุ', 'Report'),
            sub: AppScope.of(context)
                .tr('ถ่ายรูป แล้ว AI ช่วยตรวจ', 'Take a photo, AI checks it')),
      ),
    );
  }
}

class _BigCardBody extends StatelessWidget {
  const _BigCardBody(
      {required this.icon, required this.title, required this.sub});
  final IconData icon;
  final String title, sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(46), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 28),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5)),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SA.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SA.border)),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sensors
class _SensorGrid extends StatelessWidget {
  const _SensorGrid();

  // TODO: these come from the Edge Server (DEVICE + SENSOR_READING) — fixed sample values for now
  @override
  Widget build(BuildContext context) {
    final t = AppScope.of(context).tr;
    final items = [
      (
        Icons.local_fire_department,
        t('ควัน MQ-2', 'Smoke MQ-2'),
        t('210 ppm ปกติ', '210 ppm normal')
      ),
      (
        Icons.science_outlined,
        t('แก๊ส MQ-135', 'Gas MQ-135'),
        t('ไม่พบการรั่ว', 'No leak')
      ),
      (
        Icons.thermostat,
        t('อุณหภูมิ', 'Temperature'),
        t('27.4°C ปกติ', '27.4°C normal')
      ),
      (
        Icons.videocam,
        t('กล้อง AI', 'AI camera'),
        t('YOLOv8 ทำงาน', 'YOLOv8 running')
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: saCard(),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
        children: [
          for (final it in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                      color: SA.tealLight, shape: BoxShape.circle),
                  child: Icon(it.$1, color: SA.teal, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$2,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        Text(it.$3,
                            style: const TextStyle(
                                fontSize: 11,
                                color: SA.green,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- small pieces
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.action, this.onAction, this.pill});
  final String text;
  final String? action, pill;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(text,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      if (action != null)
        GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    color: SA.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
      if (pill != null) _Pill(pill!, SA.green, SA.greenLight),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.fg, this.bg);
  final String text;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.title, required this.lines});
  final String title;
  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final l in lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: SelectableText(l.$2),
                ),
            ]),
      ),
    );
  }
}
