import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';

CameraApi _apiReturning(
  FutureOr<http.Response> Function(http.Request request) handler,
) =>
    CameraApi(client: MockClient((req) async => handler(req)));

CameraFile _file(String name) => CameraFile(
      directory: '/DCIM/100OLYMP',
      filename: name,
      size: 100,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime(2024, 1, 1),
    );

void main() {
  group('CameraApi.listImages — network errors', () {
    test('404 yields an empty list (treated as empty directory)', () async {
      final api = _apiReturning((_) => http.Response('', 404));
      expect(await api.listImages('/DCIM'), isEmpty);
    });

    test('request exception is swallowed and yields empty list', () async {
      final api = _apiReturning((_) => throw const SocketExceptionLike());
      expect(await api.listImages('/DCIM'), isEmpty);
    });

    test('timeout yields empty list', () async {
      final api = CameraApi(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('', 200);
        }),
      );
      expect(await api.listImages('/DCIM'), isEmpty);
    });
  });

  group('CameraApi.listImages — parsing', () {
    test('parses valid records and skips malformed/short lines', () async {
      const date = (44 << 9) | (6 << 5) | 15;
      const time = (12 << 11);
      final body = [
        'VER,100',
        '/DCIM/100OLYMP,P1.JPG,2048,0,$date,$time',
        'too,few,fields',
        '/DCIM/100OLYMP,BAD.JPG,notanumber,0,$date,$time',
        '/DCIM/100OLYMP,HID.JPG,100,2,$date,$time',
      ].join('\r\n');

      final api = _apiReturning((_) => http.Response(body, 200));
      final files = await api.listImages('/DCIM');
      expect(files.map((f) => f.filename), ['P1.JPG']);
      expect(files.first.size, 2048);
    });

    test('skips records with corrupt FAT dates', () async {
      const badDate = (44 << 9) | 1;
      const body = '/DCIM/100OLYMP,X.JPG,100,0,$badDate,0';
      final api = _apiReturning((_) => http.Response(body, 200));
      expect(await api.listImages('/DCIM'), isEmpty);
    });
  });

  group('CameraApi.deleteFile', () {
    test('returns true on HTTP 200 with clean body', () async {
      final api = _apiReturning((_) => http.Response('OK', 200));
      expect(await api.deleteFile(_file('P1.JPG')), isTrue);
    });

    test('returns false on non-200 status', () async {
      final api = _apiReturning((_) => http.Response('', 403));
      expect(await api.deleteFile(_file('P1.JPG')), isFalse);
    });

    test('returns false when 200 body contains error text', () async {
      final api = _apiReturning((_) => http.Response('ERROR: locked', 200));
      expect(await api.deleteFile(_file('P1.JPG')), isFalse);
    });

    test('returns false when the request throws', () async {
      final api = _apiReturning((_) => throw const SocketExceptionLike());
      expect(await api.deleteFile(_file('P1.JPG')), isFalse);
    });
  });

  group('CameraApi.deleteFiles', () {
    test('aggregates success and failure counts', () async {
      final api = _apiReturning((req) {
        if (req.url.toString().contains('P2.JPG')) {
          return http.Response('', 500);
        }
        return http.Response('OK', 200);
      });
      final result = await api.deleteFiles(
        [_file('P1.JPG'), _file('P2.JPG'), _file('P3.JPG')],
      );
      expect(result.success, 2);
      expect(result.failed, 1);
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketExceptionLike: simulated network failure';
}
