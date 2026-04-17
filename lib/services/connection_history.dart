import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedConnection {
  final String ssid;
  final String password;
  final String security;
  final String cameraName;
  final String btName;
  final String btPasscode;
  final DateTime lastConnected;

  SavedConnection({
    required this.ssid,
    required this.password,
    this.security = 'WPA',
    this.cameraName = '',
    this.btName = '',
    this.btPasscode = '',
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'password': password,
        'security': security,
        'cameraName': cameraName,
        'btName': btName,
        'btPasscode': btPasscode,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory SavedConnection.fromJson(Map<String, dynamic> json) {
    return SavedConnection(
      ssid: json['ssid'] ?? '',
      password: json['password'] ?? '',
      security: json['security'] ?? 'WPA',
      cameraName: json['cameraName'] ?? '',
      btName: json['btName'] ?? '',
      btPasscode: json['btPasscode'] ?? '',
      lastConnected: DateTime.tryParse(json['lastConnected'] ?? '') ?? DateTime.now(),
    );
  }

  String get lastConnectedStr {
    final d = lastConnected;
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

class ConnectionHistory {
  static const String _key = 'connection_history';

  // Serialises concurrent read-modify-write operations on the history
  // list so two simultaneous `save()` / `delete()` calls don't clobber
  // each other.
  static Future<void> _chain = Future<void>.value();

  static Future<T> _serial<T>(Future<T> Function() op) {
    final prev = _chain;
    final completer = Completer<T>();
    _chain = prev.then((_) async {
      try {
        completer.complete(await op());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<List<SavedConnection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return SavedConnection.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<SavedConnection>()
        .toList()
      ..sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
  }

  static Future<void> save(SavedConnection conn) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await load();

        // Remove existing entry with same SSID
        list.removeWhere((c) => c.ssid == conn.ssid);

        // Add new entry at the top
        list.insert(0, conn);

        // Keep max 10 entries
        final trimmed = list.take(10).toList();

        await prefs.setStringList(
          _key,
          trimmed.map((c) => jsonEncode(c.toJson())).toList(),
        );
      });

  static Future<void> delete(String ssid) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = await load();
        list.removeWhere((c) => c.ssid == ssid);
        await prefs.setStringList(
          _key,
          list.map((c) => jsonEncode(c.toJson())).toList(),
        );
      });
}
