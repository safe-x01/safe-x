import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../core/config.dart';
import '../data/db/app_database.dart';
import '../data/models.dart';
import '../data/repositories/outbox_repository.dart';

/// Talks to the Edge Server REST API.
///   GET  /sync/static?floor_id=&version=   -> floor package (same JSON as assets/maps/floor2.json)
///   GET  /sync/incidents?since_seq=        -> {"incidents":[...], "notifications":[...], "hazards":{zone_id:level}, "seq": n}
///   POST /reports   (body has client_uuid) -> 201 / 409 (already have it)
///   POST /acks      (body has client_uuid) -> 201 / 409
///   PUT  /me/location                      -> 204
/// The server side is not written yet: the paths and bodies here are the contract to build it against.
class SyncService {
  SyncService(this._db, this._outbox, {http.Client? client, FlutterSecureStorage? secure, this.baseUrl = AppConfig.serverBaseUrl})
      : _http = client ?? http.Client(),
        _secure = secure ?? const FlutterSecureStorage();

  final AppDatabase _db;
  final OutboxRepository _outbox;
  final http.Client _http;
  final FlutterSecureStorage _secure;
  final String baseUrl;
  Timer? _retry;
  int _failStreak = 0;

  Future<Map<String, String>> _headers() async {
    final token = await _secure.read(key: 'access_token');
    return {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  /// Sends every pending ACK (SOS first) then every pending report.
  /// On failure it tries again after 2, 4, 8 ... up to 60 seconds.
  Future<void> pushOutbox() async {
    _retry?.cancel();
    var allOk = true;
    for (final row in await _outbox.pendingAcks()) {
      allOk &= await _send('ACK_OUTBOX', '/acks', row);
    }
    for (final row in await _outbox.pendingReports()) {
      allOk &= await _send('REPORT_OUTBOX', '/reports', row);
    }
    if (allOk) {
      _failStreak = 0;
    } else {
      _failStreak++;
      final wait = math.min(AppConfig.maxRetryBackoffSec, 1 << _failStreak);
      _retry = Timer(Duration(seconds: wait), pushOutbox);
    }
  }

  Future<bool> _send(String table, String path, Map<String, Object?> row) async {
    final id = row['client_uuid'] as String;
    try {
      final res = await _http
          .post(Uri.parse('$baseUrl$path'), headers: await _headers(), body: jsonEncode(row))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 201 || res.statusCode == 200 || res.statusCode == 409) {
        String? serverId;
        if (res.body.isNotEmpty) {
          final body = jsonDecode(res.body);
          if (body is Map) serverId = body['id'] as String?;
        }
        await _outbox.markSent(table, id, serverId: serverId);
        return true;
      }
      await _outbox.markFailed(table, id, 'HTTP ${res.statusCode}');
    } catch (e) {
      await _outbox.markFailed(table, id, e.toString());
    }
    return false;
  }

  /// Pulls only what is newer than SYNC_STATE.last_seq. Returns the hazard map it received.
  Future<Map<String, int>> pullIncidents() async {
    final st = await _db.db.query('SYNC_STATE', where: 'entity = ?', whereArgs: ['incident'], limit: 1);
    final since = st.isEmpty ? 0 : st.first['last_seq'] as int;
    final res = await _http
        .get(Uri.parse('$baseUrl/sync/incidents?since_seq=$since'), headers: await _headers())
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final hazards = <String, int>{};
    await _db.db.transaction((txn) async {
      for (final i in (body['incidents'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        await AppDatabase.put(txn, 'INCIDENT_CACHE', 'incident_id', {
          'incident_id': i['id'],
          'zone_id': i['zone_id'],
          'incident_type': i['incident_type'],
          'severity': i['severity'],
          'status': i['status'],
          'confidence_score': i['confidence_score'],
          'detected_at': i['detected_at'],
          'confirmed_at': i['confirmed_at'],
          'resolved_at': i['resolved_at'],
          'server_seq': i['seq'],
        }); // other tables point at incidents, so update-then-insert, never REPLACE
      }
      for (final n in (body['notifications'] as List? ?? const []).cast<Map<String, dynamic>>()) {
        await txn.insert('NOTIFICATION_INBOX', {
          'notification_id': n['id'],
          'incident_id': n['incident_id'],
          'category': n['category'],
          'title': n['title'],
          'body': n['body'],
          'priority': n['priority'],
          'received_at': DateTime.now().toIso8601String(),
          'read_at': null,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      final hz = (body['hazards'] as Map<String, dynamic>? ?? const {});
      for (final e in hz.entries) {
        hazards[e.key] = (e.value as num).toInt();
        await txn.update('ZONE_CACHE', {'hazard_level': hazards[e.key], 'hazard_updated_at': DateTime.now().toIso8601String()},
            where: 'zone_id = ?', whereArgs: [e.key]);
      }
      final seq = (body['seq'] as num?)?.toInt() ?? since;
      final changed = await txn.update('SYNC_STATE', {'last_seq': seq, 'last_sync_at': DateTime.now().toIso8601String(), 'last_status': 'ok'},
          where: 'entity = ?', whereArgs: ['incident']);
      if (changed == 0) {
        await txn.insert('SYNC_STATE', {'entity': 'incident', 'last_seq': seq, 'last_version': null, 'last_sync_at': DateTime.now().toIso8601String(), 'last_status': 'ok'});
      }
    });
    return hazards;
  }

  /// Sends only the latest position (the server keeps no walking history).
  Future<void> uploadLocation(LocationFix fix) async {
    try {
      final res = await _http
          .put(Uri.parse('$baseUrl/me/location'),
              headers: await _headers(),
              body: jsonEncode({
                'zone_id': fix.zoneId,
                'floor_id': fix.floorId,
                'accuracy_m': fix.accuracyM,
                'method': fix.method,
                'location_at': fix.measuredAt.toIso8601String(),
              }))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode < 300) {
        await _db.db.rawUpdate('UPDATE LOCATION_FIX SET uploaded = 1 WHERE measured_at = ?', [fix.measuredAt.toIso8601String()]);
      }
    } catch (_) {
      // offline: try again with the next fix
    }
  }

  void dispose() {
    _retry?.cancel();
    _http.close();
  }
}
