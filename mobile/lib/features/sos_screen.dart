import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart';

/// Page 10: SOS overlay, shown right after the SOS row went into ACK_OUTBOX.
/// Pops with `true` = open the evacuation map, `false` / null = stay.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  static const _countdown = 5; // seconds before the map opens by itself

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  Timer? _timer;
  int _left = _countdown;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _close(true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _close(bool goMap) {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    Navigator.of(context).pop(goMap);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;
    final sent = s.sosSentAt ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(sent.hour)}:${two(sent.minute)}:${two(sent.second)}${t(' น.', '')}';
    final acc = s.fix == null
        ? ''
        : ' (BLE ±${s.fix!.accuracyM.toStringAsFixed(1)} ${t('ม.', 'm')})';

    return Scaffold(
      backgroundColor: SA.bg,
      body: Column(children: [
        // ---------------------------------------------------------------- red top
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF06A6E), Color(0xFFC62B31)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(t('โหมดฉุกเฉิน', 'Emergency mode'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Spacer(),
                // pulsing rings + check
                SizedBox(
                  width: 200,
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) {
                      final v = _pulse.value;
                      return Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 150 + 50 * v,
                          height: 150 + 50 * v,
                          decoration: BoxDecoration(
                              color: Colors.white
                                  .withAlpha((40 * (1 - v)).round()),
                              shape: BoxShape.circle),
                        ),
                        Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                              color: Color(0x26FFFFFF), shape: BoxShape.circle),
                        ),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              color: SA.red, size: 64),
                        ),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(t('ส่ง SOS แล้ว', 'SOS sent'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  t('เจ้าหน้าที่กำลังมาช่วยคุณ\nอยู่ในที่ปลอดภัยและรอสักครู่',
                      'Staff are on their way to you.\nStay somewhere safe and wait.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xE6FFFFFF), fontSize: 14, height: 1.4),
                ),
                const Spacer(),
              ]),
            ),
          ),
        ),

        // ---------------------------------------------------------------- white sheet
        Container(
          decoration: const BoxDecoration(
            color: SA.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          transform: Matrix4.translationValues(
              0, -24, 0), // overlaps the red area like the Figma sheet
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: SA.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Container(
                decoration: saCard(),
                child: Column(children: [
                  _row(
                      Icons.location_on,
                      SA.teal,
                      SA.tealLight,
                      '${t('ตำแหน่งที่ส่งไป', 'Location sent')}$acc',
                      s.fix == null
                          ? t('ยังหาตำแหน่งไม่ได้', 'Location not found')
                          : '${s.zoneName} · ${t('ชั้น', 'Floor')} ${s.floor.floorNumber} ${t('อาคาร ICT', 'ICT Building')}'),
                  const Divider(
                      height: 1, indent: 14, endIndent: 14, color: SA.border),
                  _row(Icons.access_time, SA.blue, SA.blueLight,
                      t('เวลาที่ส่ง', 'Sent at'), time),
                  const Divider(
                      height: 1, indent: 14, endIndent: 14, color: SA.border),
                  _row(
                      Icons.send_rounded,
                      const Color(0xFF229ED9),
                      const Color(0xFFE3F2FB),
                      t('แจ้งไปที่', 'Notified'),
                      t('รปภ. คณะ + Telegram ICT Safety',
                          'Faculty security + Telegram ICT Safety')),
                ]),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _left / _countdown,
                  minHeight: 6,
                  backgroundColor: SA.redLight,
                  color: SA.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('กำลังพาไปแผนที่อพยพใน $_left วินาที…',
                    'Opening the evacuation map in $_left s…'),
                style: const TextStyle(color: SA.text2, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SA.red,
                      backgroundColor: SA.card,
                      side: const BorderSide(color: SA.red, width: 1.5),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      _timer?.cancel();
                      await s.cancelSos();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(t('ยกเลิก SOS แล้ว', 'SOS cancelled'))));
                      _close(false);
                    },
                    child: Text(t('ยกเลิก SOS', 'Cancel SOS'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SA.navy,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _close(true),
                    icon: const Icon(Icons.near_me, size: 18),
                    label: Text(t('ไปแผนที่อพยพ', 'Evacuation map'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(IconData icon, Color fg, Color bg, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(color: SA.text2, fontSize: 11.5)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}
