import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:olympus_tg6_manager/services/connection_history.dart';

SavedConnection _conn(
  String ssid, {
  String pw = 'pw',
  String name = '',
  DateTime? at,
}) {
  return SavedConnection(
    ssid: ssid,
    password: pw,
    cameraName: name,
    lastConnected: at ?? DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('empty history loads as empty list', () async {
    expect(await ConnectionHistory.load(), isEmpty);
  });

  test('save + load round-trips fields', () async {
    final when = DateTime(2024, 5, 1, 10, 30);
    await ConnectionHistory.save(SavedConnection(
      ssid: 'TG6-ABC',
      password: 'hunter2',
      security: 'WPA',
      cameraName: 'TG-6',
      btName: 'TG6BT',
      btPasscode: '000000',
      lastConnected: when,
    ));
    final list = await ConnectionHistory.load();
    expect(list, hasLength(1));
    final c = list.single;
    expect(c.ssid, 'TG6-ABC');
    expect(c.password, 'hunter2');
    expect(c.security, 'WPA');
    expect(c.cameraName, 'TG-6');
    expect(c.btName, 'TG6BT');
    expect(c.btPasscode, '000000');
    expect(c.lastConnected, when);
  });

  test('save deduplicates by SSID and keeps latest on top', () async {
    await ConnectionHistory.save(_conn('SAME', pw: 'old', at: DateTime(2024)));
    await ConnectionHistory.save(_conn('OTHER', at: DateTime(2024, 2)));
    await ConnectionHistory.save(_conn('SAME', pw: 'new', at: DateTime(2024, 3)));

    final list = await ConnectionHistory.load();
    expect(list.map((c) => c.ssid), ['SAME', 'OTHER']);
    expect(list.first.password, 'new');
  });

  test('history is capped at 10 entries', () async {
    for (int i = 0; i < 15; i++) {
      await ConnectionHistory.save(
        _conn('SSID_$i', at: DateTime(2024, 1, 1).add(Duration(minutes: i))),
      );
    }
    final list = await ConnectionHistory.load();
    expect(list.length, 10);
    // Newest first → SSID_14, SSID_13, ..., SSID_5
    expect(list.first.ssid, 'SSID_14');
    expect(list.last.ssid, 'SSID_5');
  });

  test('delete removes by SSID', () async {
    await ConnectionHistory.save(_conn('A'));
    await ConnectionHistory.save(_conn('B'));
    await ConnectionHistory.delete('A');
    final list = await ConnectionHistory.load();
    expect(list.map((c) => c.ssid), ['B']);
  });

  test('delete of missing SSID is a no-op', () async {
    await ConnectionHistory.save(_conn('X'));
    await ConnectionHistory.delete('NOTEXIST');
    final list = await ConnectionHistory.load();
    expect(list, hasLength(1));
  });

  test('concurrent saves are serialized — no entries are lost', () async {
    // Fire 20 saves in parallel without awaiting each; all SSIDs unique.
    final futures = <Future<void>>[];
    for (int i = 0; i < 20; i++) {
      futures.add(ConnectionHistory.save(
        _conn('C_$i', at: DateTime(2024, 1, 1).add(Duration(seconds: i))),
      ));
    }
    await Future.wait(futures);
    final list = await ConnectionHistory.load();
    // Capped at 10 — but we verify no read-modify-write race dropped the tail.
    expect(list.length, 10);
    // Top 10 newest: C_19..C_10
    expect(list.first.ssid, 'C_19');
    expect(list.last.ssid, 'C_10');
  });

  test('load returns empty list when stored JSON is corrupt', () async {
    SharedPreferences.setMockInitialValues({
      'connection_history': <String>['{not json}', 'also bad'],
    });
    expect(await ConnectionHistory.load(), isEmpty);
  });

  test('load sorts by lastConnected descending', () async {
    await ConnectionHistory.save(_conn('OLD', at: DateTime(2023, 1, 1)));
    await ConnectionHistory.save(_conn('NEW', at: DateTime(2025, 1, 1)));
    await ConnectionHistory.save(_conn('MID', at: DateTime(2024, 1, 1)));
    final list = await ConnectionHistory.load();
    expect(list.map((c) => c.ssid), ['NEW', 'MID', 'OLD']);
  });
}
