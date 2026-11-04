import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';
import 'home_shell.dart';

/// Page 01 (01a / 01b / 01c): pick a role and log in.
/// TODO: call POST /auth/login and save the token with flutter_secure_storage.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  UserRole _role = UserRole.student;
  final _email = TextEditingController(text: 'u6587xxx@student.mahidol.ac.th');
  final _password = TextEditingController(text: '••••••••');

  static const _roles = [
    (UserRole.student, 'นักศึกษา / บุคลากร', 'รับแจ้งเตือน รายงานเหตุ และอพยพ', Icons.person, SA.blue, SA.blueLight),
    (UserRole.security, 'เจ้าหน้าที่ความปลอดภัย', 'ติดตามและตอบสนองเหตุการณ์', Icons.shield, SA.teal, SA.tealLight),
    (UserRole.admin, 'ผู้ดูแลอาคาร', 'จัดการ Sensor และระบบ IoT', Icons.admin_panel_settings, SA.amberDark, SA.amberLight),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SA.navy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.verified_user, color: Colors.white, size: 56),
            const SizedBox(height: 12),
            const Text('SafeAlert ICT',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const Text('แจ้งเตือนภัยในอาคารแบบเรียลไทม์',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFBFD3E6), fontSize: 14)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: SA.bg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ยินดีต้อนรับ', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(controller: _email, decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline))),
                  const SizedBox(height: 8),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline))),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: SA.navy),
                    onPressed: _login,
                    child: const Text('เข้าสู่ระบบ'),
                  ),
                  const SizedBox(height: 16),
                  const Text('เลือกบทบาทของคุณ', textAlign: TextAlign.center, style: TextStyle(color: SA.muted)),
                  const SizedBox(height: 8),
                  for (final r in _roles) _roleCard(r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard((UserRole, String, String, IconData, Color, Color) r) {
    final selected = _role == r.$1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _role = r.$1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: saCard(color: selected ? SA.blueLight : SA.card, border: selected ? SA.blue : SA.border),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: r.$6, borderRadius: BorderRadius.circular(10)),
              child: Icon(r.$4, color: r.$5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(r.$3, style: const TextStyle(color: SA.text2, fontSize: 12)),
              ]),
            ),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? SA.blue : SA.muted),
          ]),
        ),
      ),
    );
  }

  void _login() {
    final name = switch (_role) { UserRole.student => 'ภคินธร', UserRole.security => 'สมชาย', UserRole.admin => 'ปิติ' };
    AppScope.of(context).login(_role, name);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }
}
