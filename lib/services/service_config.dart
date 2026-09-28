/// Tuning constants for the service layer.
///
/// Kept separate from `lib/constants.dart` (which pulls in `package:flutter`
/// for colors/UI strings) so pure-Dart services don't take a Flutter UI
/// dependency just to read a number.
library;

// --- Network timeouts (camera_api) ---

/// Default timeout for most camera HTTP requests (list, info, mode switch).
const Duration kCameraRequestTimeout = Duration(seconds: 10);

/// Timeout for a single file download (large transfers over WiFi).
const Duration kCameraDownloadTimeout = Duration(seconds: 120);

/// Timeout for the reachability probe in `testConnection`.
const Duration kCameraProbeTimeout = Duration(seconds: 5);

/// Settle delay after switching the camera into play mode before listing.
const Duration kCameraModeSwitchDelay = Duration(milliseconds: 500);

/// Long edge (px) requested from the camera's resize endpoint for previews.
const int kPreviewImageSize = 1920;

// --- Caching / memory (image_cache, thumbnail_manager) ---

/// Max number of images kept in the persistent disk cache (all variants).
const int kMaxCacheImages = 1000;

/// Debounce window before flushing the disk-cache LRU index to storage.
const Duration kLruSaveDebounce = Duration(seconds: 2);

/// Max thumbnails kept in the in-memory LRU cache (bounds RAM by count).
const int kMaxMemThumbs = 300;

/// Max total bytes kept in the in-memory thumbnail LRU cache. A second cap
/// alongside [kMaxMemThumbs] so a handful of unusually large thumbnails can't
/// blow RAM even when the count is within bounds. 32 MiB.
const int kMaxMemThumbBytes = 32 * 1024 * 1024;

/// Max concurrent thumbnail downloads.
const int kMaxConcurrentThumbs = 3;

// --- Connection history ---

/// Max number of saved camera connections retained.
const int kMaxHistory = 10;
