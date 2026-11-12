import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../main.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'more_screen.dart';
import 'notifications_screen.dart';
import 'report_screen.dart';

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
            // centre button opens page 04 (รายงานเหตุการณ์); a direct SOS is the long-press card on the home screen
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ReportScreen()));
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
}
