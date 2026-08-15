from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Expected text not found in {path}: {old[:120]!r}")
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


# Stable identity for one camera file: path + size + FAT timestamp.
replace_once(
    "lib/services/camera_api.dart",
    "  String get downloadUrl => '$baseUrl$fullPath';\n",
    "  String get downloadUrl => '$baseUrl$fullPath';\n"
    "  String get downloadHistoryKey =>\n"
    "      '$fullPath|$size|$dateRaw|$timeRaw';\n",
)

old_download_signature = """  Future<({int success, int failed, List<String> savedPaths})> downloadFiles(
    List<CameraFile> files,
    String saveDirPath, {
    void Function(int done, int total, String filename)? onProgress,
  }) async {"""
new_download_signature = """  Future<({int success, int failed, List<String> savedPaths})> downloadFiles(
    List<CameraFile> files,
    String saveDirPath, {
    void Function(int done, int total, String filename)? onProgress,
    Future<void> Function(CameraFile file, String savedPath)? onFileSaved,
  }) async {"""
replace_once("lib/services/camera_api.dart", old_download_signature, new_download_signature)
replace_once(
    "lib/services/camera_api.dart",
    "        savedPaths.add(savedPath);\n        success++;",
    "        savedPaths.add(savedPath);\n"
    "        if (onFileSaved != null) {\n"
    "          try {\n"
    "            await onFileSaved(files[i], savedPath);\n"
    "          } catch (e, st) {\n"
    "            AppLogger.warning(\n"
    "              'download history update failed for ${files[i].filename}',\n"
    "              name: 'camera_api',\n"
    "              error: e,\n"
    "              stackTrace: st,\n"
    "            );\n"
    "          }\n"
    "        }\n"
    "        success++;",
)

replace_once(
    "lib/widgets/download_progress_dialog.dart",
    "import '../services/camera_api.dart';\n",
    "import '../services/camera_api.dart';\nimport '../services/download_history.dart';\n",
)
replace_once(
    "lib/widgets/download_progress_dialog.dart",
    "        onProgress: (done, total, filename) {\n",
    "        onFileSaved: (file, _) =>\n"
    "            DownloadHistory.mark(file.downloadHistoryKey),\n"
    "        onProgress: (done, total, filename) {\n",
)

# Downloaded marker in grid/list.
replace_once(
    "lib/widgets/photo_grid.dart",
    "BoxDecoration _itemDecoration(\n    {required bool selected, required double borderWidth}) {\n  return BoxDecoration(\n    borderRadius: BorderRadius.circular(8),\n    border:\n        selected ? Border.all(color: kPrimaryColor, width: borderWidth) : null,\n    color: selected ? kPrimaryColor.withValues(alpha: 0.15) : kBackgroundColor,\n  );\n}\n",
    "BoxDecoration _itemDecoration({\n"
    "  required bool selected,\n"
    "  required bool downloaded,\n"
    "  required double borderWidth,\n"
    "}) {\n"
    "  final borderColor = selected\n"
    "      ? kPrimaryColor\n"
    "      : downloaded\n"
    "          ? const Color(0xFF2ECC71)\n"
    "          : null;\n"
    "  return BoxDecoration(\n"
    "    borderRadius: BorderRadius.circular(8),\n"
    "    border: borderColor == null\n"
    "        ? null\n"
    "        : Border.all(color: borderColor, width: borderWidth),\n"
    "    color: selected\n"
    "        ? kPrimaryColor.withValues(alpha: 0.15)\n"
    "        : downloaded\n"
    "            ? const Color(0xFF2ECC71).withValues(alpha: 0.07)\n"
    "            : kBackgroundColor,\n"
    "  );\n"
    "}\n",
)
replace_once(
    "lib/widgets/photo_grid.dart",
    "  final Set<String> selectedPaths;\n",
    "  final Set<String> selectedPaths;\n  final Set<String> downloadedKeys;\n",
)
replace_once(
    "lib/widgets/photo_grid.dart",
    "    required this.selectedPaths,\n",
    "    required this.selectedPaths,\n    required this.downloadedKeys,\n",
)
photo_grid = Path("lib/widgets/photo_grid.dart")
text = photo_grid.read_text(encoding="utf-8")
needle = "        selected: widget.selectedPaths.contains(widget.files[i].fullPath),\n        selectionMode:"
replacement = (
    "        selected: widget.selectedPaths.contains(widget.files[i].fullPath),\n"
    "        downloaded: widget.downloadedKeys.contains(\n"
    "          widget.files[i].downloadHistoryKey,\n"
    "        ),\n"
    "        selectionMode:"
)
if text.count(needle) != 2:
    raise SystemExit("Expected grid/list selected constructor marker twice")
