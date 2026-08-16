import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/app_update_service.dart';

void main() {
  group('AppUpdateService.isNewerVersion', () {
    test('detects a newer patch release', () {
      expect(AppUpdateService.isNewerVersion('1.3.4', '1.3.2'), isTrue);
    });

    test('does not treat the same version as newer', () {
      expect(AppUpdateService.isNewerVersion('1.3.4', '1.3.4'), isFalse);
    });

    test('does not treat an older version as newer', () {
      expect(AppUpdateService.isNewerVersion('1.3.2', '1.3.4'), isFalse);
    });

    test('compares numeric parts instead of lexicographically', () {
      expect(AppUpdateService.isNewerVersion('1.10.0', '1.9.9'), isTrue);
    });
  });

  group('AppUpdateService.releaseFromGitHubJson', () {
    Map<String, dynamic> releaseJson({
      String tag = 'v1.3.4',
      bool includeApk = true,
    }) {
      return <String, dynamic>{
        'tag_name': tag,
        'html_url':
            'https://github.com/dpolarov/olympus-view-and-delete/releases/tag/$tag',
        'body': '### Fixed\n- **Updater** works with `APK` assets.',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'OlympusView-Android.aab',
            'browser_download_url': 'https://example.invalid/app.aab',
          },
          if (includeApk)
            <String, dynamic>{
              'name': 'OlympusView-Android.apk',
              'browser_download_url': 'https://example.invalid/app.apk',
            },
        ],
      };
    }

    test('returns the exact Android APK for 1.3.2 -> 1.3.4', () {
      final release = AppUpdateService.releaseFromGitHubJson(
        releaseJson(),
        '1.3.2',
      );

      expect(release, isNotNull);
      expect(release!.version, '1.3.4');
      expect(release.apkUrl, 'https://example.invalid/app.apk');
      expect(release.releaseNotes, contains('• Updater works with APK assets.'));
    });

    test('returns no update for 1.3.4 -> 1.3.4', () {
      final release = AppUpdateService.releaseFromGitHubJson(
        releaseJson(),
        '1.3.4',
      );

      expect(release, isNull);
    });

    test('returns no update when the expected APK asset is missing', () {
      final release = AppUpdateService.releaseFromGitHubJson(
        releaseJson(includeApk: false),
        '1.3.2',
      );

      expect(release, isNull);
    });

    test('accepts a tag without the v prefix', () {
      final release = AppUpdateService.releaseFromGitHubJson(
        releaseJson(tag: '1.3.5'),
        '1.3.4',
      );

      expect(release, isNotNull);
      expect(release!.version, '1.3.5');
    });
  });
}
