import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'more_screen.dart';
import 'notifications_screen.dart';

/// Bottom bar shared by user and admin: หน้าหลัก · แผนที่ · SOS · แจ้งเตือน · เพิ่มเติม.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onOpenMap: () => setState(() => _tab = 1),
        onOpenNotifications: () => setState(() => _tab = 3),
      ),
      const MapScreen(),
      const SizedBox.shrink(), // SOS is a button, not a page
      NotificationsScreen(onOpenMap: () => setState(() => _tab = 1)),
      const MoreScreen(),
    ];
    final app = AppScope.of(context);
    final unread = app.unreadCount;
    final t = app.tr;
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: SA.card,
        indicatorColor: SA.blueLight,
        onDestinationSelected: (i) {
          if (i == 2) {
            _sos(context);
          } else {
            setState(() => _tab = i);
          }
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t('หน้าหลัก', 'Home')),
          NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: t('แผนที่', 'Map')),
          NavigationDestination(
              icon: const CircleAvatar(
                  backgroundColor: SA.red,
                  child: Text('SOS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              label: t('ฉุกเฉิน', 'SOS')),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: t('แจ้งเตือน', 'Alerts'),
          ),
          NavigationDestination(
              icon: const Icon(Icons.menu), label: t('เพิ่มเติม', 'More')),
        ],
      ),
    );
  }

  /// Page 10: SOS goes into ACK_OUTBOX (sent first) with the current zone.
  Future<void> _sos(BuildContext context) async {
    final app = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(app.tr('ส่ง SOS?', 'Send SOS?')),
        content: Text(app.tr('ระบบจะส่งตำแหน่งของคุณให้เจ้าหน้าที่ทันที',
            'Your location will be sent to the safety staff right away.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(app.tr('ยกเลิก', 'Cancel'))),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: SA.red, minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: Text(app.tr('ส่ง SOS', 'Send SOS'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final s = AppScope.of(context);
    await s.sos();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${s.tr('ส่ง SOS แล้ว', 'SOS sent')} · ${s.zoneName}')));
  }
}
