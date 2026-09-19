# Changelog

## [Unreleased]

## [1.3.9] - 2026-09-19

### Added
- **Persistent three-state file type filter**: the gallery can now show **RAW only**, **JPG only**, or **RAW + JPG** instead of the previous two-state RAW toggle.
- RAW mode includes `.ORF`, `.DNG`, and `.RAW`; JPG mode includes `.JPG` and `.JPEG`.
- The selected file type mode is saved in `SharedPreferences` and restored on the next app launch. Existing installs with no saved value default to **JPG only**, matching the previous behavior.
- Added regression tests for file-extension filtering and persisted filter restoration.

### Changed
- Version set to **1.3.9+18**.
- Users already on **v1.3.6 or newer** can install this release as a normal in-app update using the existing permanent production signing identity.

## [1.3.8] - 2026-09-19

### Fixed
- **Android RAW downloads to DCIM**: Olympus `.ORF`, Adobe `.DNG`, and generic `.RAW` files are now stored through `MediaStore.Images` instead of `MediaStore.Files`, allowing Android 10+ to save them into `DCIM/OlympusView` just like JPEG files.
- The same RAW MediaStore routing is used by both foreground and background downloads.
- A RAW file is marked as downloaded only after the save completes successfully, so the existing green downloaded marker stays consistent with files actually written to the device.

### Changed
- Version set to **1.3.8+17**.
- This is a normal in-app update for users already on **1.3.6 or newer** and uses the existing permanent production signing identity.

## [1.3.7] - 2026-08-27

### Android signing compatibility
- Users already on **1.3.6 or newer** can update normally. Users on **1.3.5 or older** still need the one-time uninstall/reinstall introduced by 1.3.6 because those older APKs were signed with the temporary legacy certificate.

### Added
- **On-device camera integration tests** with an in-process fake Olympus camera over real TCP sockets. The new suite covers gallery/preview browsing, real filesystem cache persistence, thumbnail concurrency, HTTP failures and camera disconnects/truncated transfers.
- **Failure-path cache tests** verify that HTTP 500 responses, non-JPEG bodies and truncated JPEG transfers never enter the thumbnail or full-screen preview caches.

### Changed
- Thumbnail loading now completes its disk-cache lookup before consuming a camera-network slot or starting an HTTP request, preventing cache hits from starving real camera transfers.
- Full-screen preview evicts frames outside the configured neighbor window immediately while paging, keeping memory bounded even when the user swipes faster than preloading can finish.
- Version set to **1.3.7+16**.

### Fixed
- Fixed a thumbnail fetch race where network work could start before the disk-cache lookup resolved, wasting limited camera connections and delaying visible images.
- Fixed unbounded growth of the in-memory full-screen preview cache during rapid paging.
- `CameraApi.downloadFile` now rejects non-200 responses instead of saving an HTTP error body as if it were the requested photo/video.
- Failed or interrupted camera transfers are no longer allowed to poison persistent image caches.

## [1.3.6] - 2026-08-16

### Important — one-time reinstall for 1.3.5 and older
- **Android signing certificate changed** from the temporary legacy debug certificate to the permanent production app-signing certificate. Android cannot update across unrelated signing certificates, so users of **1.3.5 and older must uninstall Olympus View and install 1.3.6 once**. Future GitHub APK updates will then work normally without another reinstall.
- Uninstalling the old build clears Olympus View's local settings and downloaded-file marker history. It does **not** delete photos already saved on the phone or files on the camera.

### Added
- **Visible app-update progress**: the GitHub build shows APK bytes/total and percent directly in Olympus View instead of disappearing into an opaque background download.
- **Update network status and recovery**: paused downloads clearly show when Android is waiting for internet; failed downloads can be retried and active downloads can be cancelled.
- **Install from inside the app**: when the APK reaches `DownloadManager.STATUS_SUCCESSFUL`, Olympus View opens the Android installer and also keeps an **Install** button available as a fallback even when notifications are disabled.
- **Select downloaded files**: selection mode now has a green `download_done` action that selects every currently visible file carrying the persistent green downloaded marker, making it easy to delete already-copied files from the camera.
- **Production signing setup tool**: `scripts/generate_android_signing_keys.ps1` generates a long-lived production app-signing key plus a separate Google Play upload key and prepares the required GitHub Actions secret values locally.

