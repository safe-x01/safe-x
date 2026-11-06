import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// One row of NOTIFICATION_INBOX (page 05).
///
/// The table has only title + body, so the extra lines a card shows are kept inside
/// [body], one per line, marked with a tag:
///   "✓ ..."      green check chip      (e.g. "✓ ยืนยันโดย MQ-2 และกล้อง AI")
///   "[pill] ..." yellow status pill    (e.g. "[pill] เจ้าหน้าที่กำลังเข้าช่วยเหลือ")
///   "[meta] ..." small grey line       (e.g. "[meta] ความมั่นใจ 91%")
///   "[link] ..." blue link text        (e.g. "[link] ดูรายละเอียด")
/// Lines without a tag are the normal body text.
class AppNotice {
  final String id;
  final String? incidentId;
  final String category; // incident / person / info / report / channel
  final String title;
  final String body;
  final String priority; // critical / high / info / low
  final DateTime receivedAt;
  final DateTime? readAt;

  const AppNotice({
    required this.id,
    required this.incidentId,
    required this.category,
    required this.title,
    required this.body,
    required this.priority,
    required this.receivedAt,
    required this.readAt,
  });

  bool get isRead => readAt != null;
  bool get isEmergency => priority == 'critical' || priority == 'high';

  List<String> get _lines => body.split('\n');
  String get text =>
      _lines.where((l) => !l.startsWith('✓ ') && !l.startsWith('[')).join('\n');
  String? _tag(String prefix) {
    for (final l in _lines) {
      if (l.startsWith(prefix)) return l.substring(prefix.length).trim();
    }
    return null;
  }

  String? get check => _tag('✓ ');
  String? get pill => _tag('[pill]');
  String? get meta => _tag('[meta]');
  String? get link => _tag('[link]');

  static AppNotice fromRow(Map<String, Object?> r) => AppNotice(
        id: r['notification_id'] as String,
        incidentId: r['incident_id'] as String?,
        category: r['category'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        priority: r['priority'] as String,
        receivedAt: DateTime.parse(r['received_at'] as String),
        readAt: r['read_at'] == null
            ? null
            : DateTime.parse(r['read_at'] as String),
      );
}

class NotificationRepository {
  NotificationRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<AppNotice>> all() async {
    final rows =
        await _db.db.query('NOTIFICATION_INBOX', orderBy: 'received_at DESC');
    return rows.map(AppNotice.fromRow).toList();
  }

  Future<String> add({
    required String category,
    required String title,
    required String body,
    required String priority,
    String? incidentId,
    DateTime? receivedAt,
  }) async {
    final id = _uuid.v4();
    await _db.db.insert('NOTIFICATION_INBOX', {
      'notification_id': id,
      'incident_id': incidentId,
      'category': category,
      'title': title,
      'body': body,
      'priority': priority,
      'received_at': (receivedAt ?? DateTime.now()).toIso8601String(),
      'read_at': null,
    });
    return id;
  }

  Future<void> markRead(String id) => _db.db.update(
        'NOTIFICATION_INBOX',
        {'read_at': DateTime.now().toIso8601String()},
        where: 'notification_id = ? AND read_at IS NULL',
        whereArgs: [id],
      );

  /// Demo mode only: empty the inbox and put the sample cards of Figma page 05 back.
  /// Remove when push from the server is connected.
  Future<void> resetDemo() async {
    await _db.db.delete('NOTIFICATION_INBOX');
    final now = DateTime.now();
    await add(
      category: 'person',
      title: 'ตรวจพบคนล้ม',
      body:
          'โถงกลาง ชั้น 2 จากกล้อง AI\n[pill] เจ้าหน้าที่กำลังเข้าช่วยเหลือ\n[meta] ความมั่นใจ 91% นิ่งนาน 6 วินาที',
      priority: 'high',
      receivedAt: now.subtract(const Duration(minutes: 5)),
    );
    await add(
      category: 'info',
      title: 'ลิฟต์งดใช้งานชั่วคราว',
      body: 'ระหว่างเหตุฉุกเฉิน กรุณาใช้บันไดหนีไฟ\n[link] ดูรายละเอียด',
      priority: 'info',
      receivedAt: now.subtract(const Duration(minutes: 12)),
    );
    await add(
      category: 'report',
      title: 'รายงานของคุณได้รับการยืนยัน',
      body:
          'น้ำรั่วที่ห้องน้ำ ชั้น 2 ซ่อมเสร็จแล้ว\nขอบคุณที่ช่วยให้ทุกคนปลอดภัย',
      priority: 'low',
      receivedAt: now.subtract(const Duration(hours: 1)),
    );
    await add(
      category: 'channel',
      title: 'ส่งเข้า Telegram แล้ว',
      body: 'กลุ่ม ICT Safety ถึง 128 คน ใน 318 ms',
      priority: 'low',
      receivedAt: now.subtract(const Duration(hours: 2)),
    );
  }
}
