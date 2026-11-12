import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../data/repositories/notification_repository.dart';
import '../main.dart';

/// Page 05: การแจ้งเตือน. Reads NOTIFICATION_INBOX through AppState.inbox.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onOpenMap});
  final VoidCallback onOpenMap;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _onlyEmergency = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final emergencyCount = s.inbox.where((n) => n.isEmergency).length;
    final list =
        _onlyEmergency ? s.inbox.where((n) => n.isEmergency).toList() : s.inbox;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.tr('การแจ้งเตือน', 'Notifications'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          _FilterChip(
              label: s.tr('ทั้งหมด', 'All'),
              selected: !_onlyEmergency,
              color: SA.navy,
              onTap: () => setState(() => _onlyEmergency = false)),
          const SizedBox(width: 8),
          _FilterChip(
            label: '${s.tr('ฉุกเฉิน', 'Emergency')} ($emergencyCount)',
            selected: _onlyEmergency,
            color: SA.red,
            onTap: () => setState(() => _onlyEmergency = true),
          ),
        ]),
        const SizedBox(height: 14),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
                child: Text(
                    s.tr('ยังไม่มีการแจ้งเตือน', 'No notifications yet'),
                    style: const TextStyle(color: SA.muted))),
          ),
        for (final n in list) ...[
          _card(context, s, n),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, AppState s, AppNotice n) {
    return switch (n.category) {
      'incident' => _EmergencyCard(
          n: n,
          onDetail: () {
            s.markRead(n);
            widget.onOpenMap();
          },
          onAck: () => s.acknowledge(n),
        ),
      'channel' => _ChannelCard(n: n),
      _ => _NormalCard(
          n: n,
          onTap: () => s.markRead(n),
          onLink: () {
            s.markRead(n);
            _detailSheet(context, n);
          },
        ),
    };
  }

  void _detailSheet(BuildContext context, AppNotice n) {
    final s = AppScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.d(n.title),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(timeAgo(n.receivedAt, en: s.lang == 'en'),
                    style: const TextStyle(color: SA.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Text(s.d(n.text),
                    style: const TextStyle(
                        color: SA.text2, fontSize: 14, height: 1.4)),
              ]),
        ),
      ),
    );
  }
}

/// "2 นาทีที่แล้ว" style. Shared with the home screen.
String timeAgo(DateTime t, {bool suffix = false, bool en = false}) {
  final d = DateTime.now().difference(t);
  if (en) {
    final tail = suffix ? ' ago' : '';
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min$tail';
    if (d.inDays < 1) return '${d.inHours} h$tail';
    return '${t.day}/${t.month}/${t.year}';
  }
  final tail = suffix ? 'ที่แล้ว' : '';
  if (d.inMinutes < 1) return 'เมื่อสักครู่';
  if (d.inHours < 1) return '${d.inMinutes} นาที$tail';
  if (d.inDays < 1) return '${d.inHours} ชม.$tail';
  return '${t.day}/${t.month}/${t.year + 543}';
}

// ---------------------------------------------------------------- filter chips
class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color : SA.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : SA.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? Colors.white : (color == SA.red ? SA.red : SA.text),
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- emergency card (red)
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard(
      {required this.n, required this.onDetail, required this.onAck});
  final AppNotice n;
  final VoidCallback onDetail, onAck;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: saCard(
          color: const Color(0xFFFFF5F5), border: const Color(0xFFF6C3C3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_rounded, color: SA.red, size: 26),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(s.tr('แจ้งเตือนฉุกเฉิน', 'Emergency alert'),
                        style: const TextStyle(
                            color: SA.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700))),
                Text(timeAgo(n.receivedAt, suffix: true, en: s.lang == 'en'),
                    style: const TextStyle(color: SA.text2, fontSize: 12)),
              ]),
              const SizedBox(height: 2),
              Text(s.d(n.title),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              Text(s.d(n.text),
                  style: const TextStyle(color: SA.text2, fontSize: 13)),
              if (n.check != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: SA.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check, color: SA.green, size: 15),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(s.d(n.check!),
                            style: const TextStyle(
                                color: SA.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: SA.red,
                side: const BorderSide(color: SA.red, width: 1.5),
                backgroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onDetail,
              child: Text(s.tr('ดูรายละเอียด', 'View details'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: n.isRead
                ? Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: SA.greenLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle, color: SA.green, size: 18),
                      const SizedBox(width: 6),
                      Text(s.tr('รับทราบแล้ว', 'Acknowledged'),
                          style: const TextStyle(
                              color: SA.green, fontWeight: FontWeight.w700)),
                    ]),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: SA.red,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: onAck,
                    child: Text(s.tr('รับทราบ', 'Acknowledge'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- normal card (white)
class _NormalCard extends StatelessWidget {
  const _NormalCard(
      {required this.n, required this.onTap, required this.onLink});
  final AppNotice n;
  final VoidCallback onTap, onLink;

  (IconData, Color, Color) get _look => switch (n.category) {
        'person' => (Icons.add, SA.amber, SA.amberLight),
        'report' => (Icons.check, Colors.white, SA.green),
        _ => (Icons.info_outline, Colors.white, SA.blue),
      };

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final (icon, fg, bg) = _look;
    return Material(
      color: SA.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: SA.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.d(n.title),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: n.isRead
                                      ? FontWeight.w700
                                      : FontWeight.w800),
                            ),
                          ),
                          Text(timeAgo(n.receivedAt, en: s.lang == 'en'),
                              style: const TextStyle(
                                  color: SA.text2, fontSize: 12)),
                        ]),
                    const SizedBox(height: 2),
                    Text(s.d(n.text),
                        style: const TextStyle(
                            color: SA.text2, fontSize: 13, height: 1.35)),
                    if (n.pill != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: SA.amberLight,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(s.d(n.pill!),
                            style: const TextStyle(
                                color: SA.amberDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                    if (n.meta != null) ...[
                      const SizedBox(height: 8),
                      Text(s.d(n.meta!),
                          style:
                              const TextStyle(color: SA.muted, fontSize: 11.5)),
                    ],
                    if (n.link != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onLink,
                        child: Text(s.d(n.link!),
                            style: const TextStyle(
                                color: SA.blue,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- channel card (light blue)
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.n});
  final AppNotice n;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: saCard(color: SA.blueLight, border: const Color(0xFFC9DAFB)),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Color(0xFF229ED9), shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.d(n.title),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(s.d(n.text),
                style: const TextStyle(color: SA.text2, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}