### Changed
- Camera auto-connect is suppressed while an application update is downloading so connecting to a camera Wi-Fi network without internet cannot silently stall the APK download.
- Notification permission is no longer required to start an app update; in-app progress and installation controls remain available without notifications.
- GitHub release builds now require an explicit production keystore and refuse the legacy debug certificate. The release workflow verifies the production certificate SHA-256 stored in GitHub Secrets.
- Google Play AAB builds use and verify a **separate upload key**. The production app-signing key is intended to be supplied to Play App Signing so GitHub and Play installations share the same final signing identity.
- Version set to **1.3.6+15**.

### Fixed
- Starting an in-app update no longer leaves the user with no visible indication of whether the APK is downloading, paused, failed or ready to install.
- Auto-connecting to the camera can no longer steal internet connectivity while an APK update is active.

## [1.3.5] - 2026-08-16

### Added
- **Updater end-to-end test release**: a normal public GitHub release so installed `1.3.4+13` GitHub builds can exercise the complete in-app update path against a real newer version.
- **Updater regression tests** cover numeric version comparison, `1.3.2 -> 1.3.4`, same-version rejection, exact `OlympusView-Android.apk` asset selection, missing-APK rejection and release-note normalization.

### Changed
- Version bumped to **1.3.5+14**. Application behavior is otherwise the same as 1.3.4; this release exists primarily to verify download and installation through the built-in GitHub updater.

## [1.3.4] - 2026-08-16

### Added
- **GitHub APK auto-update**: the direct Android build checks the latest GitHub release at startup, can download a newer APK in the background and shows an install-ready notification. The Google Play flavor explicitly disables external APK updates.
- **Persistent downloaded-file markers**: successfully downloaded camera files are remembered by camera path, size and FAT timestamp and remain highlighted after app restarts and normal app updates.
- **Android background camera downloads**: selected files can continue downloading through a `connectedDevice` foreground service while Olympus View is backgrounded or the screen is off, with progress and completion notifications.
- **Runtime diagnostics**: four-finger gesture, long-press About entry and a visible Debug information fallback open a diagnostics screen with installed version/build, embedded build metadata, device/ABI, display/memory/storage, active network, camera endpoint, permissions and download state without exposing saved Wi-Fi passwords.

### Changed
- Full-screen camera traffic now prioritizes the **visible preview first**, an active file download second, and neighboring preview preloads last; gallery thumbnail network work pauses while the viewer is open.
- Neighbor previews preload in controlled **right/left pairs**: `(+1, -1)`, then `(+2, -2)`, then `(+3, -3)`, with at most two parallel camera requests per pair and preloading paused during foreground/background downloads.
- About reads the installed Android package version/build at runtime instead of relying on a duplicated Dart constant.
- Android distribution is split into `github` and `play` flavors so the GitHub APK can self-update while the Play build does not request `REQUEST_INSTALL_PACKAGES`.
- Android `versionName` and `versionCode` come directly from the Flutter Gradle plugin.
- Local release builds now clean stale Flutter/Android artifacts, embed build time/Git commit/Flutter version and strictly verify packaged Dart AOT metadata; `install.cmd` force-stops the old process, verifies the installed version and starts a fresh process after replacement.
- Version set to **1.3.4+13**.

### Fixed
- Downloading while the current preview is still loading no longer leaves the preview spinner stuck; downloaded JPEG bytes can immediately satisfy the preview.
- Full-screen preview now shows the green downloaded marker for files already present in persistent download history.
- Diagnostics navigation is deferred through the root navigator and raw-pointer handling makes the multi-touch/About entry deterministic on devices that coalesce or reserve gestures.
- Release builds no longer risk packaging stale `libapp.so` from a previous build; CI/local metadata verification rejects mismatched AOT output.
- Latest Android CI passes analyzer, the full test suite, release APK/AAB builds, package-version verification, Dart AOT metadata verification, Play-flavor policy validation and 16 KB page-size compatibility.

