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

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final t = s.tr;
    final roles = [
      (
        UserRole.student,
        t('นักศึกษา / บุคลากร', 'Student / Staff'),
        t('รับแจ้งเตือน รายงานเหตุ และอพยพ',
            'Get alerts, report incidents, evacuate'),
        Icons.person,
        SA.blue,
        SA.blueLight
      ),
      (
        UserRole.security,
        t('เจ้าหน้าที่ความปลอดภัย', 'Safety officer'),
        t('ติดตามและตอบสนองเหตุการณ์', 'Monitor and respond to incidents'),
        Icons.shield,
        SA.teal,
        SA.tealLight
      ),
    ];
    return Scaffold(
      backgroundColor: SA.navy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(alignment: Alignment.centerRight, child: _LangToggle(s: s)),
            const Icon(Icons.verified_user, color: Colors.white, size: 56),
            const SizedBox(height: 12),
            const Text('SafeAlert ICT',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
            Text(
                t('แจ้งเตือนภัยในอาคารแบบเรียลไทม์',
                    'Real-time indoor safety alerts'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBFD3E6), fontSize: 14)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: SA.bg, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t('ยินดีต้อนรับ', 'Welcome'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _email,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.mail_outline))),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline))),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: SA.navy),
                    onPressed: _login,
                    child: Text(t('เข้าสู่ระบบ', 'Log in')),
                  ),
                  const SizedBox(height: 16),
                  Text(t('เลือกบทบาทของคุณ', 'Choose your role'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SA.muted)),
                  const SizedBox(height: 8),
                  for (final r in roles) _roleCard(r),
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
          decoration: saCard(
              color: selected ? SA.blueLight : SA.card,
              border: selected ? SA.blue : SA.border),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: r.$6, borderRadius: BorderRadius.circular(10)),
              child: Icon(r.$4, color: r.$5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(r.$3,
                        style: const TextStyle(color: SA.text2, fontSize: 12)),
                  ]),
            ),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? SA.blue : SA.muted),
          ]),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final en = AppScope.of(context).lang == 'en';
    final name = switch (_role) {
      UserRole.student => en ? 'Pakinthorn' : 'ภคินธร',
      UserRole.security || UserRole.admin => en ? 'Piti' : 'ปิติ',
    };
    await AppScope.of(context).login(_role, name, email: _email.text.trim());
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }
}

/// ไทย | EN switch on the login screen (saved to the profile when the user logs in).
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    Widget item(String code, String label) {
      final on = s.lang == code;
      return GestureDetector(
        onTap: () => s.setLanguageLocal(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: on ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style: TextStyle(
                  color: on ? SA.navy : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x66FFFFFF))),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [item('th', 'ไทย'), item('en', 'EN')]),
    );
  }
}
