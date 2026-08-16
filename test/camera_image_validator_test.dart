import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/camera_image_validator.dart';

void main() {
  test('accepts a complete JPEG response', () {
    final bytes = Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0x01,
      0x02,
      0x03,
      0xFF,
      0xD9,
    ]);

    expect(isCompleteCameraJpeg(bytes), isTrue);
    expect(isCompleteCameraJpeg(bytes, expectedLength: bytes.length), isTrue);
  });

  test('rejects a truncated JPEG without EOI marker', () {
    final bytes = Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0x01,
      0x02,
      0x03,
    ]);

    expect(isCompleteCameraJpeg(bytes), isFalse);
  });

  test('rejects a non-JPEG HTTP body', () {
    final bytes = Uint8List.fromList('ERROR'.codeUnits);

    expect(isCompleteCameraJpeg(bytes), isFalse);
  });

  test('rejects content-length mismatch', () {
    final bytes = Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0x01,
      0x02,
      0xFF,
      0xD9,
    ]);

    expect(
      isCompleteCameraJpeg(bytes, expectedLength: bytes.length + 10),
      isFalse,
    );
  });

  test('allows a small amount of trailing camera padding', () {
    final bytes = Uint8List.fromList(<int>[
      0xFF,
      0xD8,
      0x01,
      0x02,
      0xFF,
      0xD9,
      0x00,
      0x00,
    ]);

    expect(isCompleteCameraJpeg(bytes), isTrue);
  });
}
