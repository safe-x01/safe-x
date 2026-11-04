import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// REPORT_OUTBOX and ACK_OUTBOX: rows made on the phone that wait to be sent.
/// Every row carries a client_uuid, so sending the same row twice never makes two rows on the server.
class OutboxRepository {
  OutboxRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Page 04 "ส่งรายงาน".
  Future<String> addReport({
    required String reportType, // fire / gas / quake
    required String severity, // low / mid / high
    String? description,
    String? zoneId, // from the latest LOCATION_FIX
    List<String> photoPaths = const [],
    String? aiLabel,
    double? aiConfidence,
    double? posX,
    double? posY,
  }) async {
    final id = _uuid.v4();
    await _db.db.insert('REPORT_OUTBOX', {
      'client_uuid': id,
      'server_report_id': null,
      'zone_id': zoneId,
      'report_type': reportType,
      'severity': severity,
      'description': description,
      'photo_paths_json': jsonEncode(photoPaths),
      'ai_label': aiLabel,
      'ai_confidence': aiConfidence,
      'pos_x': posX,
      'pos_y': posY,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'retry_count': 0,
      'last_error': null,
      'synced_at': null,
    });
    return id;
  }

  /// "ฉันปลอดภัย" / "ขอความช่วยเหลือ" / SOS.
  Future<String> addAck({
    required String ackStatus, // safe / need_help / sos / cancel_sos
    String? incidentId,
    String? zoneId,
    String? message,
  }) async {
    final id = _uuid.v4();
    await _db.db.insert('ACK_OUTBOX', {
      'client_uuid': id,
      'incident_id': incidentId,
      'zone_id': zoneId,
      'ack_status': ackStatus,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'retry_count': 0,
      'synced_at': null,
    });
    return id;
  }

  /// Rows to send now. SOS first, then other acks, then reports.
  Future<List<Map<String, Object?>>> pendingAcks() => _db.db.query(
        'ACK_OUTBOX',
        where: "sync_status IN ('pending','failed')",
        orderBy: "CASE ack_status WHEN 'sos' THEN 0 ELSE 1 END, created_at",
      );

  Future<List<Map<String, Object?>>> pendingReports() => _db.db.query(
        'REPORT_OUTBOX',
        where: "sync_status IN ('pending','failed')",
        orderBy: 'created_at',
      );

  Future<void> markSent(String table, String clientUuid, {String? serverId}) async {
    await _db.db.update(
      table,
      {
        'sync_status': 'sent',
        'synced_at': DateTime.now().toIso8601String(),
        if (table == 'REPORT_OUTBOX') 'server_report_id': serverId,
      },
      where: 'client_uuid = ?',
      whereArgs: [clientUuid],
    );
  }

  Future<void> markFailed(String table, String clientUuid, String error) async {
    await _db.db.rawUpdate(
      'UPDATE $table SET sync_status = ?, retry_count = retry_count + 1'
      '${table == 'REPORT_OUTBOX' ? ', last_error = ?' : ''} WHERE client_uuid = ?',
      [
        'failed',
        if (table == 'REPORT_OUTBOX') error,
        clientUuid,
      ],
    );
  }
}
