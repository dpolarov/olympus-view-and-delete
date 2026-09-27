import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../services/app_logger.dart';
import '../services/camera_api.dart';
import '../services/connection_history.dart';
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
      // Remember the SSID only if the Olympus/OM camera endpoint is actually
      // reachable on it. An unrelated internet Wi-Fi must never become the
      // expected camera network just because the app was backgrounded there.
      final reachable = await _api.testConnection(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!reachable) return;
      final ssid = _normalizeSsid(await WiFiForIoTPlugin.getSSID());
      if (ssid.isNotEmpty) _cameraSsid = ssid;
    } catch (e) {
      AppLogger.debug(
        'camera WiFi capture failed: $e',
        name: 'camera_wifi_lifecycle',
      );
    }
  }

  Future<void> _loadSavedCameraSsid() async {
    if (_cameraSsid != null) return;
    try {
      final history = await ConnectionHistory.load();
      if (history.isEmpty) return;
      final saved = _normalizeSsid(history.first.ssid);
      if (saved.isNotEmpty) _cameraSsid = saved;
    } catch (e) {
      AppLogger.debug(
        'saved camera SSID lookup failed: $e',
        name: 'camera_wifi_lifecycle',
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

      if (!_supportsWifiCheck) {
        _resumeThumbnailNetwork();
        return;
      }

      // Android can switch Wi-Fi very quickly after the app becomes inactive,
      // before the asynchronous SSID capture above finishes. The most recently
      // used saved camera is a safe fallback for that race.
      await _loadSavedCameraSsid();
      if (_cameraSsid == null) {
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
      final expected = _cameraSsid;
      if (current.isEmpty || expected == null || current != expected) {
        await WiFiForIoTPlugin.forceWifiUsage(false);
        return false;
      }

      // Only after confirming the same camera SSID do we bind HTTP traffic to
      // Wi-Fi and probe the camera. This prevents requests from leaking onto an
      // internet/home network that Android selected while the app was hidden.
      await WiFiForIoTPlugin.forceWifiUsage(true);
      final reachable = await _api.testConnection(
        timeout: const Duration(milliseconds: 1500),
      );
      if (!reachable) {
        await WiFiForIoTPlugin.forceWifiUsage(false);
      }
      return reachable;
    } catch (e) {
      AppLogger.debug(
        'camera WiFi resume check failed: $e',
        name: 'camera_wifi_lifecycle',
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
