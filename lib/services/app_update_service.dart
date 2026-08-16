import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../version.dart';
import 'app_logger.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseUrl,
    required this.releaseNotes,
  });

  final String version;
  final String apkUrl;
  final String releaseUrl;
  final String releaseNotes;
}

class InstalledAppVersion {
  const InstalledAppVersion({required this.versionName, required this.versionCode});

  final String versionName;
  final String versionCode;

  String get display => 'v$versionName (build $versionCode)';
}

class AppUpdateService {
  AppUpdateService._();

  static const MethodChannel _channel =
      MethodChannel('com.flynew.photomanager/app_update');
  static const String latestReleaseEndpoint =
      'https://api.github.com/repos/dpolarov/olympus-view-and-delete/releases/latest';

  static bool get supportsExternalUpdates =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      appFlavor == 'github';

  static Future<InstalledAppVersion> getInstalledVersion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const InstalledAppVersion(
        versionName: appVersion,
        versionCode: appBuild,
      );
    }

    try {
      final current = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentVersion',
      );
      final versionName = current?['versionName']?.toString();
      final versionCode = current?['versionCode']?.toString();
      if (versionName != null && versionName.isNotEmpty &&
          versionCode != null && versionCode.isNotEmpty) {
        return InstalledAppVersion(
          versionName: versionName,
          versionCode: versionCode,
        );
      }
    } on PlatformException catch (error) {
      AppLogger.debug(
        'native version lookup failed; using source fallback: $error',
        name: 'app_update',
      );
    }

    return const InstalledAppVersion(
      versionName: appVersion,
      versionCode: appBuild,
    );
  }

  static Future<AppReleaseInfo?> checkForUpdate() async {
    if (!supportsExternalUpdates) return null;

    try {
      final currentVersion = (await getInstalledVersion()).versionName;
      final response = await http.get(
        Uri.parse(latestReleaseEndpoint),
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'OlympusView/$currentVersion',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;

      return releaseFromGitHubJson(json, currentVersion);
    } catch (error) {
      AppLogger.debug(
        'update check failed: $error',
        name: 'app_update',
      );
      return null;
    }
  }

  @visibleForTesting
  static AppReleaseInfo? releaseFromGitHubJson(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    final tag = json['tag_name']?.toString() ?? '';
    final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
    if (latestVersion.isEmpty ||
        !isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }

    String? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic> &&
            asset['name'] == 'OlympusView-Android.apk') {
          apkUrl = asset['browser_download_url']?.toString();
          break;
        }
      }
    }
    if (apkUrl == null || apkUrl.isEmpty) return null;

    return AppReleaseInfo(
      version: latestVersion,
      apkUrl: apkUrl,
      releaseUrl: json['html_url']?.toString() ??
          'https://github.com/dpolarov/olympus-view-and-delete/releases/latest',
      releaseNotes: _cleanReleaseNotes(json['body']?.toString() ?? ''),
    );
  }

  static Future<bool> canInstallUnknownApps() async {
    if (!supportsExternalUpdates) return false;
    return await _channel.invokeMethod<bool>('canInstallUnknownApps') ?? false;
  }

  static Future<void> openInstallSettings() async {
    if (!supportsExternalUpdates) return;
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  static Future<void> startUpdateDownload(AppReleaseInfo release) async {
    if (!supportsExternalUpdates) return;
    await _channel.invokeMethod<void>('startUpdateDownload', <String, Object>{
      'url': release.apkUrl,
      'version': release.version,
    });
  }

  static String _cleanReleaseNotes(String raw) {
    if (raw.trim().isEmpty) return '';

    final result = <String>[];
    for (final sourceLine in raw.replaceAll('\r\n', '\n').split('\n')) {
      var line = sourceLine.trimRight();
      if (line.startsWith('### ')) {
        line = line.substring(4);
      } else if (line.startsWith('## ')) {
        line = line.substring(3);
      } else if (line.startsWith('# ')) {
        line = line.substring(2);
      }
      if (line.startsWith('- ')) {
        line = '• ${line.substring(2)}';
      }
      line = line.replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'),
        (match) => match.group(1) ?? '',
      );
      line = line.replaceAll('`', '');
      result.add(line);
    }

    while (result.isNotEmpty && result.first.trim().isEmpty) {
      result.removeAt(0);
    }
    while (result.isNotEmpty && result.last.trim().isEmpty) {
      result.removeLast();
    }
    return result.join('\n');
  }

  @visibleForTesting
  static bool isNewerVersion(String candidate, String current) {
    final a = _versionParts(candidate);
    final b = _versionParts(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static List<int> _versionParts(String value) {
    final matches = RegExp(r'\d+').allMatches(value).take(3).toList();
    return List<int>.generate(
      3,
      (index) => index < matches.length
          ? int.tryParse(matches[index].group(0) ?? '') ?? 0
          : 0,
    );
  }
}
