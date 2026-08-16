import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../build_info.dart';
import '../version.dart';
import 'app_update_service.dart';
import 'background_download_service.dart';
import 'camera_api.dart';
import 'connection_history.dart';
import 'download_history.dart';

class DebugSection {
  const DebugSection(this.title, this.values);

  final String title;
  final Map<String, String> values;
}

class DebugSnapshot {
  const DebugSnapshot({
    required this.sections,
    required this.staleProcess,
    required this.versionMismatch,
    required this.runtimeVersion,
    required this.runtimeBuild,
  });

  final List<DebugSection> sections;
  final bool staleProcess;
  final bool versionMismatch;
  final String runtimeVersion;
  final String runtimeBuild;

  String toPlainText() {
    final out = StringBuffer();
    for (final section in sections) {
      out.writeln('== ${section.title} ==');
      for (final entry in section.values.entries) {
        out.writeln('${entry.key}: ${entry.value}');
      }
      out.writeln();
    }
    return out.toString().trimRight();
  }
}

class DebugInfoService {
  DebugInfoService._();

  static const MethodChannel _channel =
      MethodChannel('com.flynew.photomanager/debug_info');

  static Future<DebugSnapshot> collect() async {
    final native = await _nativeInfo();
    final runtimeVersion = native['versionName']?.toString() ?? 'unknown';
    final runtimeBuild = native['versionCode']?.toString() ?? 'unknown';
    final staleProcess = native['staleProcess'] == true;
    final versionMismatch = runtimeVersion != 'unknown' &&
        runtimeBuild != 'unknown' &&
        (runtimeVersion != appVersion || runtimeBuild != appBuild);

    final wifi = await _wifiInfo();
    final backgroundRunning = await _backgroundRunning();
    final downloadedCount = await _downloadedCount();
    final savedCameras = await _savedCameras();

    final sections = <DebugSection>[
      DebugSection('Application', <String, String>{
        'Runtime package version': '$runtimeVersion (build $runtimeBuild)',
        'Dart source constants': '$appVersion (build $appBuild)',
        'Package name': _string(native['packageName']),
        'Flavor': _string(native['flavor']),
        'Build type': _string(native['buildType']),
        'External updater enabled': _string(native['externalUpdaterEnabled']),
        'Process stale after install': staleProcess ? 'YES' : 'no',
        'Process started': _formatEpoch(native['processStartedAtMs']),
        'Package last updated': _formatEpoch(native['lastUpdateTimeMs']),
        'Package first installed': _formatEpoch(native['firstInstallTimeMs']),
        'Installer': _string(native['installerPackage']),
      }),
      DebugSection('Build', <String, String>{
        'Build time UTC': buildTimeUtc,
        'Git commit': buildGitCommit,
        'Flutter': buildFlutterVersion,
        'Compile SDK': _string(native['compileSdk']),
        'Target SDK': _string(native['targetSdk']),
        'Min SDK': _string(native['minSdk']),
      }),
      DebugSection('Device / Android', <String, String>{
        'Manufacturer': _string(native['manufacturer']),
        'Brand': _string(native['brand']),
        'Model': _string(native['model']),
        'Device': _string(native['device']),
        'Product': _string(native['product']),
        'Hardware': _string(native['hardware']),
        'Android': _string(native['androidRelease']),
        'API level': _string(native['sdkInt']),
        'Security patch': _string(native['securityPatch']),
        'Build ID': _string(native['androidBuildId']),
        'ABIs': _list(native['supportedAbis']),
        '64-bit process': _string(native['is64BitProcess']),
        'Locale': _string(native['locale']),
        'Time zone': _string(native['timeZone']),
      }),
      DebugSection('Display / resources', <String, String>{
        'Physical display':
            '${_string(native['displayWidthPx'])} × ${_string(native['displayHeightPx'])} px',
        'Density': '${_string(native['density'])} / ${_string(native['densityDpi'])} dpi',
        'Memory available': _bytes(native['memoryAvailableBytes']),
        'Memory total': _bytes(native['memoryTotalBytes']),
        'Low-memory flag': _string(native['lowMemory']),
        'Storage available': _bytes(native['storageAvailableBytes']),
        'Storage total': _bytes(native['storageTotalBytes']),
        'Battery': '${_string(native['batteryPercent'])}%',
        'Ignoring battery optimizations':
            _string(native['ignoringBatteryOptimizations']),
      }),
      DebugSection('Network / camera', <String, String>{
        'Wi-Fi SSID': wifi.$1,
        'Device Wi-Fi IP': wifi.$2,
        'Active transports': _list(native['networkTransports']),
        'Network validated': _string(native['networkValidated']),
        'Network metered': _string(native['networkMetered']),
        'Camera endpoint': baseUrl,
        'Camera IP': cameraIp,
        'Saved cameras': savedCameras,
      }),
      DebugSection('Application state', <String, String>{
        'Background download running': backgroundRunning,
        'Downloaded-history entries': '$downloadedCount',
        'External update supported now':
            AppUpdateService.supportsExternalUpdates ? 'yes' : 'no',
      }),
      DebugSection('Permissions', _permissions(native['permissions'])),
      DebugSection('Process', <String, String>{
        'PID': _string(native['processId']),
        'Device uptime': _duration(native['deviceUptimeMs']),
        'Debuggable package': _string(native['debuggable']),
        'Native library dir': _string(native['nativeLibraryDir']),
        'Java VM': _string(native['javaVmVersion']),
      }),
    ];

    return DebugSnapshot(
      sections: sections,
      staleProcess: staleProcess,
      versionMismatch: versionMismatch,
      runtimeVersion: runtimeVersion,
      runtimeBuild: runtimeBuild,
    );
  }

