import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';

/// Page 04: รายงานเหตุการณ์. Saves into REPORT_OUTBOX (sent to the server when online).
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _maxChars = 300;

  String _type = 'fire'; // fire / gas / temp
  String _severity = 'high'; // low / mid / high
  final _detail = TextEditingController();
  final List<String> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;

    return Scaffold(
      backgroundColor: SA.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ---------------------------------------------------------------- top bar
            Row(children: [
              Material(
                color: SA.card,
                shape: const CircleBorder(side: BorderSide(color: SA.border)),
                child: IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => Navigator.pop(context)),
              ),
              Expanded(
                child: Column(children: [
                  Text(t('รายงานเหตุการณ์', 'Report an incident'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(
                      t('เห็นอะไรผิดปกติ แจ้งเราได้ทันที',
                          'See something wrong? Tell us now'),
                      style: const TextStyle(color: SA.text2, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 48),
            ]),
            const SizedBox(height: 18),

            // ---------------------------------------------------------------- type
            _heading(t('ประเภทเหตุการณ์', 'Incident type')),
            Row(children: [
              Expanded(
                  child: _typeCard(
                      'fire',
                      Icons.local_fire_department,
                      SA.red,
                      SA.redLight,
                      t('ไฟ / ควัน', 'Fire / smoke'),
                      t('ควัน หรือเปลวไฟ', 'Smoke or flames'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _typeCard(
                      'gas',
                      Icons.gas_meter_outlined,
                      SA.amber,
                      SA.amberLight,
                      t('แก๊สรั่ว', 'Gas leak'),
                      t('ได้กลิ่นแก๊ส', 'Smell of gas'))),
              const SizedBox(width: 10),
              Expanded(
                  child: _typeCard(
                      'temp',
                      Icons.monitor_heart_outlined,
                      SA.purple,
                      SA.purpleLight,
                      t('อุณหภูมิ', 'Heat'),
                      t('ความร้อน', 'Too hot'))),
            ]),
            const SizedBox(height: 18),

            // ---------------------------------------------------------------- detail
            _heading(t('รายละเอียด', 'Details')),
            TextField(
              controller: _detail,
              maxLines: 3,
              maxLength: _maxChars,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t('เช่น มีควันสีเทาออกจากห้อง 203 ได้กลิ่นไหม้',
                    'e.g. grey smoke coming out of Room 203, smells burnt'),
                counterText: '',
                filled: true,
                fillColor: SA.card,
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SA.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SA.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SA.teal, width: 1.5)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${_detail.text.length}/$_maxChars',
                    style: const TextStyle(color: SA.muted, fontSize: 11.5)),
              ),
            ),
            const SizedBox(height: 10),

            // ---------------------------------------------------------------- photos
            Row(children: [
              Expanded(child: _heading(t('รูปภาพ', 'Photos'))),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t('AI ช่วยตรวจจากรูป', 'AI checks the photo'),
                    style: const TextStyle(
                        color: SA.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            SizedBox(
              height: 120,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                _addPhotoBox(t('เพิ่มรูป', 'Add photo'), () => _pickPhoto(s)),
                for (final path in _photos) ...[
                  const SizedBox(width: 10),
                  _photoTile(
                      path,
                      t('รอ AI ตรวจที่เซิร์ฟเวอร์',
                          'AI will check on the server')),
                ],
              ]),
            ),
            const SizedBox(height: 18),

            // ---------------------------------------------------------------- severity
            _heading(t('ระดับความรุนแรง', 'Severity')),
            Row(children: [
              Expanded(child: _severityChip('low', t('ต่ำ', 'Low'), SA.green)),
              const SizedBox(width: 10),
              Expanded(
                  child: _severityChip(
                      'mid', t('ปานกลาง', 'Medium'), SA.amberDark)),
              const SizedBox(width: 10),
              Expanded(child: _severityChip('high', t('สูง', 'High'), SA.red)),
            ]),
            const SizedBox(height: 14),

            // ---------------------------------------------------------------- location (LOCATION_FIX)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: saCard(),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: SA.tealLight, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.location_on, color: SA.teal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('ตำแหน่งจาก BLE', 'Location from BLE'),
                            style: const TextStyle(
                                color: SA.text2, fontSize: 11.5)),
                        Text(
                          s.fix == null
                              ? t('ยังหาตำแหน่งไม่ได้',
                                  'Location not found yet')
                              : '${s.zoneName} · ${t('ชั้น', 'Floor')} ${s.floor.floorNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: s.fix == null ? SA.amberLight : SA.greenLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    s.fix == null ? t('ไม่พบ', 'None') : t('อัตโนมัติ', 'Auto'),
                    style: TextStyle(
                        color: s.fix == null ? SA.amberDark : SA.green,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ---------------------------------------------------------------- send
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SA.navy,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _sending ? null : () => _send(s),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(t('ส่งรายงาน', 'Send report'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pieces
  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _typeCard(
      String id, IconData icon, Color fg, Color bg, String title, String sub) {
    final on = _type == id;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _type = id),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFFFF5F5) : SA.card,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: on ? SA.red : SA.border, width: on ? 2 : 1),
          ),
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 26),
            ),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                textAlign: TextAlign.center),
            Text(sub,
                style: const TextStyle(color: SA.text2, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (on)
          const Positioned(
            right: 6,
            top: 6,
            child: CircleAvatar(
                radius: 10,
                backgroundColor: SA.red,
                child: Icon(Icons.check, color: Colors.white, size: 14)),
          ),
      ]),
    );
  }

  Widget _addPhotoBox(String label, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorder(color: SA.muted, radius: 14),
          child: SizedBox(
            width: 120,
            height: 120,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.photo_camera_outlined,
                  color: SA.text2, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      color: SA.text2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ]),
          ),
        ),
      );

  Widget _photoTile(String path, String aiNote) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 200,
          height: 120,
          child: Stack(fit: StackFit.expand, children: [
            Image.file(File(path), fit: BoxFit.cover),
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: () => setState(() => _photos.remove(path)),
                child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xCC0F172A),
                    child: Icon(Icons.close, color: Colors.white, size: 16)),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xCC0F172A),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: SA.amber, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(aiNote,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      );

  Widget _severityChip(String id, String label, Color color) {
    final on = _severity == id;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _severity = id),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? color.withAlpha(26) : SA.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? color : SA.border, width: on ? 2 : 1),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ---------------------------------------------------------------- actions
  Future<void> _pickPhoto(AppState s) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(s.tr('ถ่ายรูป', 'Take a photo')),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(s.tr('เลือกจากคลังรูป', 'Choose from gallery')),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker()
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (x != null && mounted) setState(() => _photos.add(x.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.tr('เปิดกล้องหรือคลังรูปไม่ได้',
              'Could not open the camera or gallery'))));
    }
  }

  Future<void> _send(AppState s) async {
    setState(() => _sending = true);
    await s.sendReport(
      type: _type,
      severity: _severity,
      description: _detail.text.trim().isEmpty ? null : _detail.text.trim(),
      photoPaths: List.of(_photos),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: SA.green, size: 48),
        title: Text(s.tr('ส่งรายงานแล้ว', 'Report sent')),
        content: Text(
          s.tr(
              'เจ้าหน้าที่จะได้รับรายงานของคุณ ถ้าตอนนี้ไม่มีเน็ต แอปจะส่งให้เองเมื่อเชื่อมต่อได้',
              'Staff will receive your report. If you are offline, the app sends it when you are back online.'),
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c),
              child: Text(s.tr('ตกลง', 'OK')))
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}

/// Dashed rounded border for the "เพิ่มรูป" box.
class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => old.color != color;
}