## [1.3.2] - 2026-08-15

### Added
- **Android APK + AAB CI builds** with `flutter analyze`, the full test suite, release APK compilation and App Bundle compilation.
- **16 KB page-size compatibility check** for the Android 64-bit ABIs (`arm64-v8a` and `x86_64`) required by modern Google Play / Android devices.
- **Safe signed-release workflow**: GitHub Actions restores the signing keystore only at build time, verifies its certificate SHA-256, builds APK/AAB and removes signing material afterwards.
- **Modern Android storage integration**: downloaded photos are saved through `MediaStore` into `DCIM/OlympusView` on Android 10+ so broad storage access is no longer required.
- **Android 13+ Wi-Fi permission handling** using `NEARBY_WIFI_DEVICES`; legacy fine-location access is limited to Android 12L and older where required by the Wi-Fi APIs.
- **Android launcher/adaptive icon** based on the existing Olympus View camera mark.
- Google Play preparation documentation, Android signing documentation and release checks.

### Changed
- Version bumped to **1.3.2+6**.
- Android build stack aligned to **compileSdk/targetSdk 36**, **AGP 8.10.1**, **Gradle 8.11.1** and **JDK 17**, with plugin versions defined in one place.
- `mobile_scanner` updated to **6.0.11**, bringing newer CameraX / bundled ML Kit Android components and 16 KB-compatible 64-bit native libraries.
- Android release builds no longer silently fall back to a debug signing key unless explicitly enabled for non-publishing CI validation.
- CI is currently focused on Android; Windows/Web build refinements are deferred to a later pass.
- Removed tracked local Android build state (`android/local.properties`, `.gradle` cache and stale generated plugin registrant) from the repository.

### Fixed
- Release APK and AAB now build successfully in GitHub Actions.
- Fixed the 16 KB checker so it validates ELF `LOAD` segment alignment correctly and follows Android's 64-bit ABI verification scope.
- Fixed Android photo saving under scoped storage on recent Android versions.
- Fixed stale Android plugin registration that referenced removed dependencies.
- Fixed multiple analyzer/lint issues so the quality gate passes cleanly.

## [1.3.1] - 2026-05-29

### Added
- **In-app language selection**: a language picker in the app bar lets you switch the UI between System, English, Русский and Українська at runtime; the choice is persisted across launches (`LocaleController` + `SharedPreferences`) and drives `MaterialApp.locale`

## [1.3.0] - 2026-05-29

### Added
- **Unified logging** (`AppLogger`): cross-platform logger built on `dart:developer` with `debug/info/warning/error` levels; release builds suppress logs below `warning`
- **Centralised service tuning** (`lib/services/service_config.dart`): named constants for network timeouts, cache/memory limits, connection-history size and preview resolution (no Flutter UI dependency)
- **In-memory thumbnail cache byte cap** (`kMaxMemThumbBytes`, 32 MiB): the thumbnail LRU now bounds RAM by total bytes in addition to entry count, so a few unusually large thumbnails can't exhaust RAM; covered by new `thumbnail_manager_test.dart`
- **Network-error test coverage** (`camera_api_network_test.dart`): `CameraApi.listImages`/`deleteFile`/`deleteFiles` now tested against 404s, timeouts, connection failures, malformed records and corrupt FAT dates via an injectable `http.Client`
- **Localization tests** (`l10n_test.dart`): verify key parity across `en`/`ru`/`uk` ARB files, no orphan/empty translations, placeholder consistency, and that every supported locale resolves
- **Shared test helpers** (`test/helpers/test_helpers.dart`): `FakePathProvider` and `fixedResponseClient` extracted from duplicated mock-init code in the disk-cache and preview-screen tests

