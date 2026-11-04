import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';
import '../navigation/route_planner.dart';

/// Page 02 (user) / ad02 (admin). Same layout as the Figma screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenMap});
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _Header(s: s),
        const SizedBox(height: 16),
        _LocationCard(s: s),
        if (s.incident != IncidentMode.none) ...[
          const SizedBox(height: 12),
          _IncidentBanner(s: s, onOpenMap: onOpenMap),
        ],
        const SizedBox(height: 20),
        _SectionTitle('เหตุการณ์ในอาคาร',
            action: 'ดูทั้งหมด',
            onAction: () => _todo(context, 'หน้า 05 แจ้งเตือน')),
        const SizedBox(height: 10),
        _IncidentCounts(s: s),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _SosCard(s: s)),
          const SizedBox(width: 12),
          Expanded(
              child: _ReportCard(
                  onTap: () => _todo(context, 'หน้า 04 รายงานเหตุ'))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _QuickAction(
                  icon: Icons.navigation_rounded,
                  color: SA.teal,
                  label: 'เส้นทางปลอดภัย',
                  onTap: () {
                    if (s.plan == null) s.replan();
                    onOpenMap();
                  })),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.call,
                  color: SA.red,
                  label: 'เบอร์ฉุกเฉิน',
                  onTap: () => _emergencyNumbers(context))),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.groups_rounded,
                  color: SA.blue,
                  label: 'จุดรวมพล',
                  onTap: () => _assembly(context))),
        ]),
        if (s.isAdmin) ...[
          const SizedBox(height: 20),
          const _SectionTitle('งานของผู้ดูแล'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: saCard(),
            child: const Text(
                'ad02: รายงานรอตรวจ · สถานะอพยพ · อุปกรณ์ · ส่งประกาศ (ยังไม่ได้เขียน)',
                style: TextStyle(color: SA.text2)),
          ),
        ],
        const SizedBox(height: 20),
        const _SectionTitle('สถานะเซนเซอร์ ชั้น 2', pill: 'ออนไลน์ 24/24'),
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
            label: const Text('เดโม: จำลองเหตุไฟไหม้ห้อง 203',
                style: TextStyle(color: SA.muted)),
          ),
        ],
      ],
    );
  }

  static void _todo(BuildContext context, String what) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$what ยังไม่ได้เขียน')));

  static void _emergencyNumbers(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => const _InfoSheet(title: 'เบอร์ฉุกเฉิน', lines: [
          ('ห้องควบคุม รปภ. อาคาร ICT', '02-xxx-xxxx ต่อ 1234'),
          ('ดับเพลิง / กู้ภัย', '199'),
          ('การแพทย์ฉุกเฉิน', '1669'),
        ]),
      );

  static void _assembly(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (_) => const _InfoSheet(title: 'จุดรวมพล', lines: [
          ('ลานหน้าอาคาร ICT', 'ห่างประมาณ 120 เมตร · ทางบันได E'),
        ]),
      );
}

// ---------------------------------------------------------------- header
class _Header extends StatelessWidget {
  const _Header({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? 'สวัสดีตอนเช้า'
        : (hour < 17 ? 'สวัสดีตอนบ่าย' : 'สวัสดีตอนเย็น');
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
              const _Pill('ผู้ดูแลระบบ', SA.purple, SA.purpleLight)
            ],
          ]),
        ]),
      ),
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: SA.card,
              shape: BoxShape.circle,
              border: Border.all(color: SA.border)),
          child: const Icon(Icons.notifications_none_rounded, color: SA.text),
        ),
        if (s.incident != IncidentMode.none)
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
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ตำแหน่งปัจจุบัน',
                  style: TextStyle(color: SA.text2, fontSize: 12)),
              Text('อาคาร ICT มหาวิทยาลัยมหิดล',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
          TextButton(
            style: TextButton.styleFrom(
                backgroundColor: SA.blueLight,
                foregroundColor: SA.blue,
                visualDensity: VisualDensity.compact),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('เลือกตำแหน่งเอง ยังไม่ได้เขียน'))),
            child: const Text('เปลี่ยน',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const Divider(height: 24, color: SA.border),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _kv('ชั้น', '${s.floor.floorNumber}'),
          const SizedBox(width: 28),
          Expanded(child: _kv('โซน', zone?.name ?? 'กำลังหาตำแหน่ง…')),
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
          Text(ok ? 'BLE เชื่อมต่อแล้ว' : 'กำลังหา beacon',
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w700)),
          Text(
              ok
                  ? 'แม่นยำ ±${fix!.accuracyM.toStringAsFixed(0)} เมตร · ${fix!.beaconCount} ตัว'
                  : 'เปิดบลูทูธไว้',
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
        const Row(children: [
          Icon(Icons.warning_rounded, color: SA.red, size: 20),
          SizedBox(width: 6),
          Text('แจ้งเตือนฉุกเฉิน',
              style: TextStyle(
                  color: SA.red, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Text('ไฟไหม้ ${s.floor.zones[s.incidentZoneId]?.name ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Text('ชั้น 2 อาคาร ICT · ออกทางบันไดหนีไฟ ห้ามใช้ลิฟต์',
            style: TextStyle(color: SA.text2, fontSize: 12.5)),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: SA.red, minimumSize: const Size.fromHeight(46)),
          onPressed: onOpenMap,
          child: const Text('ดูเส้นทางอพยพ'),
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
    // TODO: count from INCIDENT_CACHE by severity once sync is connected
    final critical = s.incident == IncidentMode.none ? 0 : 1;
    return Row(children: [
      Expanded(
          child: _CountTile(
              icon: Icons.local_fire_department,
              color: SA.red,
              bg: SA.redLight,
              value: critical,
              label: 'วิกฤต')),
      const SizedBox(width: 10),
      const Expanded(
          child: _CountTile(
              icon: Icons.warning_amber_rounded,
              color: SA.amber,
              bg: SA.amberLight,
              value: 0,
              label: 'เฝ้าระวัง')),
      const SizedBox(width: 10),
      const Expanded(
          child: _CountTile(
              icon: Icons.info_rounded,
              color: SA.blue,
              bg: SA.blueLight,
              value: 0,
              label: 'ข้อมูล')),
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
  const _SosCard({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SA.red,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กดค้าง 3 วินาทีเพื่อส่ง SOS'))),
        onLongPress: () async {
          await s.sos();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ส่ง SOS แล้ว · ${s.zoneName}')));
        },
        child: const _BigCardBody(
            icon: Icons.notifications_active_outlined,
            title: 'SOS ฉุกเฉิน',
            sub: 'กดค้าง 3 วินาทีเพื่อขอช่วย'),
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
        child: const _BigCardBody(
            icon: Icons.photo_camera_outlined,
            title: 'รายงานเหตุ',
            sub: 'ถ่ายรูป แล้ว AI ช่วยตรวจ'),
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
  static const _items = [
    (Icons.local_fire_department, 'ควัน MQ-2', '210 ppm ปกติ'),
    (Icons.science_outlined, 'แก๊ส MQ-135', 'ไม่พบการรั่ว'),
    (Icons.thermostat, 'อุณหภูมิ', '27.4°C ปกติ'),
    (Icons.videocam, 'กล้อง AI', 'YOLOv8 ทำงาน'),
  ];

  @override
  Widget build(BuildContext context) {
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
          for (final it in _items)
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
