import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../main.dart';
import '../navigation/route_planner.dart';

/// Pages 03 (live map), 07 (routes A/B/C) and 11a-11d (step-by-step navigation).
/// Layout follows Figma 03_live_map.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  int _selected = 0; // 0 = route A, 1 = B ...
  bool _showBeacons = true;

  static const _walkSpeed =
      1.0; // m/s, used only for the "about N seconds" text

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final navigating = s.mode == ScanMode.navigating && s.route != null;
    final plan = s.plan;
    if (plan != null && _selected >= plan.options.length) _selected = 0;
    final RouteOption? shown = navigating
        ? s.route
        : (plan != null && plan.options.isNotEmpty
            ? plan.options[_selected]
            : null);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        _header(s),
        const SizedBox(height: 14),
        _FloorTabs(
            current: s.floor.floorNumber,
            alert: s.incident != IncidentMode.none),
        if (navigating) ...[
          const SizedBox(height: 12),
          _StepBanner(s: s),
        ] else if (s.incident != IncidentMode.none) ...[
          const SizedBox(height: 12),
          _IncidentBanner(
              s: s,
              exitLabel: shown == null
                  ? null
                  : s.d(s.floor.nodes[shown.exitNodeId]?.label ?? ''),
              onTap: () => _routesSheet(context, s)),
        ],
        const SizedBox(height: 12),
        _mapCard(s, shown),
        const SizedBox(height: 12),
        if (navigating)
          _NavCard(s: s)
        else if (shown != null)
          _routeCard(s, plan!, shown)
        else
          _normalCard(s),
      ],
    );
  }

  // ---------------------------------------------------------------- header
  Widget _header(AppState s) {
    final fix = s.fix;
    final ago = fix == null
        ? null
        : DateTime.now().difference(fix.measuredAt).inSeconds;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.tr('แผนที่อาคาร ICT', 'ICT Building map'),
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(
              ago == null
                  ? s.tr('กำลังหาตำแหน่ง…', 'Locating…')
                  : s.tr(
                      'อัปเดตล่าสุด $ago วินาทีที่แล้ว', 'Updated $ago s ago'),
              style: const TextStyle(color: SA.text2, fontSize: 12.5)),
        ]),
      ),
      Material(
        color: SA.card,
        shape: const CircleBorder(side: BorderSide(color: SA.border)),
        child: IconButton(
          tooltip: _showBeacons
              ? s.tr('ซ่อน beacon', 'Hide beacons')
              : s.tr('แสดง beacon', 'Show beacons'),
          icon: Icon(Icons.layers_outlined,
              color: _showBeacons ? SA.text : SA.muted),
          onPressed: () => setState(() => _showBeacons = !_showBeacons),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- map
  Widget _mapCard(AppState s, RouteOption? shown) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: saCard(),
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: CustomPaint(
              painter:
                  FloorPainter(s, route: shown, showBeacons: _showBeacons)),
        ),
        const SizedBox(height: 10),
        Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Legend(
                  kind: _LegendKind.dot,
                  color: SA.blue,
                  label: s.tr('คุณ', 'You')),
              _Legend(
                  kind: _LegendKind.dash,
                  color: SA.teal,
                  label: s.tr('เส้นทาง', 'Route')),
              _Legend(
                  kind: _LegendKind.square,
                  color: SA.red,
                  label: s.tr('จุดเกิดเหตุ', 'Incident')),
              _Legend(
                  kind: _LegendKind.square,
                  color: SA.teal,
                  label: s.tr('ทางออก', 'Exit')),
              const _Legend(
                  kind: _LegendKind.smallDot, color: SA.teal, label: 'beacon'),
            ]),
        const SizedBox(height: 6),
        Text(
            s.tr('ข้อมูลแผนที่ถูกเก็บไว้ในเครื่อง ใช้งานได้เมื่อออฟไลน์',
                'Map is stored on the phone, works offline'),
            style: const TextStyle(color: SA.muted, fontSize: 11)),
      ]),
    );
  }

  // ---------------------------------------------------------------- bottom cards
  Widget _routeCard(AppState s, RoutePlan plan, RouteOption o) {
    final exit = s.floor.nodes[o.exitNodeId]!;
    final steps = buildSteps(s.floor, o.nodeIds);
    final secs = (o.distanceM / _walkSpeed).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: SA.navy, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                const BoxDecoration(color: SA.teal, shape: BoxShape.circle),
            child: const Icon(Icons.near_me, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.d(exit.label),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              Text(
                s.tr('ระยะ ${o.distanceM.toStringAsFixed(0)} เมตร ใช้เวลาประมาณ $secs วินาที',
                        '${o.distanceM.toStringAsFixed(0)} m · about $secs seconds') +
                    (o.passesSmoke
                        ? s.tr(' · ผ่านควัน', ' · through smoke')
                        : ''),
                style: TextStyle(
                    color: o.passesSmoke
                        ? const Color(0xFFFCD34D)
                        : const Color(0xCCFFFFFF),
                    fontSize: 12.5),
              ),
            ]),
          ),
        ]),
        if (plan.options.length > 1) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < plan.options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _routeChip(i, plan.options[i])),
            ],
          ]),
        ],
        const Divider(height: 24, color: Color(0x33FFFFFF)),
        for (var i = 0; i < math.min(3, steps.length); i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0x33FFFFFF),
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(s.stepText(steps[i]),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13))),
            ]),
          ),
        const SizedBox(height: 4),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: SA.teal,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => s.startNavigation(_selected),
          child: Text(s.tr('เริ่มนำทาง', 'Start navigation'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _routeChip(int i, RouteOption o) {
    final sel = i == _selected;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selected = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Colors.white : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${AppScope.of(context).tr('เส้นทาง', 'Route')} ${String.fromCharCode(65 + i)} · ${o.distanceM.toStringAsFixed(0)} ${AppScope.of(context).tr('ม.', 'm')}',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: sel ? SA.navy : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _normalCard(AppState s) {
    // no incident: show the nearest exit so the user knows the way out anyway
    final fix = s.fix;
    RouteOption? nearest;
    if (fix != null) {
      final p = s.planner.plan(s.planner.nearestNode(fix.pos), s.floor.hazards,
          mode: IncidentMode.none);
      if (p.options.isNotEmpty) nearest = p.options.first;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: saCard(),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(color: SA.greenLight, shape: BoxShape.circle),
          child: const Icon(Icons.verified_user_outlined, color: SA.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.tr('ไม่มีเหตุการณ์ในชั้นนี้', 'No incidents on this floor'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(
              nearest == null
                  ? s.tr('กำลังหาตำแหน่งจาก BLE…', 'Locating with BLE…')
                  : '${s.tr('ทางออกใกล้สุด', 'Nearest exit')}: ${s.d(s.floor.nodes[nearest.exitNodeId]!.label)} · ${nearest.distanceM.toStringAsFixed(0)} ${s.tr('ม.', 'm')}',
              style: const TextStyle(color: SA.text2, fontSize: 12.5),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Page 07 as a sheet: all routes + exits that must not be used.
  void _routesSheet(BuildContext context, AppState s) {
    final plan = s.plan;
    if (plan == null) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.tr('เส้นทางที่ระบบแนะนำ', 'Suggested routes'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (var i = 0; i < plan.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _selected = i);
                        Navigator.pop(c);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: saCard(
                            color: i == _selected ? SA.tealLight : SA.card,
                            border: i == _selected ? SA.teal : SA.border),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: i == 0 ? SA.teal : SA.amber,
                            child: Text(String.fromCharCode(65 + i),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  s.d(s.floor.nodes[plan.options[i].exitNodeId]!
                                      .label),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          Text(
                            '${plan.options[i].distanceM.toStringAsFixed(0)} ${s.tr('ม.', 'm')}${plan.options[i].passesSmoke ? s.tr(' · ผ่านควัน', ' · smoke') : ''}',
                            style: TextStyle(
                                color: plan.options[i].passesSmoke
                                    ? SA.amberDark
                                    : SA.text2),
                          ),
                        ]),
                      ),
                    ),
                  ),
                for (final b in plan.blocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: saCard(
                        color: SA.redLight, border: const Color(0xFFF6C3C3)),
                    child: Row(children: [
                      const Icon(Icons.close, color: SA.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              '${s.d(s.floor.nodes[b]?.label ?? b)} · ${s.tr('ห้ามใช้', 'do not use')}',
                              style: const TextStyle(
                                  color: SA.redDark,
                                  fontWeight: FontWeight.w700))),
                    ]),
                  ),
              ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- floor tabs
class _FloorTabs extends StatelessWidget {
  const _FloorTabs({required this.current, required this.alert});
  final int current;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: saCard(),
      child: Row(children: [
        for (var f = 1; f <= 4; f++)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: f == current
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(AppScope.of(context).tr(
                                'ยังไม่มีผังชั้น $f (ขอบเขตโปรเจกต์: ชั้น 2)',
                                'No map for floor $f yet (project scope: floor 2)'))),
                      ),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: f == current ? SA.navy : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Stack(clipBehavior: Clip.none, children: [
                  Text(AppScope.of(context).tr('ชั้น $f', 'Floor $f'),
                      style: TextStyle(
                          color: f == current ? Colors.white : SA.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  if (f == current && alert)
                    Positioned(
                      right: -10,
                      top: -2,
                      child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: SA.red, shape: BoxShape.circle)),
                    ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- incident banner
class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner(
      {required this.s, required this.exitLabel, required this.onTap});
  final AppState s;
  final String? exitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final what = switch (s.incident) {
      IncidentMode.fire => s.tr('ไฟไหม้', 'Fire in'),
      IncidentMode.gas => s.tr('แก๊สรั่ว', 'Gas leak in'),
      IncidentMode.quake => s.tr('แผ่นดินไหว', 'Earthquake'),
      IncidentMode.none => '',
    };
    final where = s.d(s.floor.zones[s.incidentZoneId]?.name ?? '');
    return Material(
      color: const Color(0xFFFFF1F1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF6C3C3))),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration:
                  const BoxDecoration(color: SA.red, shape: BoxShape.circle),
              child:
                  const Icon(Icons.local_fire_department, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$what $where · ${s.d(s.floor.label)}',
                        style: const TextStyle(
                            color: SA.redDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text(
                        exitLabel == null
                            ? s.tr('ห้ามใช้ลิฟต์', 'Do not use the lift')
                            : s.tr('ออกทาง${exitLabel}ทันที · ห้ามใช้ลิฟต์',
                                'Leave via $exitLabel now · do not use the lift'),
                        style: const TextStyle(color: SA.red, fontSize: 12.5)),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: SA.redDark),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- navigation (11a-11d)
class _StepBanner extends StatelessWidget {
  const _StepBanner({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final step = s.steps.isEmpty ? null : s.steps[s.stepIndex];
    final icon = switch (step?.turn) {
      'left' => Icons.turn_left,
      'right' => Icons.turn_right,
      'arrive' => Icons.flag,
      _ => Icons.straight,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: s.arrived ? SA.green : SA.navy,
          borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(s.arrived ? Icons.check_circle : icon,
            color: Colors.white, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            s.arrived
                ? s.tr(
                    'ถึง${s.d(s.floor.nodes[s.route!.exitNodeId]!.label)}แล้ว',
                    'You reached ${s.d(s.floor.nodes[s.route!.exitNodeId]!.label)}')
                : (step == null ? '' : s.stepText(step)),
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: SA.navy, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          s.arrived
              ? s.tr('ถึงทางออกแล้ว', 'You reached the exit')
              : s.tr('เหลือ ${s.remainingMeters.toStringAsFixed(0)} เมตร',
                  '${s.remainingMeters.toStringAsFixed(0)} m to go'),
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
            '${s.tr('ขั้นที่', 'Step')} ${s.stepIndex + 1}/${s.steps.length} · ${s.d(s.floor.nodes[s.route!.exitNodeId]!.label)}',
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
        const SizedBox(height: 14),
        if (s.arrived)
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: SA.green,
                minimumSize: const Size.fromHeight(50)),
            onPressed: s.imSafe,
            child: Text(s.tr('ฉันปลอดภัย', 'I’m safe'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          )
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x66FFFFFF)),
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: s.stopNavigation,
            child: Text(s.tr('หยุดนำทาง', 'Stop navigation')),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- legend
enum _LegendKind { dot, smallDot, dash, square }

class _Legend extends StatelessWidget {
  const _Legend({required this.kind, required this.color, required this.label});
  final _LegendKind kind;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final mark = switch (kind) {
      _LegendKind.dot => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      _LegendKind.smallDot => Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      _LegendKind.square => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      _LegendKind.dash => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
                width: 4,
                height: 3,
                margin: const EdgeInsets.only(right: 2),
                color: color),
        ]),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(
              fontSize: 11.5, color: SA.text2, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ---------------------------------------------------------------- painter
/// Draws the floor from ZONE_CACHE polygons in the Figma style: rounded room tiles,
/// one merged corridor, exits in teal, the incident room in red, the lift crossed out,
/// a dashed route and the user dot. Metres -> pixels, y up (north at the top).
class FloorPainter extends CustomPainter {
  FloorPainter(this.s, {this.route, this.showBeacons = true})
      : super(repaint: s);
  final AppState s;
  final RouteOption? route;
  final bool showBeacons;

  @override
  void paint(Canvas canvas, Size size) {
    final f = s.floor;
    var minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (final z in f.zones.values) {
      for (final p in z.polygon) {
        minX = math.min(minX, p.x);
        maxX = math.max(maxX, p.x);
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    const pad = 6.0;
    final scale = math.min((size.width - 2 * pad) / (maxX - minX),
        (size.height - 2 * pad) / (maxY - minY));
    final ox = (size.width - (maxX - minX) * scale) / 2,
        oy = (size.height - (maxY - minY) * scale) / 2;
    Offset px(P p) =>
        Offset(ox + (p.x - minX) * scale, oy + (maxY - p.y) * scale);
    Rect rectOf(Zone z) {
      final pts = z.polygon.map(px).toList();
      var l = pts.first.dx, r = l, t = pts.first.dy, b = t;
      for (final o in pts) {
        l = math.min(l, o.dx);
        r = math.max(r, o.dx);
        t = math.min(t, o.dy);
        b = math.max(b, o.dy);
      }
      return Rect.fromLTRB(l, t, r, b);
    }

    // building outline
    final outer = Rect.fromLTWH(
        ox - pad + 2,
        oy - pad + 2,
        (maxX - minX) * scale + 2 * pad - 4,
        (maxY - minY) * scale + 2 * pad - 4);
    canvas.drawRRect(RRect.fromRectAndRadius(outer, const Radius.circular(10)),
        Paint()..color = const Color(0xFFEEF2F7));
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFCBD5E1),
    );

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final incidentOn = s.incident != IncidentMode.none;
    final exitZoneId =
        route == null ? null : f.nodes[route!.exitNodeId]?.zoneId;

    // corridor: one long tile, smoke tinted on top
    final corridors =
        f.zones.values.where((z) => z.type == 'corridor').toList();
    if (corridors.isNotEmpty) {
      var cr = rectOf(corridors.first);
      for (final z in corridors) {
        cr = cr.expandToInclude(rectOf(z));
      }
      final rr =
          RRect.fromRectAndRadius(cr.deflate(2), const Radius.circular(6));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFFF8FAFC));
      canvas.save();
      canvas.clipRRect(rr);
      for (final z in corridors) {
        if (z.hazardLevel >= Hazard.watch) {
          canvas.drawRect(
              rectOf(z),
              Paint()
                ..color = z.hazardLevel >= Hazard.smoke
                    ? const Color(0x66FDE68A)
                    : const Color(0x33FDE68A));
        }
      }
      canvas.restore();
      canvas.drawRRect(rr, border..color = const Color(0xFFDDE3EA));
      _text(canvas, s.tr('โถงกลาง', 'Corridor'), cr.center, cr.width, 10.5,
          SA.muted);
    }

    // rooms, stairs, lift
    for (final z in f.zones.values) {
      if (z.type == 'corridor') continue;
      final r = rectOf(z).deflate(2.5);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
      Color fill = SA.card, line = const Color(0xFFDDE3EA), label = SA.text;
      var name = s.d(z.name);
      if (z.type == 'stairs') {
        final chosen = z.id == exitZoneId;
        fill = chosen ? SA.teal : SA.tealLight;
        line = SA.teal;
        label = chosen ? Colors.white : SA.teal;
        if (chosen)
          name = '${s.tr('ทางออก', 'Exit')} ${z.name.split(' ').last}';
      } else if (z.type == 'lift' && incidentOn) {
        fill = SA.redLight;
        line = SA.red;
        label = SA.red;
      }
      if (z.hazardLevel >= Hazard.blocked) {
        fill = const Color(0xFFFDE8E8);
        line = const Color(0xFFF19A9A);
        label = SA.redDark;
      } else if (z.hazardLevel >= Hazard.smoke) {
        fill = SA.amberLight;
        line = SA.amber;
      }
      canvas.drawRRect(rr, Paint()..color = fill);
      canvas.drawRRect(rr, border..color = line);

      if (z.hazardLevel >= Hazard.blocked) {
        // fire tile: halo + icon above the label
        final c = r.center - Offset(0, r.height * 0.12);
        canvas.drawCircle(c, math.min(r.width, r.height) * 0.32,
            Paint()..color = const Color(0x33E5484D));
        _icon(canvas, Icons.local_fire_department, c, 18, SA.red);
        _text(canvas, name, Offset(r.center.dx, r.bottom - 12), r.width - 6,
            10.5, label,
            bold: true);
      } else if (z.type == 'lift' && incidentOn) {
        _text(canvas, name, r.center - const Offset(0, 8), r.width - 6, 10.5,
            label,
            bold: true);
        _icon(canvas, Icons.close, r.center + const Offset(0, 9), 16, SA.red);
      } else if (z.type == 'stairs' && z.id == exitZoneId) {
        _icon(canvas, Icons.stairs, r.center - const Offset(0, 9), 20,
            Colors.white);
        _text(canvas, name, r.center + const Offset(0, 11), r.width - 6, 10.5,
            label,
            bold: true);
      } else {
        _text(canvas, name, r.center, r.width - 6, 10.5, label, bold: true);
      }
    }

    // beacons
    if (showBeacons) {
      for (final b in f.beacons.values) {
        canvas.drawCircle(px(b.pos), 2.6, Paint()..color = SA.teal);
      }
    }

    // route (dashed)
    final r = route;
    if (r != null && r.nodeIds.length > 1) {
      final path = Path();
      final fix = s.fix;
      final pts = [
        if (fix != null) px(fix.pos),
        ...r.nodeIds.map((id) => px(f.nodes[id]!.pos)),
      ];
      path.moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      _dashed(
        canvas,
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = SA.teal
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // user
    final fix = s.fix;
    if (fix != null) {
      final c = px(fix.pos);
      final halo = math.min(fix.accuracyM * scale, 26.0);
      canvas.drawCircle(
          c, math.max(halo, 12), Paint()..color = const Color(0x262F6FED));
      canvas.drawCircle(c, 8, Paint()..color = Colors.white);
      canvas.drawCircle(c, 6, Paint()..color = SA.blue);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint,
      {double dash = 6, double gap = 5}) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  void _text(Canvas c, String t, Offset center, double maxWidth, double size,
      Color color,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(
              fontSize: size,
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              height: 1.15)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(maxWidth, 10));
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _icon(Canvas c, IconData icon, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
            fontSize: size,
            color: color,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FloorPainter old) => true;
}
