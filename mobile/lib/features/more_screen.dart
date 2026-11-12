import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../main.dart';
import 'login_screen.dart';

/// Page 08 (เพิ่มเติม / โปรไฟล์). For now: profile card, menu rows and ออกจากระบบ.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final roleLabel = switch (s.role) {
      UserRole.student => 'นักศึกษา / บุคลากร',
      UserRole.security => 'เจ้าหน้าที่ความปลอดภัย',
      UserRole.admin => 'ผู้ดูแลระบบ',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text('เพิ่มเติม',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: saCard(),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: SA.navy,
              child: Text(
                s.displayName.characters.first,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.displayName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(roleLabel,
                        style: const TextStyle(color: SA.text2, fontSize: 13)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: saCard(),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            _row(context, Icons.person_outline, 'แก้ไขโปรไฟล์'),
            const Divider(height: 1, color: SA.border),
            _row(context, Icons.history, 'ประวัติรายงาน'),
            const Divider(height: 1, color: SA.border),
            _row(context, Icons.language, 'ภาษา', trailing: 'ไทย'),
            const Divider(height: 1, color: SA.border),
            _row(context, Icons.info_outline, 'เกี่ยวกับแอป', trailing: 'v0.1'),
          ]),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: SA.red,
            backgroundColor: SA.card,
            side: const BorderSide(color: SA.red, width: 1.5),
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('ออกจากระบบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, String label,
      {String? trailing}) {
    return ListTile(
      leading: Icon(icon, color: SA.text2),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null)
          Text(trailing, style: const TextStyle(color: SA.muted)),
        const Icon(Icons.chevron_right, color: SA.muted),
      ]),
      onTap: () => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label ยังไม่ได้เขียน'))),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ออกจากระบบ?'),
        content: const Text('แอปจะหยุดหาตำแหน่ง และกลับไปหน้าเข้าสู่ระบบ'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SA.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await AppScope.of(context).logout();
    if (!context.mounted) return;
    // remove every page and start again at the login screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}
