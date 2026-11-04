import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:safealert/data/db/app_database.dart';
import 'package:safealert/data/repositories/map_repository.dart';
import 'package:safealert/data/repositories/outbox_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the real SQLite schema on your computer (no phone needed).
void main() {
  sqfliteFfiInit();
  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.open(fileName: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });
  tearDown(() => db.close());

  test('creates the 14 tables', () async {
    final rows = await db.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");
    expect(rows.length, 14);
  });

  test('imports floor 2 twice without breaking foreign keys', () async {
    final json = File('assets/maps/floor2.json').readAsStringSync();
    await db.importFloorPackage(json);
    await db.importFloorPackage(json); // second time = update, not duplicate
    final floor = (await MapRepository(db).loadFloor('F2'))!;
    expect(floor.zones.length, 14);
    expect(floor.beacons.length, 10);
    expect(floor.nodes.length, 18);
    expect(floor.edges.length, 17);
  });

  test('outbox: SOS is sent before other rows', () async {
    final outbox = OutboxRepository(db);
    await outbox.addAck(ackStatus: 'safe');
    final sos = await outbox.addAck(ackStatus: 'sos', message: 'ขาเจ็บ');
    final pending = await outbox.pendingAcks();
    expect(pending.first['client_uuid'], sos);
    await outbox.markSent('ACK_OUTBOX', sos);
    expect((await outbox.pendingAcks()).length, 1);
  });
}
