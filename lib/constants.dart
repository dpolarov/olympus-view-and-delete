// lib/constants.dart

import 'theme/olympus_theme.dart';

// Shared camera-shell colors (use theme roles in new widgets).
const kPrimaryColor = OlympusPalette.coral;
const kAccentColor = OlympusPalette.success;
const kBackgroundColor = OlympusPalette.card;
const kBorderColor = OlympusPalette.border;
const kButtonColor = OlympusPalette.raised;
const kErrorColor = OlympusPalette.danger;

// Таймауты и лимиты UI.
// Сервисные тюнинг-константы (кэш, сеть, история) — в services/service_config.dart.
const kCameraConnectTimeoutMs = 1500;
const kBatchFlushMs = 150;

/// Задержка перед возвратом с экрана QR после успешного подключения,
/// чтобы пользователь успел увидеть статус.
const kQrSuccessDelay = Duration(seconds: 2);

/// Таймаут загрузки полноразмерного превью фото.
const kPreviewLoadTimeout = Duration(seconds: 30);

/// Сколько соседних страниц превью держать в памяти с каждой стороны.
const kPreviewKeepNeighbors = 3;

// Строки UI (будут заменены на локализацию)
class AppStrings {
  static const checkingCamera = 'Checking camera...';
  static const connectingTo = 'Connecting to';
  static const wifiConnected = 'WiFi connected, reaching camera...';
  static const wifiFailed = 'WiFi connection failed';
  static const cannotConnect =
      'Cannot connect to camera.\nConnect to camera WiFi first.';
  static const retrying = 'Retrying...';
  static const loadingCameraInfo = 'Loading camera info...';
  static const loadingFileList = 'Loading file list...';
  static const downloadFiles = 'Download Files';
  static const deleteFiles = 'Delete Files';
  static const downloadFirst = 'Select files to download first';
  static const deleteFirst = 'Select files to delete first';
  static const download = 'DOWNLOAD';
  static const delete = 'DELETE';
  // Icon-button tooltips (mixed case, distinct from the all-caps action labels).
  static const downloadTooltip = 'Download';
  static const deleteTooltip = 'Delete';
  static const cancel = 'Cancel';
  static const selectFiles = 'Select Files';
  static const selectAllDelete = 'Select All & Delete';
  static const noFilesFound = 'No files found';
  static const clearFilters = 'Clear filters';
  static const connected = 'Connected';
  static const disconnected = 'Disconnected';
  static const loading = 'Loading...';
  static const about = 'About';
  static const savedCameras = 'Saved cameras';
  static const selectAll = 'Select all';
  static const deselectAll = 'Deselect all';
  static const selectByDates = 'Select all by same dates';
  static const showRaw = 'Show RAW files';
  static const hideRaw = 'Hide RAW files';
  static const info = 'Info';
  static const retryConnection = 'Retry Connection';
  static const scanQr = 'Scan QR Code';
  static const connectWifi = 'Connect WiFi';
}