### Changed
- Replaced silently swallowed `catch (_) {}` blocks across services, screens and dialogs with logged handlers that capture the error and stack trace
- Extracted magic numbers into named constants: camera request/download/probe timeouts, mode-switch delay, disk/memory cache caps, thumbnail concurrency, batch-flush interval, QR success delay, preview load timeout, preview keep-neighbors and preview image size; removed duplicate constants and resolved the `_keepNeighbors` TODO
- Unified filename sanitisation into a single `sanitizeFilename` (`lib/services/filename_sanitizer.dart`), replacing the duplicate copies in `camera_api` and both file savers
- Extracted shared `_showSnack` / `_confirm` helpers in `HomeScreen` (removed duplicated SnackBar and confirmation-dialog code in download/delete handlers) and a shared `_itemDecoration` in `PhotoGrid`
- Stricter linting in `analysis_options.yaml`: `avoid_print` (as error), `use_build_context_synchronously`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `prefer_final_locals`, `directives_ordering`
- Fire-and-forget futures are now explicitly marked with `unawaited(...)`; imports sorted per `directives_ordering`
- Thumbnail fetch timeout now uses the shared `kCameraRequestTimeout` constant instead of an inline literal
- `CameraApi` accepts an optional injected `http.Client` (`CameraApi({client})`) for testability; production behaviour is unchanged
- Upgraded dependencies to their latest compatible versions (`media_scanner`, `shared_preferences`, `url_launcher` and transitive packages)
- Updated the Android toolchain to satisfy the refreshed AndroidX dependencies: `compileSdk`/`targetSdk` 35 → 36, Android Gradle Plugin 8.6.0 → 8.9.1, Gradle wrapper 8.7 → 8.11.1, NDK 26.1 → 28.2

### Fixed
- Preview screen download/delete icon tooltips now read "Download"/"Delete" instead of the all-caps action labels

## [1.2.0] - 2026-04-17

### Added
- **Test Suite**: 61 unit and widget tests covering caching, deletion, paging, QR decoding and connection history
- **Dependency Injection**: Photo preview screen accepts optional `CameraApi` and `http.Client` for testability

### Changed
- Disk cache LRU index writes are now debounced (fewer `SharedPreferences` writes while browsing)
- Hardened filename sanitization for downloaded photos (path traversal, NUL, control chars, Windows reserved names)
- Connection history saves are serialized to prevent race conditions under rapid writes

### Fixed
- Crash (`RangeError`) when deleting the last photo from the preview screen
- Race condition when the disk image cache was accessed before full initialization
- Release APK signing configuration

## [1.1.0] - 2026-04-06

### Added
- **Photo Preview**: Full-screen image viewer with swipe navigation and pinch-to-zoom
- **Preview Download/Delete**: Download or delete photos directly from preview screen (delete with confirmation)
- **Image Preloading**: Preload ±2 neighbor images for smooth swiping
- **Disk Image Cache**: Persistent LRU cache (150 images) for thumbnails and previews across sessions
- **Connection History**: Save and recall previously connected cameras
- **Auto-Connect**: Automatically connect to last used camera on startup
- **Saved Cameras List**: Quick reconnect from error screen without rescanning QR
- **Status Messages**: Detailed connection progress (checking camera, connecting WiFi, loading files...)
- **Version Info**: App version displayed in About dialog

### Changed
- Retry camera connection up to 3 times after WiFi switch (1s delay)
- WiFi connection from saved cameras happens directly without navigating to QR screen
- Loading screen shows context-aware messages instead of generic "Connecting..."

### Fixed
- Error screen content centered horizontally and vertically
- Saved cameras list no longer shifts left when empty

## [1.0.0] - 2026-03-15

### Initial Release
- Connect to Olympus cameras via WiFi (QR code scan or manual SSID/password)
- Browse photos in grid or list view
- Filter photos by date range
- Batch select, download, and delete files
- RAW/ORF file toggle
- Download progress dialog with per-file tracking
- Delete progress dialog with per-file tracking
- Progressive file list loading
- Thumbnail caching (in-memory)
- Android and Web support
