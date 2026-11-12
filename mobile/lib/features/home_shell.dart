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
    final unread = AppScope.of(context).unreadCount;
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
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'หน้าหลัก'),
          const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'แผนที่'),
          const NavigationDestination(
              icon: CircleAvatar(
                  backgroundColor: SA.red,
                  child: Text('SOS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              label: 'ฉุกเฉิน'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'แจ้งเตือน',
          ),
          const NavigationDestination(
              icon: Icon(Icons.menu), label: 'เพิ่มเติม'),
        ],
      ),
    );
  }

  /// Page 10: SOS goes into ACK_OUTBOX (sent first) with the current zone.
  Future<void> _sos(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ส่ง SOS?'),
        content: const Text('ระบบจะส่งตำแหน่งของคุณให้เจ้าหน้าที่ทันที'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('ยกเลิก')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: SA.red, minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ส่ง SOS')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final s = AppScope.of(context);
    await s.sos();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('ส่ง SOS แล้ว · ${s.zoneName}')));
  }
}
