import 'dart:typed_data';

/// Olympus thumbnail/resize endpoints return JPEG data. A camera can close a
/// Wi-Fi response early while still leaving us with a non-empty HTTP body, so
/// do a cheap structural check before putting bytes into persistent cache.
bool isCompleteCameraJpeg(Uint8List bytes, {int? expectedLength}) {
  if (expectedLength != null &&
      expectedLength > 0 &&
      bytes.lengthInBytes != expectedLength) {
    return false;
  }
  if (bytes.lengthInBytes < 4) return false;

  // JPEG SOI marker.
  if (bytes[0] != 0xFF || bytes[1] != 0xD8) return false;

  // JPEG EOI should be at the end. Allow a small amount of harmless trailing
  // padding because embedded camera HTTP servers are not always perfectly
  // consistent about their response framing.
  final firstCandidate =
      bytes.lengthInBytes > 66 ? bytes.lengthInBytes - 66 : 2;
  for (var i = bytes.lengthInBytes - 2; i >= firstCandidate; i--) {
    if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) return true;
  }
  return false;
}
