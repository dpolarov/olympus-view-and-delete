from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Expected block not found in {path}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/screens/home_screen.dart',
    "import '../widgets/delete_progress_dialog.dart';\nimport '../widgets/download_progress_dialog.dart';",
    "import '../widgets/delete_progress_dialog.dart';\nimport '../widgets/diagnostics_info_action.dart';\nimport '../widgets/download_progress_dialog.dart';",
)

replace_once(
    'lib/screens/home_screen.dart',
    "class HomeScreen extends StatefulWidget {\n  const HomeScreen({super.key, required this.localeController});\n\n  final LocaleController localeController;",
    "class HomeScreen extends StatefulWidget {\n  const HomeScreen({\n    super.key,\n    required this.localeController,\n    this.onOpenDiagnostics,\n  });\n\n  final LocaleController localeController;\n  final VoidCallback? onOpenDiagnostics;",
)

replace_once(
    'lib/screens/home_screen.dart',
    "  void _openDebugInfo() {\n    unawaited(\n      Navigator.of(context).push<void>(\n        MaterialPageRoute<void>(builder: (_) => const DebugInfoScreen()),\n      ),\n    );\n  }",
    "  void _openDebugInfo() {\n    final rootHandler = widget.onOpenDiagnostics;\n    if (rootHandler != null) {\n      rootHandler();\n      return;\n    }\n    unawaited(\n      Navigator.of(context).push<void>(\n        MaterialPageRoute<void>(builder: (_) => const DebugInfoScreen()),\n      ),\n    );\n  }",
)

replace_once(
    'lib/screens/home_screen.dart',
    "            Semantics(\n              button: true,\n              label: 'About. Long press for diagnostics.',\n              child: InkResponse(\n                radius: 24,\n                onTap: _showAbout,\n                onLongPress: _openDebugInfo,\n                child: const Padding(\n                  padding: EdgeInsets.all(12),\n                  child: Icon(Icons.info_outline),\n                ),\n              ),\n            ),",
    "            DiagnosticsInfoAction(\n              onTap: _showAbout,\n              onDiagnostics: _openDebugInfo,\n            ),",
)

