import '../db/app_database.dart';

/// LOCAL_PROFILE: the logged-in user and their settings (page 08).
/// One row per user, keyed by user_id (the email until real login returns an id).
class ProfileRepository {
  ProfileRepository(this._db);
  final AppDatabase _db;

  /// Returns the stored row, creating it with default settings the first time.
  Future<Map<String, Object?>> loadOrCreate({
    required String userId,
    required String displayName,
    required String role,
    required String email,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.db.transaction((txn) async {
      await AppDatabase.put(
        txn,
        'LOCAL_PROFILE',
        'user_id',
        {
          'user_id': userId,
          'employee_code': _codeFrom(email),
          'display_name': displayName,
          'role': role,
          'email': email,
          'updated_at': now,
        },
        // settings are only set on the first login; later logins keep what the user chose
        insertOnly: {
          'language': 'th',
          'ble_enabled': 1,
          'alert_sound': 1,
          'phone': null,
          'emergency_contact': null
        },
      );
    });
    final rows = await _db.db.query('LOCAL_PROFILE',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    return rows.first;
  }

  Future<void> update(String userId, Map<String, Object?> values) =>
      _db.db.update(
        'LOCAL_PROFILE',
        {...values, 'updated_at': DateTime.now().toIso8601String()},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

  /// Numbers for the 3 tiles: reports sent, reports confirmed, evacuations finished ("ฉันปลอดภัย").
  Future<(int, int, int)> stats() async {
    Future<int> count(String sql) async {
      final r = await _db.db.rawQuery(sql);
      return (r.first.values.first as int?) ?? 0;
    }

    final sent = await count('SELECT COUNT(*) FROM REPORT_OUTBOX');
    final confirmed = await count(
        "SELECT COUNT(*) FROM NOTIFICATION_INBOX WHERE category = 'report'");
    final drills = await count(
        "SELECT COUNT(*) FROM ACK_OUTBOX WHERE ack_status = 'safe'");
    return (sent, confirmed, drills);
  }

  /// "u6587xxx@student.mahidol.ac.th" -> "6587xxx"
  static String _codeFrom(String email) {
    final local = email.split('@').first;
    return local.startsWith(RegExp(r'u\d')) ? local.substring(1) : local;
  }
}
