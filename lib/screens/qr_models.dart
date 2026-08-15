/// Decoded camera/network credentials shared by native and Web UI.
class WifiCredentials {
  final String ssid;
  final String password;
  final String security;
  final String btName;
  final String btPasscode;

  WifiCredentials({
    required this.ssid,
    required this.password,
    required this.security,
    this.btName = '',
    this.btPasscode = '',
  });

  static WifiCredentials? parseAny(String raw) {
    final olympus = OlympusQrDecoder.parse(raw);
    if (olympus != null) return olympus;
    return parseWifi(raw);
  }

  static WifiCredentials? parseWifi(String raw) {
    if (!raw.startsWith('WIFI:')) return null;

    String ssid = '';
    String password = '';
    String security = 'WPA';
    final regex = RegExp(r'([TSPH]):([^;]*);');

    for (final match in regex.allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2) ?? '';
      switch (key) {
        case 'S':
          ssid = value;
          break;
        case 'P':
          password = value;
          break;
        case 'T':
          security = value;
          break;
      }
    }

    if (ssid.isEmpty) return null;
    return WifiCredentials(
      ssid: ssid,
      password: password,
      security: security,
    );
  }
}

/// Olympus/OM System QR code decoder.
/// OIS1: OIS1,<encoded_ssid>,<encoded_password>
/// OIS3: OIS3,<ver1>,<ver2>,<ssid>,<password>,<bt_name>,<bt_passcode>
class OlympusQrDecoder {
  static const String _charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ\$%*+-/.:';
  static const int _key = 41;

  static String _decode(String encoded) {
    final out = StringBuffer();
    for (final char in encoded.split('')) {
      final index = _charset.indexOf(char);
      if (index < 0) {
        out.write(char);
      } else {
        out.write(_charset[(_key - index) % _charset.length]);
      }
    }
    return out.toString();
  }

  static WifiCredentials? parse(String raw) {
    if (!raw.startsWith('OIS')) return null;
    final parts = raw.split(',');

    String ssid;
    String password;
    String btName = '';
    String btPasscode = '';

    if (raw.startsWith('OIS3,') && parts.length >= 7) {
      ssid = _decode(parts[3]);
      password = _decode(parts[4]);
      btName = _decode(parts[5]);
      btPasscode = _decode(parts[6]);
    } else if (raw.startsWith('OIS1,') && parts.length >= 3) {
      ssid = _decode(parts[1]);
      password = _decode(parts[2]);
    } else {
      return null;
    }

    if (ssid.isEmpty) return null;
    return WifiCredentials(
      ssid: ssid,
      password: password,
      security: 'WPA',
      btName: btName,
      btPasscode: btPasscode,
    );
  }
}
