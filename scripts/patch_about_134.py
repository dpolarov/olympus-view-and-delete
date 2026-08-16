from pathlib import Path

home_path = Path('lib/screens/home_screen.dart')
changelog_path = Path('CHANGELOG.md')

home = home_path.read_text(encoding='utf-8')
old = """        const Text(
          '• Full-screen photo preview with swipe & zoom\\n'
          '• Download/Delete from preview screen\\n'
          '• Image preloading for smooth swiping\\n'
          '• Persistent disk cache for thumbnails & previews\\n'
          '• Auto-connect to last used camera\\n'
          '• Saved cameras quick reconnect\\n'
          '• Detailed connection status messages',
          style: TextStyle(fontSize: 13),
        ),"""
new = """        const Text(
          '• Background downloads with Android notifications\\n'
          '• Persistent green markers for downloaded files\\n'
          '• GitHub APK auto-update with release notes\\n'
          '• More reliable thumbnails with validation and retries\\n'
          '• Full-screen preview with swipe & zoom\\n'
          '• Batch download and delete directly from the camera\\n'
          '• Auto-connect and saved-camera quick reconnect',
          style: TextStyle(fontSize: 13),
        ),"""
if old not in home:
    raise SystemExit('About changelog block not found')
home_path.write_text(home.replace(old, new, 1), encoding='utf-8')

changelog = changelog_path.read_text(encoding='utf-8')
marker = """### Changed
- Android distribution is split into `github` and `play` flavors so the GitHub APK can request package installation while the Play bundle does not request `REQUEST_INSTALL_PACKAGES`.
"""
replacement = """### Changed
- Android distribution is split into `github` and `play` flavors so the GitHub APK can request package installation while the Play bundle does not request `REQUEST_INSTALL_PACKAGES`.
- Android `versionName` and `versionCode` now come directly from the Flutter Gradle plugin instead of potentially stale values in `android/local.properties`.
- `build_release.cmd` now requires the `master` branch, prints the source commit/version, passes explicit build-name/build-number values and verifies the finished APK manifest when `aapt` is available.
- `install.cmd` now prints the actually installed Android `versionName`/`versionCode` after `adb install -r`.
- The in-app About changelog now highlights the current 1.3.4 Android features instead of the older preview-only list.
"""
if marker not in changelog:
    raise SystemExit('CHANGELOG Changed block not found')
changelog_path.write_text(changelog.replace(marker, replacement, 1), encoding='utf-8')

print('About and changelog patched')
