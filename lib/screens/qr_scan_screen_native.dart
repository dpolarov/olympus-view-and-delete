import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../constants.dart';
import '../services/app_logger.dart';
import '../services/connection_history.dart';
import 'qr_models.dart';

class QrScanScreen extends StatefulWidget {
  final String? initialSsid;
  final String? initialPassword;

  const QrScanScreen({super.key, this.initialSsid, this.initialPassword});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? _scanner;
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  List<SavedConnection> _history = const [];
  String _status = '';
  bool _busy = false;
  bool _scannerFailed = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _ssid.text = widget.initialSsid ?? '';
    _password.text = widget.initialPassword ?? '';
    unawaited(_loadHistory());
    if (_isMobile) unawaited(_initScanner());
  }

  Future<void> _loadHistory() async {
    final history = await ConnectionHistory.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _initScanner() async {
    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      if (mounted) setState(() => _scannerFailed = true);
      return;
    }

    try {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
      if (mounted) setState(() {});
    } catch (e, st) {
      AppLogger.warning('scanner init failed',
          name: 'qr_scan', error: e, stackTrace: st);
      if (mounted) setState(() => _scannerFailed = true);
    }
  }

  Future<void> _ensureAndroidWifiPermission() async {
    final nearby = await Permission.nearbyWifiDevices.request();
    if (nearby.isGranted) return;

    // On Android 12L and older the WiFi APIs use location permission instead.
    final legacyLocation = await Permission.location.request();
    if (!legacyLocation.isGranted) {
      throw StateError('Nearby WiFi permission was not granted');
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final credentials = WifiCredentials.parseAny(raw);
      if (credentials == null) {
        if (mounted) setState(() => _status = 'Unknown QR format');
        return;
      }
      _ssid.text = credentials.ssid;
      _password.text = credentials.password;
      await _scanner?.stop();
      await _connect(credentials);
      return;
    }
  }

  Future<void> _connectManual() async {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty) return;
    await _connect(WifiCredentials(
      ssid: ssid,
      password: _password.text,
      security: _password.text.isEmpty ? 'NONE' : 'WPA',
    ));
  }

  Future<void> _connect(WifiCredentials credentials) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '${AppStrings.connectingTo} ${credentials.ssid}...';
    });

    try {
      if (Platform.isAndroid) {
        await _ensureAndroidWifiPermission();
        final connected = await WiFiForIoTPlugin.connect(
          credentials.ssid,
          password: credentials.password,
          security: _security(credentials.security),
          joinOnce: false,
          withInternet: false,
        );
        if (!connected) {
          throw StateError('Could not connect to ${credentials.ssid}');
        }
        await WiFiForIoTPlugin.forceWifiUsage(true);
      }

      await ConnectionHistory.save(SavedConnection(
        ssid: credentials.ssid,
        password: credentials.password,
        security: credentials.security,
        btName: credentials.btName,
        btPasscode: credentials.btPasscode,
        lastConnected: DateTime.now(),
      ));

      if (!mounted) return;
      if (Platform.isAndroid) {
        setState(() {
          _busy = false;
          _status = '${AppStrings.connected} to ${credentials.ssid}!';
        });
        await Future.delayed(kQrSuccessDelay);
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _busy = false;
          _status =
              'Connect to ${credentials.ssid} manually in system WiFi settings, then press Done.';
        });
      }
    } catch (e, st) {
      AppLogger.warning('camera WiFi connect failed',
          name: 'qr_scan', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'Connection failed: $e';
        });
        unawaited(_scanner?.start() ?? Future<void>.value());
      }
    }
  }

  NetworkSecurity _security(String value) {
    switch (value.toUpperCase()) {
      case 'WEP':
        return NetworkSecurity.WEP;
      case '':
      case 'NONE':
        return NetworkSecurity.NONE;
      default:
        return NetworkSecurity.WPA;
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Camera')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isMobile && !_scannerFailed)
            SizedBox(
              height: 280,
              child: _scanner == null
                  ? const Center(child: CircularProgressIndicator())
                  : MobileScanner(controller: _scanner!, onDetect: _handleBarcode),
            ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Saved cameras',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._history.map((item) => ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(item.ssid),
                  subtitle: Text(item.lastConnectedStr),
                  onTap: () {
                    _ssid.text = item.ssid;
                    _password.text = item.password;
                    unawaited(_connect(WifiCredentials(
                      ssid: item.ssid,
                      password: item.password,
                      security: item.security,
                      btName: item.btName,
                      btPasscode: item.btPasscode,
                    )));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ConnectionHistory.delete(item.ssid);
                      await _loadHistory();
                    },
                  ),
                )),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _ssid,
            decoration: const InputDecoration(labelText: 'SSID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _connectManual,
            child:
                Text(_isMobile ? 'Connect' : 'Show connection instructions'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            SelectableText(_status, textAlign: TextAlign.center),
          ],
          if (!_isMobile && _status.isNotEmpty) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}