text = text.replace(needle, replacement)
text = text.replace(
    "  final bool selected;\n  final bool selectionMode;",
    "  final bool selected;\n  final bool downloaded;\n  final bool selectionMode;",
)
text = text.replace(
    "    required this.selected,\n    required this.selectionMode,",
    "    required this.selected,\n    required this.downloaded,\n    required this.selectionMode,",
)
if text.count("final bool downloaded;") != 2:
    raise SystemExit("Expected downloaded field in both item classes")
text = text.replace(
    "decoration: _itemDecoration(selected: selected, borderWidth: 2),",
    "decoration: _itemDecoration(\n"
    "          selected: selected,\n"
    "          downloaded: downloaded,\n"
    "          borderWidth: 2,\n"
    "        ),",
    1,
)
text = text.replace(
    "decoration: _itemDecoration(selected: selected, borderWidth: 1),",
    "decoration: _itemDecoration(\n"
    "          selected: selected,\n"
    "          downloaded: downloaded,\n"
    "          borderWidth: 1,\n"
    "        ),",
    1,
)
grid_marker = """                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: kPrimaryColor,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 16),
                      ),
                    ),
"""
downloaded_marker = """                  if (downloaded)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2ECC71),
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
"""
if grid_marker not in text:
    raise SystemExit("Grid selection marker not found")
text = text.replace(grid_marker, grid_marker + downloaded_marker, 1)
list_marker = """            if (selected)
              Container(
                width: 40,
                height: 72,
                color: kPrimaryColor,
                child: const Icon(Icons.check, color: Colors.white),
              ),
"""
list_downloaded = """            if (!selected && downloaded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.download_done,
                  color: Color(0xFF2ECC71),
                ),
              ),
"""
if list_marker not in text:
    raise SystemExit("List selection marker not found")
photo_grid.write_text(text.replace(list_marker, list_marker + list_downloaded, 1), encoding="utf-8")

# Home screen: startup updater, persistent history and background transfer UI.
replace_once(
    "lib/screens/home_screen.dart",
    "import 'package:flutter/material.dart';\n",
    "import 'package:flutter/material.dart';\n"
    "import 'package:flutter/services.dart' show PlatformException;\n",
)
replace_once(
    "lib/screens/home_screen.dart",
    "import '../services/app_logger.dart';\n",
    "import '../services/app_logger.dart';\n"
    "import '../services/app_update_service.dart';\n"
    "import '../services/background_download_service.dart';\n",
)
replace_once(
    "lib/screens/home_screen.dart",
    "import '../services/connection_history.dart';\n",
    "import '../services/connection_history.dart';\n"
    "import '../services/download_history.dart';\n",
)
replace_once(
    "lib/screens/home_screen.dart",
    "class _HomeScreenState extends State<HomeScreen> {",
    "class _HomeScreenState extends State<HomeScreen>\n"
    "    with WidgetsBindingObserver {",
)
old_lifecycle = """  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _batchFlushTimer?.cancel();
    _api.dispose();
    super.dispose();
  }
"""
new_lifecycle = """  int _totalBytes = 0;
  Set<String> _downloadedKeys = <String>{};
  Timer? _downloadPollTimer;
  AppReleaseInfo? _pendingUpdateAfterPermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startApp());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadPollTimer?.cancel();
    _batchFlushTimer?.cancel();
    _api.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshDownloadedHistory());
      unawaited(_resumePendingUpdate());
      unawaited(_resumeBackgroundMonitor());
    }
  }

  Future<void> _startApp() async {
    await _refreshDownloadedHistory();
    await _checkForAppUpdate();
    if (mounted) unawaited(_initLoad());
  }

  Future<void> _refreshDownloadedHistory() async {
    final keys = await DownloadHistory.load();
    if (!mounted) return;
    setState(() => _downloadedKeys = keys);
  }

  String _localizedText({
    required String en,
    required String ru,
    required String uk,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ru':
        return ru;
      case 'uk':
        return uk;
      default:
        return en;
    }
  }

  Future<void> _checkForAppUpdate() async {
    final release = await AppUpdateService.checkForUpdate();
    if (release == null || !mounted) return;
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackgroundColor,
        title: Text(_localizedText(
          en: 'Update available',
          ru: 'Доступно обновление',
          uk: 'Доступне оновлення',
        )),
        content: Text(_localizedText(
          en: 'Olympus View ${release.version} is available. Download it in the background?',
          ru: 'Доступна версия Olympus View ${release.version}. Скачать обновление в фоне?',
          uk: 'Доступна версія Olympus View ${release.version}. Завантажити оновлення у фоні?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_localizedText(
              en: 'Later', ru: 'Позже', uk: 'Пізніше')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_localizedText(
              en: 'Update', ru: 'Обновить', uk: 'Оновити')),
          ),
        ],
      ),
    );
    if (install == true && mounted) await _beginUpdate(release);
  }

  Future<void> _beginUpdate(AppReleaseInfo release) async {
    final allowed = await AppUpdateService.canInstallUnknownApps();
    if (!mounted) return;
    if (!allowed) {
      _pendingUpdateAfterPermission = release;
      _showSnack(_localizedText(
        en: 'Allow Olympus View to install updates, then return to the app.',
        ru: 'Разрешите Olympus View устанавливать обновления и вернитесь в приложение.',
        uk: 'Дозвольте Olympus View встановлювати оновлення та поверніться до застосунку.',
      ));
      await AppUpdateService.openInstallSettings();
      return;
    }
    await AppUpdateService.startUpdateDownload(release);
    if (!mounted) return;
    _pendingUpdateAfterPermission = null;
    _showSnack(_localizedText(
      en: 'Update is downloading in the background. Tap the notification when it is ready to install.',
      ru: 'Обновление скачивается в фоне. Когда оно будет готово, нажмите уведомление для установки.',
      uk: 'Оновлення завантажується у фоні. Коли воно буде готове, натисніть сповіщення для встановлення.',
    ));
  }

  Future<void> _resumePendingUpdate() async {
    final release = _pendingUpdateAfterPermission;
    if (release == null || !AppUpdateService.supportsExternalUpdates) return;
    if (await AppUpdateService.canInstallUnknownApps()) {
      await _beginUpdate(release);
    }
  }

  void _startBackgroundDownloadMonitor() {
    _downloadPollTimer?.cancel();
    _downloadPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_pollBackgroundDownload());
    });
  }

  Future<void> _pollBackgroundDownload() async {
    await _refreshDownloadedHistory();
    final running = await BackgroundDownloadService.isRunning();
    if (!running) {
      _downloadPollTimer?.cancel();
      _downloadPollTimer = null;
      if (mounted) {
        _showSnack(_localizedText(
          en: 'Background download finished.',
          ru: 'Фоновое скачивание завершено.',
          uk: 'Фонове завантаження завершено.',
        ));
      }
    }
  }

  Future<void> _resumeBackgroundMonitor() async {
    if (!BackgroundDownloadService.isSupported) return;
    if (await BackgroundDownloadService.isRunning()) {
      _startBackgroundDownloadMonitor();
    }
  }
"""
replace_once("lib/screens/home_screen.dart", old_lifecycle, new_lifecycle)

