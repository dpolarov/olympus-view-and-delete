import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

/// Olympus/OM System QR code decoder
/// OIS1 format (TG-6):  OIS1,<encoded_ssid>,<encoded_password>
/// OIS3 format (OM-1):  OIS3,<ver1>,<ver2>,<encoded_ssid>,<encoded_password>,<encoded_bt_name>,<encoded_bt_pass>
/// Charset: 44 chars (QR alphanumeric without space, / before .)
/// Formula: decoded = charset[(41 - charset.index(encoded)) % 44]
class OlympusQrDecoder {
  static const String _charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ\$%*+-/.:';
  static const int _key = 41;

  static String _decode(String encoded) {
    final buf = StringBuffer();
    for (final c in encoded.split('')) {
      final idx = _charset.indexOf(c);
      if (idx < 0) {
        buf.write(c);
        continue;
      }
      final decodedIdx = (_key - idx) % _charset.length;
      buf.write(_charset[decodedIdx]);
    }
    return buf.toString();
  }

  static WifiCredentials? parse(String raw) {
    if (!raw.startsWith('OIS')) return null;
    final parts = raw.split(',');

    String ssid;
    String password;
    String btName = '';
    String btPasscode = '';

    if (raw.startsWith('OIS3,') && parts.length >= 7) {
      // OIS3 format (OM-1): OIS3,ver1,ver2,wifi_ssid,wifi_password,bt_name,bt_passcode
      ssid = _decode(parts[3]);
      password = _decode(parts[4]);
      btName = _decode(parts[5]);
      btPasscode = _decode(parts[6]);
    } else if (raw.startsWith('OIS1,') && parts.length >= 3) {
      // OIS1 format (TG-6): OIS1,wifi_ssid,wifi_password
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

/// Parses WiFi QR code format: WIFI:T:<type>;S:<ssid>;P:<password>;;
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

  /// Try all known QR formats: OIS1 (Olympus), WIFI: (standard)
  static WifiCredentials? parseAny(String raw) {
    // Try Olympus OIS1 format first
    final ois = OlympusQrDecoder.parse(raw);
    if (ois != null) return ois;

    // Try standard WIFI: format
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
    return WifiCredentials(ssid: ssid, password: password, security: security);
  }
}

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;
  bool _connecting = false;
  bool _scannerError = false;
  String _status = '';
  WifiCredentials? _credentials;
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    _isMobile = Platform.isAndroid || Platform.isIOS;
    if (_isMobile) {
      _initScanner();
    }
  }

  Future<void> _initScanner() async {
    await Permission.camera.request();
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _scannerError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;

      setState(() => _scanned = true);
      _controller?.stop();

      final creds = WifiCredentials.parseAny(raw);
      if (creds != null) {
        final btInfo = creds.btName.isNotEmpty
            ? '\nBluetooth: ${creds.btName} (${creds.btPasscode})'
            : '';
        setState(() {
          _credentials = creds;
          _status = 'WiFi found: ${creds.ssid}$btInfo';
          _ssidController.text = creds.ssid;
          _passController.text = creds.password;
        });
        if (_isMobile) _connectToWifi(creds);
        return;
      }

      setState(() {
        _status = 'QR scanned:\n$raw\n\nUnknown format';
        _credentials = WifiCredentials(
          ssid: raw.trim(), password: '', security: 'NONE');
        _ssidController.text = raw.trim();
      });
      return;
    }
  }

  void _handleManualConnect() {
    final ssid = _ssidController.text.trim();
    final pass = _passController.text.trim();
    if (ssid.isEmpty) return;

    final creds = WifiCredentials(
      ssid: ssid, password: pass, security: pass.isEmpty ? 'NONE' : 'WPA');

    if (_isMobile) {
      _connectToWifi(creds);
    } else {
      setState(() {
        _status = 'WiFi: $ssid\nPassword: $pass\n\n'
            'Connect to this network manually in Windows Settings,\n'
            'then press "Done" below.';
        _credentials = creds;
      });
    }
  }

  Future<void> _connectToWifi(WifiCredentials creds) async {
    setState(() {
      _connecting = true;
      _status = 'Connecting to ${creds.ssid}...';
    });

    try {
      if (Platform.isAndroid) {
        await Permission.location.request();

        final connected = await WiFiForIoTPlugin.connect(
          creds.ssid,
          password: creds.password,
          security: _getNetworkSecurity(creds.security),
          joinOnce: false,
          withInternet: false,
        );

        if (connected) {
          await WiFiForIoTPlugin.forceWifiUsage(true);
          setState(() {
            _status = 'Connected to ${creds.ssid}!';
            _connecting = false;
          });
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _status = 'Failed to connect to ${creds.ssid}';
            _connecting = false;
            _scanned = false;
          });
          _controller?.start();
        }
      } else {
        setState(() {
          _status = 'WiFi: ${creds.ssid}\nPassword: ${creds.password}\n\n'
              'Connect manually in system settings.';
          _connecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _connecting = false;
        _scanned = false;
      });
      _controller?.start();
    }
  }

  NetworkSecurity _getNetworkSecurity(String type) {
    switch (type.toUpperCase()) {
      case 'WPA':
      case 'WPA2':
        return NetworkSecurity.WPA;
      case 'WEP':
        return NetworkSecurity.WEP;
      case '':
      case 'NONE':
        return NetworkSecurity.NONE;
      default:
        return NetworkSecurity.WPA;
    }
  }

  Widget _buildManualEntry() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Enter WiFi credentials from camera screen:',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ssidController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'SSID',
              hintText: 'e.g. TG-6-P-BJ5A21882',
              labelStyle: TextStyle(color: Colors.grey[400]),
              hintStyle: TextStyle(color: Colors.grey[600]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600]!),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFE94560)),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: const Color(0xFF252540),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'e.g. 98109058',
              labelStyle: TextStyle(color: Colors.grey[400]),
              hintStyle: TextStyle(color: Colors.grey[600]),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600]!),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFE94560)),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: const Color(0xFF252540),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleManualConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isMobile ? 'CONNECT' : 'SHOW CREDENTIALS',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Connect to Camera'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Camera scanner (mobile only)
            if (_isMobile && !_scannerError) ...[
              SizedBox(
                height: 300,
                child: _controller == null
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFE94560)))
                    : Stack(
                        children: [
                          MobileScanner(
                            controller: _controller!,
                            onDetect: _onDetect,
                          ),
                          Center(
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _scanned
                                      ? const Color(0xFF2ECC71)
                                      : const Color(0xFFE94560),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const Divider(color: Color(0xFF333355), height: 1),
            ],

            // Manual entry (always visible)
            _buildManualEntry(),

            // Status
            if (_status.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF1A1A2E),
                child: Column(
                  children: [
                    if (_connecting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CircularProgressIndicator(
                            color: Color(0xFF2ECC71)),
                      ),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _scanned && !_connecting
                            ? const Color(0xFF2ECC71)
                            : Colors.white,
                      ),
                    ),
                    if (!_isMobile && _credentials != null && !_connecting) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 32),
                        ),
                        child: const Text('Done — Go Back',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
