# Changelog

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
- **Image Preloading**: Preload ±2 neighbor images for smooth swiping in preview
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
