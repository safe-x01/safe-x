import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';
import 'login_screen.dart';

/// Page 08: โปรไฟล์ (tab "เพิ่มเติม"). Reads and saves LOCAL_PROFILE through AppState.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;
    final roleLabel = switch (s.role) {
      UserRole.student => t('นักศึกษา / บุคลากร', 'Student / Staff'),
      UserRole.security => t('เจ้าหน้าที่ความปลอดภัย', 'Safety officer'),
      UserRole.admin => t('ผู้ดูแลระบบ', 'Administrator'),
    };
    final (sent, confirmed, drills) = s.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        // ---------------------------------------------------------------- title
        Row(children: [
          Expanded(
              child: Text(t('โปรไฟล์', 'Profile'),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800))),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: SA.text,
              backgroundColor: SA.card,
              side: const BorderSide(color: SA.border),
              shape: const StadiumBorder(),
            ),
            onPressed: () =>
                _todo(context, t('แก้ไขโปรไฟล์', 'Edit profile'), s),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(t('แก้ไข', 'Edit'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),

        // ---------------------------------------------------------------- navy card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: SA.navy, borderRadius: BorderRadius.circular(20)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  s.displayName.characters.first,
                  style: const TextStyle(
                      color: SA.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.displayName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        s.email.isEmpty ? '-' : s.email,
                        style: const TextStyle(
                            color: Color(0xFFBFD3E6), fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(roleLabel),
              if (s.employeeCode.isNotEmpty)
                _chip('${t('รหัส', 'ID')} ${s.employeeCode}'),
              _chip(t('คณะ ICT', 'Faculty of ICT')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // ---------------------------------------------------------------- stats
        Row(children: [
          Expanded(
              child:
                  _stat('$sent', t('รายงานที่ส่ง', 'Reports sent'), SA.text)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat(
                  '$confirmed', t('ได้รับการยืนยัน', 'Confirmed'), SA.teal)),
          const SizedBox(width: 10),
          Expanded(
              child: _stat('$drills', t('ซ้อมอพยพ', 'Evacuations'), SA.text)),
        ]),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------- emergency contacts
        _section(t('ติดต่อฉุกเฉิน', 'Emergency contacts')),
        Container(
          decoration: saCard(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _contact(Icons.call_outlined, SA.green, SA.greenLight,
                t('เบอร์ของฉัน', 'My phone'), s.phone ?? '08x-xxx-xxxx'),
            const Divider(height: 1, color: SA.border),
            _contact(
              Icons.person_add_alt_1_outlined,
              SA.red,
              SA.redLight,
              t('ผู้ติดต่อกรณีฉุกเฉิน', 'Emergency contact'),
              s.emergencyContact ??
                  t('[ชื่อผู้ปกครอง] · 08x-xxx-xxxx',
                      '[Guardian name] · 08x-xxx-xxxx'),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------- settings
        _section(t('การตั้งค่า', 'Settings')),
        Container(
          decoration: saCard(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _switch(
              t('แจ้งเตือนเหตุฉุกเฉิน', 'Emergency alerts'),
              t('เสียงดังแม้อยู่ในโหมดเงียบ', 'Sound even in silent mode'),
              s.alertSound,
              s.setAlertSound,
            ),
            const Divider(height: 1, color: SA.border),
            _switch(
              t('ระบุตำแหน่งด้วย BLE', 'Indoor location (BLE)'),
              t('ใช้นำทางอพยพ แม่นยำ ±1.5 เมตร',
                  'Used for evacuation routes, ±1.5 m'),
              s.bleEnabled,
              s.setBleEnabled,
            ),
            const Divider(height: 1, color: SA.border),
            _link(t('ประวัติรายงานของฉัน', 'My reports'),
                onTap: () =>
                    _todo(context, t('ประวัติรายงาน', 'My reports'), s)),
            const Divider(height: 1, color: SA.border),
            _link(
              t('ภาษา', 'Language'),
              trailing: s.lang == 'en' ? 'English' : 'ไทย',
              onTap: () => _languageSheet(context, s),
            ),
            const Divider(height: 1, color: SA.border),
            _link(t('ความเป็นส่วนตัวและข้อมูล', 'Privacy & data'),
                onTap: () =>
                    _todo(context, t('ความเป็นส่วนตัว', 'Privacy'), s)),
          ]),
        ),
        const SizedBox(height: 20),

        // ---------------------------------------------------------------- logout
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: SA.red,
            backgroundColor: SA.card,
            side: const BorderSide(color: Color(0xFFF6C3C3), width: 1.5),
            minimumSize: const Size.fromHeight(52),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _logout(context, s),
          child: Text(t('ออกจากระบบ', 'Log out'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- pieces
  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0x26FFFFFF),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );

  Widget _stat(String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: saCard(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: SA.text2, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _contact(
          IconData icon, Color fg, Color bg, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: fg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(color: SA.text2, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
            ]),
          ),
        ]),
      );

  Widget _switch(String title, String sub, bool value,
          Future<void> Function(bool) onChanged) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14.5)),
              Text(sub, style: const TextStyle(color: SA.text2, fontSize: 12)),
            ]),
          ),
          Switch(
              value: value,
              activeColor: Colors.white,
              activeTrackColor: SA.teal,
              onChanged: onChanged),
        ]),
      );

  Widget _link(String title, {String? trailing, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5))),
            if (trailing != null)
              Text(trailing, style: const TextStyle(color: SA.muted)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: SA.muted),
          ]),
        ),
      );

  // ---------------------------------------------------------------- actions
  void _todo(BuildContext context, String what, AppState s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('$what ${s.tr('ยังไม่ได้เขียน', 'is not built yet')}')));

  void _languageSheet(BuildContext context, AppState s) {
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.tr('เลือกภาษา', 'Choose language'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final (code, label) in const [
                  ('th', 'ไทย'),
                  ('en', 'English')
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.pop(c);
                        await s.setLanguage(code);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: saCard(
                          color: s.lang == code ? SA.blueLight : SA.card,
                          border: s.lang == code ? SA.blue : SA.border,
                        ),
                        child: Row(children: [
                          Expanded(
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700))),
                          Icon(
                            s.lang == code
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: s.lang == code ? SA.blue : SA.muted,
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.tr('ออกจากระบบ?', 'Log out?')),
        content: Text(s.tr('แอปจะหยุดหาตำแหน่ง และกลับไปหน้าเข้าสู่ระบบ',
            'The app will stop locating you and go back to the login screen.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s.tr('ยกเลิก', 'Cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SA.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.tr('ออกจากระบบ', 'Log out')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await s.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
