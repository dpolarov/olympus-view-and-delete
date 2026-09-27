import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../services/app_logger.dart';
import '../services/camera_api.dart';
import '../services/thumbnail_manager.dart';

/// Keeps gallery image traffic tied to the camera Wi-Fi session.
///
/// When the app leaves the foreground, new thumbnail requests are paused. On
/// resume, the app verifies that it is still on the same Wi-Fi network and that
/// the camera endpoint is reachable before allowing queued requests to run.
/// Cached previews can still be read while network work is paused.
class CameraWifiLifecycleGuard extends StatefulWidget {
  const CameraWifiLifecycleGuard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<CameraWifiLifecycleGuard> createState() =>
      _CameraWifiLifecycleGuardState();
}

class _CameraWifiLifecycleGuardState extends State<CameraWifiLifecycleGuard>
    with WidgetsBindingObserver {
  final CameraApi _api = CameraApi();

  bool _pausedForLifecycle = false;
  bool _checking = false;
  String? _cameraSsid;
  Future<void>? _captureFuture;
  Timer? _recheckTimer;

  bool get _supportsWifiCheck =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recheckTimer?.cancel();
    if (_pausedForLifecycle) {
      ThumbnailManager.instance.resumeNetwork();
    }
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _pauseForLifecycle();
        break;
      case AppLifecycleState.resumed:
        unawaited(_verifyAndResume());
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  void _pauseForLifecycle() {
    if (_pausedForLifecycle) return;
    _pausedForLifecycle = true;
    ThumbnailManager.instance.pauseNetwork();
    _recheckTimer?.cancel();
    _recheckTimer = null;
    _captureFuture = _captureCameraWifi();
  }

  Future<void> _captureCameraWifi() async {
    if (!_supportsWifiCheck) return;
    try {
      // Only remember an SSID when the camera is actually reachable on it.
      // This prevents an unrelated internet Wi-Fi from becoming the expected
      // camera network while the updater or another screen is active.
      final reachable = await _api.testConnection(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!reachable) return;
      final ssid = _normalizeSsid(await WiFiForIoTPlugin.getSSID());
      if (ssid.isNotEmpty) _cameraSsid = ssid;
    } catch (e, st) {
      AppLogger.debug(
        'camera WiFi capture failed: $e',
        name: 'camera_wifi_lifecycle',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _verifyAndResume() async {
    if (!_pausedForLifecycle || _checking) return;
    _checking = true;
    try {
      final capture = _captureFuture;
      if (capture != null) await capture;
      _captureFuture = null;

      if (!_supportsWifiCheck || _cameraSsid == null) {
        _resumeThumbnailNetwork();
        return;
      }

      if (await _cameraWifiIsRestored()) {
        _resumeThumbnailNetwork();
      } else {
        _startRecheckTimer();
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> _cameraWifiIsRestored() async {
    try {
      final current = _normalizeSsid(await WiFiForIoTPlugin.getSSID());
      if (current.isEmpty || current != _cameraSsid) {
        await WiFiForIoTPlugin.forceWifiUsage(false);
        return false;
      }

      await WiFiForIoTPlugin.forceWifiUsage(true);
      return _api.testConnection(
        timeout: const Duration(milliseconds: 1500),
      );
    } catch (e, st) {
      AppLogger.debug(
        'camera WiFi resume check failed: $e',
        name: 'camera_wifi_lifecycle',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  void _startRecheckTimer() {
    _recheckTimer?.cancel();
    _recheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_retryCameraWifi());
    });
  }

  Future<void> _retryCameraWifi() async {
    if (!_pausedForLifecycle || _checking) return;
    _checking = true;
    try {
      if (await _cameraWifiIsRestored()) {
        _resumeThumbnailNetwork();
      }
    } finally {
      _checking = false;
    }
  }

  void _resumeThumbnailNetwork() {
    _recheckTimer?.cancel();
    _recheckTimer = null;
    if (!_pausedForLifecycle) return;
    _pausedForLifecycle = false;
    ThumbnailManager.instance.resumeNetwork();
  }

  static String _normalizeSsid(String? value) {
    var ssid = (value ?? '').trim();
    if (ssid.length >= 2 && ssid.startsWith('"') && ssid.endsWith('"')) {
      ssid = ssid.substring(1, ssid.length - 1);
    }
    return ssid;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
