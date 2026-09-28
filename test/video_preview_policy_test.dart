import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';

Uint8List _validJpeg() =>
    Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

void main() {
  test('MOV resize preview is fetched through screennail first frame', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return http.Response.bytes(_validJpeg(), 200);
    });
    final manager = ThumbnailManager.forTesting(client: client);

    final bytes = await manager.load(
      'http://192.168.0.10/get_resizeimg.cgi?DIR=/DCIM/100OLYMP/P1.MOV&size=1024',
      0,
    );

    expect(bytes, isNotNull);
    expect(
      urls,
      ['http://192.168.0.10/get_screennail.cgi?DIR=/DCIM/100OLYMP/P1.MOV'],
    );
  });

  test('still-image resize preview keeps get_resizeimg', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return http.Response.bytes(_validJpeg(), 200);
    });
    final manager = ThumbnailManager.forTesting(client: client);
    const url =
        'http://192.168.0.10/get_resizeimg.cgi?DIR=/DCIM/100OLYMP/P1.ORF&size=1024';

    final bytes = await manager.load(url, 0);

    expect(bytes, isNotNull);
    expect(urls, [url]);
  });
}