old_after_confirm = """    if (!confirmed || !mounted) return;

    final saveDirPath = await file_saver.getSaveDirectory();"""
new_after_confirm = """    if (!confirmed || !mounted) return;

    if (BackgroundDownloadService.isSupported) {
      final background = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kBackgroundColor,
          title: Text(_localizedText(
            en: 'Download mode',
            ru: 'Режим скачивания',
            uk: 'Режим завантаження',
          )),
          content: Text(_localizedText(
            en: 'Background mode keeps downloading if you switch to another app or turn the screen off.',
            ru: 'Фоновый режим продолжит скачивание, если открыть другое приложение или выключить экран.',
            uk: 'Фоновий режим продовжить завантаження, якщо відкрити інший застосунок або вимкнути екран.',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_localizedText(
                en: 'On screen', ru: 'На экране', uk: 'На екрані')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.downloading),
              label: Text(_localizedText(
                en: 'Background', ru: 'В фоне', uk: 'У фоні')),
            ),
          ],
        ),
      );
      if (!mounted || background == null) return;
      if (background) {
        await Permission.notification.request();
        try {
          await BackgroundDownloadService.start(toDownload);
        } on PlatformException catch (error) {
          if (error.code == 'storage_permission_required') {
            final storage = await Permission.storage.request();
            if (!storage.isGranted) {
              if (mounted) _showSnack('Storage permission is required.');
              return;
            }
            await BackgroundDownloadService.start(toDownload);
          } else {
            if (mounted) {
              _showSnack(error.message ?? 'Could not start background download.');
            }
            return;
          }
        }
        if (!mounted) return;
        _exitSelectionMode();
        _showSnack(_localizedText(
          en: 'Background download started. Progress is shown in notifications.',
          ru: 'Фоновое скачивание запущено. Прогресс виден в уведомлении.',
          uk: 'Фонове завантаження запущено. Прогрес видно у сповіщенні.',
        ));
        _startBackgroundDownloadMonitor();
        return;
      }
    }

    final saveDirPath = await file_saver.getSaveDirectory();"""
replace_once("lib/screens/home_screen.dart", old_after_confirm, new_after_confirm)
replace_once(
    "lib/screens/home_screen.dart",
    "    if (result != null) {\n      _showSnack(\n        'Downloaded: ${result.success}, Failed: ${result.failed}'",
    "    if (result != null) {\n"
    "      await _refreshDownloadedHistory();\n"
    "      if (!mounted) return;\n"
    "      _showSnack(\n"
    "        'Downloaded: ${result.success}, Failed: ${result.failed}'",
)
replace_once(
    "lib/screens/home_screen.dart",
    "                      selectedPaths: _selectedPaths,\n",
    "                      selectedPaths: _selectedPaths,\n"
    "                      downloadedKeys: _downloadedKeys,\n",
)

print("Flutter source integration patched successfully")