replace_once(
    'lib/screens/home_screen.dart',
    "        TextButton.icon(\n          onPressed: () => launchUrl(\n            Uri.parse(\n              'https://dpolarov.github.io/olympus-view-and-delete/privacy.html',\n            ),\n            mode: LaunchMode.externalApplication,\n          ),\n          icon: const Icon(Icons.privacy_tip_outlined, size: 18),\n          label: const Text('Privacy Policy'),\n        ),\n        const SizedBox(height: 8),\n        const Divider(height: 1),",
    "        TextButton.icon(\n          onPressed: () => launchUrl(\n            Uri.parse(\n              'https://dpolarov.github.io/olympus-view-and-delete/privacy.html',\n            ),\n            mode: LaunchMode.externalApplication,\n          ),\n          icon: const Icon(Icons.privacy_tip_outlined, size: 18),\n          label: const Text('Privacy Policy'),\n        ),\n        const SizedBox(height: 8),\n        TextButton.icon(\n          onPressed: () {\n            Navigator.of(context, rootNavigator: true).pop();\n            WidgetsBinding.instance.addPostFrameCallback((_) {\n              if (mounted) _openDebugInfo();\n            });\n          },\n          icon: const Icon(Icons.bug_report_outlined, size: 18),\n          label: const Text('Debug information'),\n        ),\n        const SizedBox(height: 8),\n        const Divider(height: 1),",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "import '../services/app_logger.dart';\nimport '../services/camera_api.dart';",
    "import '../services/app_logger.dart';\nimport '../services/background_download_service.dart';\nimport '../services/camera_api.dart';",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "  bool _busy = false;\n  Set<String> _downloadedKeys = <String>{};",
    "  bool _busy = false;\n  int _preloadGeneration = 0;\n  Set<String> _downloadedKeys = <String>{};",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "  void _loadAround(int index) {\n    unawaited(_loadAroundPrioritized(index));\n  }\n\n  Future<void> _loadAroundPrioritized(int index) async {\n    if (index < 0 || index >= _files.length) return;\n\n    // Do not even enqueue neighbor network work until the visible frame has\n    // finished (or failed). This makes the user's current screen deterministic.\n    await _loadImage(index, priority: _priorityVisiblePreview);\n    if (!mounted || index != _currentIndex) return;\n\n    // Give an immediately requested Download a short chance to enter the queue\n    // before low-priority neighbor preloads begin.\n    await Future<void>.delayed(const Duration(milliseconds: 100));\n    if (!mounted || index != _currentIndex || _busy) return;\n\n    for (int d = 1; d <= _keepNeighbors; d++) {\n      if (index - d >= 0) {\n        unawaited(_loadImage(\n          index - d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n      if (index + d < _files.length) {\n        unawaited(_loadImage(\n          index + d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n    }\n    _evictFar(index);\n  }",
    "  void _loadAround(int index) {\n    final generation = ++_preloadGeneration;\n    unawaited(_loadAroundPrioritized(index, generation));\n  }\n\n  bool _isCurrentPreload(int index, int generation) =>\n      mounted &&\n      index == _currentIndex &&\n      generation == _preloadGeneration;\n\n  Future<bool> _downloadsAreRunning() async {\n    if (_busy) return true;\n    try {\n      return await BackgroundDownloadService.isRunning();\n    } catch (e) {\n      AppLogger.debug(\n        'background download state unavailable: $e',\n        name: 'photo_preview',\n      );\n      return _busy;\n    }\n  }\n\n  Future<bool> _waitForDownloadsIdle(\n    int index,\n    int generation, {\n    bool initialDelay = false,\n  }) async {\n    if (initialDelay) {\n      // Small idle window: if the user taps Download immediately after the\n      // visible preview appears, that download wins before any neighbor fetch.\n      await Future<void>.delayed(const Duration(milliseconds: 100));\n    }\n\n    while (_isCurrentPreload(index, generation)) {\n      if (!await _downloadsAreRunning()) return true;\n      await Future<void>.delayed(const Duration(milliseconds: 200));\n    }\n    return false;\n  }\n\n  Future<void> _loadAroundPrioritized(int index, int generation) async {\n    if (index < 0 || index >= _files.length) return;\n\n    // Priority 1: the frame currently visible to the user.\n    await _loadImage(index, priority: _priorityVisiblePreview);\n    if (!_isCurrentPreload(index, generation)) return;\n\n    // Priority 2: all foreground/background downloads. Neighbor previews wait\n    // until those downloads are idle, then resume automatically.\n    if (!await _waitForDownloadsIdle(\n      index,\n      generation,\n      initialDelay: true,\n    )) {\n      return;\n    }\n\n    // Priority 3: fetch exactly one neighbor at a time. For every distance the\n    // right-hand photo goes first, then the left: +1, -1, +2, -2, +3, -3.\n    // Before every request we re-check downloads so a new Download stops the\n    // sequence at the next safe boundary.\n    for (int distance = 1; distance <= _keepNeighbors; distance++) {\n      final right = index + distance;\n      if (right < _files.length) {\n        if (!await _waitForDownloadsIdle(index, generation)) return;\n        await _loadImage(right, priority: _priorityNeighborPreload);\n        if (!_isCurrentPreload(index, generation)) return;\n      }\n\n      final left = index - distance;\n      if (left >= 0) {\n        if (!await _waitForDownloadsIdle(index, generation)) return;\n        await _loadImage(left, priority: _priorityNeighborPreload);\n        if (!_isCurrentPreload(index, generation)) return;\n      }\n    }\n    _evictFar(index);\n  }",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "      });\n      _loadAround(_currentIndex);\n      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text('${AppStrings.download}: ${file.filename}')),\n      );",
    "      });\n      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text('${AppStrings.download}: ${file.filename}')),\n      );",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "    } finally {\n      if (mounted) setState(() => _busy = false);\n    }\n  }\n\n  Future<void> _deleteCurrent() async {",
    "    } finally {\n      if (mounted) {\n        setState(() => _busy = false);\n        // Restart deterministic right-first neighbor preloading after the\n        // foreground download completes. Cached neighbors are skipped cheaply.\n        _loadAround(_currentIndex);\n      }\n    }\n  }\n\n  Future<void> _deleteCurrent() async {",
)

replace_once('pubspec.yaml', 'version: 1.3.4+12', 'version: 1.3.4+13')
replace_once("lib/version.dart", "const String appBuild = '12';", "const String appBuild = '13';")

replace_once(
    'CHANGELOG.md',
    '- Diagnostic test build bumped to **1.3.4+12**.',
    '- Neighbor full-screen previews now preload strictly one at a time in **right, left, right, left** distance order (`+1, -1, +2, -2, +3, -3`) and wait for foreground/background downloads to finish before continuing.\n- Diagnostics navigation is deferred through the root navigator; holding the About icon now uses raw pointer timing, and About includes a visible **Debug information** fallback button for devices that reserve multi-finger gestures.\n- Diagnostic test build bumped to **1.3.4+13**.',
)
