from pathlib import Path

home = Path("lib/screens/home_screen.dart")
text = home.read_text(encoding="utf-8")
old = """    await AppUpdateService.startUpdateDownload(release);
    if (!mounted) return;
    _pendingUpdateAfterPermission = null;
"""
new = """    final notifications = await Permission.notification.request();
    if (!notifications.isGranted) {
      if (mounted) {
        _showSnack(_localizedText(
          en: 'Notifications are required so Olympus View can tell you when the update is ready to install.',
          ru: 'Разрешите уведомления, чтобы Olympus View сообщил, когда обновление будет готово к установке.',
          uk: 'Дозвольте сповіщення, щоб Olympus View повідомив, коли оновлення буде готове до встановлення.',
        ));
      }
      return;
    }
    await AppUpdateService.startUpdateDownload(release);
    if (!mounted) return;
    _pendingUpdateAfterPermission = null;
"""
if old not in text:
    raise SystemExit("Updater insertion point not found")
home.write_text(text.replace(old, new, 1), encoding="utf-8")

changelog = Path("CHANGELOG.md")
text = changelog.read_text(encoding="utf-8")
marker = "## [Unreleased]\n"
block = """## [Unreleased]

### Added
- **GitHub APK auto-update check**: the Android GitHub build checks the latest published GitHub release at startup, offers newer versions, downloads the APK in the background and shows an install-ready notification. The Google Play flavor explicitly disables external APK updates.
- **Persistent downloaded-file markers**: successfully downloaded camera files are recorded by camera path, size and FAT timestamp and remain highlighted after app restarts and normal app updates.
- **Android background camera downloads**: selected files can continue downloading through a `connectedDevice` foreground service while Olympus View is backgrounded or the screen is off, with progress and completion notifications.

### Changed
- Android distribution is split into `github` and `play` flavors so the GitHub APK can request package installation while the Play bundle does not request `REQUEST_INSTALL_PACKAGES`.
"""
if marker not in text:
    raise SystemExit("Unreleased changelog marker not found")
changelog.write_text(text.replace(marker, block, 1), encoding="utf-8")
