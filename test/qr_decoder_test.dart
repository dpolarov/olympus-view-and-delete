import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/screens/qr_scan_screen.dart';

// Mirror of the private _decode() + _charset so we can build encoded test
// payloads without modifying the production code. The transform is an
// involution: decode(decode(x)) == x for chars in charset.
const _charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ\$%*+-/.:';
const _key = 41;

String _encode(String plain) {
  final buf = StringBuffer();
  for (final c in plain.split('')) {
    final idx = _charset.indexOf(c);
    if (idx < 0) {
      buf.write(c);
      continue;
    }
    final encIdx = (_key - idx) % _charset.length;
    buf.write(_charset[encIdx]);
  }
  return buf.toString();
}

void main() {
  group('OlympusQrDecoder', () {
    test('encodes+decodes is involution for charset chars', () {
      // Self-check: applying _encode twice should yield the original.
      const samples = ['TG6', 'OMCAMERA', 'PWD1234', '\$MONEY'];
      for (final s in samples) {
        expect(_encode(_encode(s)), s);
      }
    });

    test('parses OIS1 (TG-6) payload', () {
      const ssid = 'OLYMPUSTG6';
      const pass = 'PASSWORD1';
      final raw = 'OIS1,${_encode(ssid)},${_encode(pass)}';
      final creds = OlympusQrDecoder.parse(raw);
      expect(creds, isNotNull);
      expect(creds!.ssid, ssid);
      expect(creds.password, pass);
      expect(creds.security, 'WPA');
      expect(creds.btName, '');
      expect(creds.btPasscode, '');
    });

    test('parses OIS3 (OM-1) payload with bluetooth fields', () {
      const ssid = 'OMCAMERA';
      const pass = 'WIFIPASS';
      const btName = 'OMBT';
      const btPass = 'BTPASS';
      final raw = 'OIS3,V1,V2,'
          '${_encode(ssid)},${_encode(pass)},'
          '${_encode(btName)},${_encode(btPass)}';
      final creds = OlympusQrDecoder.parse(raw);
      expect(creds, isNotNull);
      expect(creds!.ssid, ssid);
      expect(creds.password, pass);
      expect(creds.btName, btName);
      expect(creds.btPasscode, btPass);
    });

    test('returns null for non-OIS prefix', () {
      expect(OlympusQrDecoder.parse('WIFI:T:WPA;S:foo;P:bar;;'), isNull);
      expect(OlympusQrDecoder.parse('random'), isNull);
    });

    test('returns null when OIS3 has too few fields', () {
      expect(OlympusQrDecoder.parse('OIS3,v1,v2,ssid,pw'), isNull);
    });

    test('returns null when OIS1 has too few fields', () {
      expect(OlympusQrDecoder.parse('OIS1,onlyssid'), isNull);
    });
  });

  group('WifiCredentials.parseWifi', () {
    test('parses standard WIFI: QR payload', () {
      final creds = WifiCredentials.parseWifi('WIFI:T:WPA;S:MyCam;P:secret;;');
      expect(creds, isNotNull);
      expect(creds!.ssid, 'MyCam');
      expect(creds.password, 'secret');
      expect(creds.security, 'WPA');
    });

    test('returns null on empty SSID', () {
      expect(WifiCredentials.parseWifi('WIFI:T:WPA;S:;P:pw;;'), isNull);
    });

    test('returns null on non-WIFI prefix', () {
      expect(WifiCredentials.parseWifi('OIS1,foo,bar'), isNull);
    });
  });

  group('WifiCredentials.parseAny', () {
    test('falls through OIS1 → WIFI:', () {
      final std = WifiCredentials.parseAny('WIFI:T:WPA;S:X;P:Y;;');
      expect(std, isNotNull);
      expect(std!.ssid, 'X');
    });

    test('prefers OIS when payload is Olympus', () {
      final raw = 'OIS1,${_encode("SS")},${_encode("PP")}';
      final creds = WifiCredentials.parseAny(raw);
      expect(creds, isNotNull);
      expect(creds!.ssid, 'SS');
    });

    test('returns null for unknown payload', () {
      expect(WifiCredentials.parseAny('just some text'), isNull);
    });
  });
}