  static Future<Map<String, dynamic>> _nativeInfo() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return <String, dynamic>{
        'packageName': 'non-Android',
        'versionName': appVersion,
        'versionCode': appBuild,
        'flavor': appFlavor ?? 'unknown',
      };
    }
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getDebugInfo') ??
          <String, dynamic>{};
    } on PlatformException catch (error) {
      return <String, dynamic>{
        'versionName': appVersion,
        'versionCode': appBuild,
        'nativeError': '${error.code}: ${error.message}',
      };
    }
  }

  static Future<(String, String)> _wifiInfo() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return ('not available', 'not available');
    }
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      final ip = await WiFiForIoTPlugin.getIP();
      return (ssid ?? 'unknown', ip ?? 'unknown');
    } catch (_) {
      return ('unavailable', 'unavailable');
    }
  }

  static Future<String> _backgroundRunning() async {
    try {
      return await BackgroundDownloadService.isRunning() ? 'yes' : 'no';
    } catch (_) {
      return 'unknown';
    }
  }

  static Future<int> _downloadedCount() async {
    try {
      return (await DownloadHistory.load()).length;
    } catch (_) {
      return -1;
    }
  }

  static Future<String> _savedCameras() async {
    try {
      final cameras = await ConnectionHistory.load();
      if (cameras.isEmpty) return '0';
      final names = cameras
          .take(5)
          .map((camera) =>
              camera.cameraName.isNotEmpty ? camera.cameraName : camera.ssid)
          .join(', ');
      return '${cameras.length} ($names)';
    } catch (_) {
      return 'unknown';
    }
  }

  static Map<String, String> _permissions(Object? raw) {
    final result = <String, String>{};
    if (raw is! List) return <String, String>{'Declared permissions': 'unknown'};
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name']?.toString() ?? 'unknown';
      final shortName = name.startsWith('android.permission.')
          ? name.substring('android.permission.'.length)
          : name;
      result[shortName] = item['granted'] == true ? 'GRANTED' : 'denied';
    }
    if (result.isEmpty) result['Declared permissions'] = 'none';
    return result;
  }

  static String _string(Object? value) {
    if (value == null || value.toString().isEmpty) return 'unknown';
    return value.toString();
  }

  static String _list(Object? value) {
    if (value is List) return value.map((item) => item.toString()).join(', ');
    return _string(value);
  }

  static String _formatEpoch(Object? value) {
    final millis = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (millis == null || millis <= 0) return 'unknown';
    return DateTime.fromMillisecondsSinceEpoch(millis).toLocal().toIso8601String();
  }

  static String _bytes(Object? value) {
    final bytes = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (bytes == null || bytes < 0) return 'unknown';
    const kb = 1024.0;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  static String _duration(Object? value) {
    final millis = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (millis == null || millis < 0) return 'unknown';
    final duration = Duration(milliseconds: millis);
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    return '${days}d ${hours}h ${minutes}m';
  }
}
