from pathlib import Path

root = Path('.')

# 1) Reliable global four-finger gesture.
p = root / 'lib/widgets/four_finger_debug_trigger.dart'
p.write_text('''import 'dart:async';\n\nimport 'package:flutter/material.dart';\n\n/// Global raw-pointer shortcut for diagnostics.\n///\n/// Opens when four pointers are simultaneously down. Some Android tablet\n/// firmwares briefly cancel/coalesce a pointer during a four-finger touch, so\n/// we also accept four pointer-down events within a short window while at least\n/// three pointers are still down. Normal taps, scrolling and two-finger zoom do\n/// not enter Flutter's gesture arena here.\nclass FourFingerDebugTrigger extends StatefulWidget {\n  const FourFingerDebugTrigger({\n    super.key,\n    required this.child,\n    required this.onTriggered,\n  });\n\n  final Widget child;\n  final VoidCallback onTriggered;\n\n  @override\n  State<FourFingerDebugTrigger> createState() =>\n      _FourFingerDebugTriggerState();\n}\n\nclass _FourFingerDebugTriggerState extends State<FourFingerDebugTrigger> {\n  static const Duration _gestureWindow = Duration(milliseconds: 900);\n\n  final Set<int> _activePointers = <int>{};\n  final List<DateTime> _recentDowns = <DateTime>[];\n  bool _triggeredForCurrentTouch = false;\n  Timer? _resetTimer;\n\n  @override\n  void dispose() {\n    _resetTimer?.cancel();\n    super.dispose();\n  }\n\n  void _pointerDown(PointerDownEvent event) {\n    final now = DateTime.now();\n    _activePointers.add(event.pointer);\n    _recentDowns.removeWhere((time) => now.difference(time) > _gestureWindow);\n    _recentDowns.add(now);\n\n    final simultaneous = _activePointers.length >= 4;\n    final nearSimultaneous =\n        _activePointers.length >= 3 && _recentDowns.length >= 4;\n    if (!_triggeredForCurrentTouch && (simultaneous || nearSimultaneous)) {\n      _triggeredForCurrentTouch = true;\n      widget.onTriggered();\n    }\n\n    _resetTimer?.cancel();\n  }\n\n  void _pointerFinished(PointerEvent event) {\n    _activePointers.remove(event.pointer);\n    if (_activePointers.isEmpty) {\n      _resetTimer?.cancel();\n      _resetTimer = Timer(const Duration(milliseconds: 250), () {\n        if (!mounted || _activePointers.isNotEmpty) return;\n        _recentDowns.clear();\n        _triggeredForCurrentTouch = false;\n      });\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return Listener(\n      behavior: HitTestBehavior.translucent,\n      onPointerDown: _pointerDown,\n      onPointerUp: _pointerFinished,\n      onPointerCancel: _pointerFinished,\n      child: widget.child,\n    );\n  }\n}\n''', encoding='utf-8')

# 2) Remove IconButton tooltip/long-press gesture conflict on About.
p = root / 'lib/screens/home_screen.dart'
s = p.read_text(encoding='utf-8')
old = '''            GestureDetector(\n              behavior: HitTestBehavior.opaque,\n              onLongPress: _openDebugInfo,\n              child: IconButton(\n                icon: const Icon(Icons.info_outline),\n                tooltip: 'About · hold for diagnostics',\n                onPressed: _showAbout,\n              ),\n            ),\n'''
new = '''            Semantics(\n              button: true,\n              label: 'About. Long press for diagnostics.',\n              child: InkResponse(\n                radius: 24,\n                onTap: _showAbout,\n                onLongPress: _openDebugInfo,\n                child: const Padding(\n                  padding: EdgeInsets.all(12),\n                  child: Icon(Icons.info_outline),\n                ),\n              ),\n            ),\n'''
if old not in s:
    raise SystemExit('home info control marker not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# 3) Pause low-value gallery thumbnail network work while full-screen preview is open.
p = root / 'lib/services/thumbnail_manager.dart'
s = p.read_text(encoding='utf-8')
s = s.replace('  int _generation = 0;\n', '  int _generation = 0;\n  bool _networkPaused = false;\n', 1)
marker = '''  /// Update the currently visible item range so the queue can prioritize.\n  void updateVisibleRange(int start, int end) {\n    _visibleStart = start;\n    _visibleEnd = end;\n  }\n'''
replacement = marker + '''\n  /// Pause starting new camera thumbnail HTTP requests. Active requests are\n  /// allowed to finish, but queued work waits. Full-screen preview uses this so\n  /// the camera can prioritize what the user is actively viewing/downloading.\n  void pauseNetwork() {\n    _networkPaused = true;\n  }\n\n  /// Resume queued thumbnail work after full-screen preview closes.\n  void resumeNetwork() {\n    if (!_networkPaused) return;\n    _networkPaused = false;\n    _processQueue();\n  }\n'''
if marker not in s:
    raise SystemExit('thumbnail visible marker not found')
s = s.replace(marker, replacement, 1)
s = s.replace('  void _processQueue() {\n', '  void _processQueue() {\n    if (_networkPaused) return;\n', 1)
p.write_text(s, encoding='utf-8')

# 4) Full-screen preview: one priority queue for camera traffic.
p = root / 'lib/screens/photo_preview_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("import '../services/service_config.dart';\n", "import '../services/service_config.dart';\nimport '../services/thumbnail_manager.dart';\n", 1)
s = s.replace('  static const int _maxPreviewAttempts = 3;\n', '''  static const int _maxPreviewAttempts = 3;\n  static const int _priorityVisiblePreview = 0;\n  static const int _priorityDownload = 1;\n  static const int _priorityNeighborPreload = 2;\n''', 1)
s = s.replace('  final Set<String> _loading = {};\n', '''  final Set<String> _loading = {};\n  final Map<String, Future<void>> _loadFutures = {};\n''', 1)
s = s.replace('  late final CameraApi _api;\n', '''  late final CameraApi _api;\n  final _PreviewCameraQueue _cameraQueue = _PreviewCameraQueue();\n''', 1)
s = s.replace('  bool _busy = false;\n', '  bool _busy = false;\n  Set<String> _downloadedKeys = <String>{};\n', 1)

old = '''    _pageController = PageController(initialPage: _currentIndex);\n    _loadAround(_currentIndex);\n'''
new = '''    _pageController = PageController(initialPage: _currentIndex);\n    ThumbnailManager.instance.pauseNetwork();\n    unawaited(_refreshDownloadedHistory());\n    _loadAround(_currentIndex);\n'''
if old not in s:
    raise SystemExit('preview init marker not found')
s = s.replace(old, new, 1)
old = '''  void dispose() {\n    _pageController.dispose();\n    if (_ownsClient) _client.close();\n    if (_ownsApi) _api.dispose();\n    super.dispose();\n  }\n'''
new = '''  void dispose() {\n    _cameraQueue.dispose();\n    ThumbnailManager.instance.resumeNetwork();\n    _pageController.dispose();\n    if (_ownsClient) _client.close();\n    if (_ownsApi) _api.dispose();\n    super.dispose();\n  }\n'''
if old not in s:
    raise SystemExit('preview dispose marker not found')
s = s.replace(old, new, 1)

marker = '''  String _cacheKey(CameraFile file) => file.downloadHistoryKey;\n'''
addition = '''\n  bool _isDownloaded(CameraFile file) =>\n      _downloadedKeys.contains(file.downloadHistoryKey);\n\n  Future<void> _refreshDownloadedHistory() async {\n    final keys = await DownloadHistory.load();\n    if (!mounted) return;\n    setState(() => _downloadedKeys = keys);\n  }\n'''
if marker not in s:
    raise SystemExit('preview cache key marker not found')
s = s.replace(marker, marker + addition, 1)

old = '''  void _loadAround(int index) {\n    if (index < 0 || index >= _files.length) return;\n    _loadImage(index);\n    for (int d = 1; d <= _keepNeighbors; d++) {\n      if (index - d >= 0) _loadImage(index - d);\n      if (index + d < _files.length) _loadImage(index + d);\n    }\n    _evictFar(index);\n  }\n'''
new = '''  void _loadAround(int index) {\n    if (index < 0 || index >= _files.length) return;\n    unawaited(_loadImage(index, priority: _priorityVisiblePreview));\n    for (int d = 1; d <= _keepNeighbors; d++) {\n      if (index - d >= 0) {\n        unawaited(_loadImage(\n          index - d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n      if (index + d < _files.length) {\n        unawaited(_loadImage(\n          index + d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n    }\n    _evictFar(index);\n  }\n'''
if old not in s:
    raise SystemExit('preview loadAround marker not found')
s = s.replace(old, new, 1)

old_start = s.index('  Future<void> _downloadCurrent() async {')
old_end = s.index('\n  Future<void> _deleteCurrent() async {', old_start)
new_method = '''  Future<void> _downloadCurrent() async {\n    final file = _files[_currentIndex];\n    final key = _cacheKey(file);\n    setState(() => _busy = true);\n    try {\n      // Highest priority is always the image the user is currently waiting to\n      // see. If it is still pending, finish/promote it before starting the full\n      // file download. Downloads then run ahead of all neighbor preloads.\n      await _loadImage(\n        _currentIndex,\n        priority: _priorityVisiblePreview,\n      );\n\n      final bytes = await _cameraQueue.schedule(\n        key: 'download:$key',\n        priority: _priorityDownload,\n        run: () async => Uint8List.fromList(await _api.downloadFile(file)),\n      );\n      if (bytes == null) throw StateError('Camera returned no file data');\n\n      final saveDirPath = kIsWeb ? null : await file_saver.getSaveDirectory();\n      await file_saver.saveFileToDevice(file.filename, bytes, saveDirPath);\n      await DownloadHistory.mark(file.downloadHistoryKey);\n      if (!mounted) return;\n\n      setState(() {\n        _downloadedKeys.add(key);\n        _loading.remove(key);\n        _error.remove(key);\n        if (isCompleteCameraJpeg(bytes)) {\n          // The downloaded original is also a valid full-screen preview. Reuse\n          // it immediately rather than leaving a failed resize request spinning.\n          _imageCache[key] = bytes;\n        }\n      });\n      _loadAround(_currentIndex);\n      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text('${AppStrings.download}: ${file.filename}')),\n      );\n    } catch (e) {\n      if (!mounted) return;\n      setState(() {\n        _loading.remove(key);\n        _error.remove(key);\n      });\n      unawaited(_loadImage(\n        _currentIndex,\n        priority: _priorityVisiblePreview,\n      ));\n      ScaffoldMessenger.of(context).showSnackBar(\n        SnackBar(content: Text('${AppStrings.download} failed: $e')),\n      );\n    } finally {\n      if (mounted) setState(() => _busy = false);\n    }\n  }\n'''
s = s[:old_start] + new_method + s[old_end:]

old_start = s.index('  Future<void> _loadImage(int index) async {')
old_end = s.index('\n  void _onPageChanged(int index) {', old_start)
new_methods = '''  Future<void> _loadImage(\n    int index, {\n    required int priority,\n  }) {\n    if (index < 0 || index >= _files.length) return Future<void>.value();\n    final file = _files[index];\n    final key = _cacheKey(file);\n    if (_imageCache.containsKey(key)) return Future<void>.value();\n\n    final existing = _loadFutures[key];\n    if (existing != null) {\n      _cameraQueue.promote('preview:$key', priority);\n      return existing;\n    }\n\n    late Future<void> future;\n    future = _loadImageInternal(file, key, priority).whenComplete(() {\n      if (identical(_loadFutures[key], future)) {\n        _loadFutures.remove(key);\n      }\n    });\n    _loadFutures[key] = future;\n    return future;\n  }\n\n  Future<void> _loadImageInternal(\n    CameraFile file,\n    String key,\n    int priority,\n  ) async {\n    if (mounted) {\n      setState(() {\n        _loading.add(key);\n        _error.remove(key);\n      });\n    }\n\n    try {\n      final cached = await ImageDiskCache.instance.get(key, 'preview');\n      if (!mounted) return;\n      if (cached != null && isCompleteCameraJpeg(cached)) {\n        setState(() {\n          _imageCache[key] = cached;\n          _loading.remove(key);\n        });\n        return;\n      }\n      if (cached != null) {\n        AppLogger.debug(\n          'discarding incomplete cached preview for ${file.fullPath}',\n          name: 'photo_preview',\n        );\n      }\n\n      final bytes = await _cameraQueue.schedule(\n        key: 'preview:$key',\n        priority: priority,\n        run: () => _fetchPreview(file),\n      );\n      if (!mounted) return;\n      if (bytes != null) {\n        unawaited(ImageDiskCache.instance.put(key, 'preview', bytes).catchError(\n              (Object e) => AppLogger.debug(\n                'preview disk cache put failed: $e',\n                name: 'photo_preview',\n              ),\n            ));\n        setState(() {\n          _imageCache[key] = bytes;\n          _loading.remove(key);\n        });\n      } else {\n        setState(() {\n          _error.add(key);\n          _loading.remove(key);\n        });\n      }\n    } catch (e) {\n      AppLogger.debug(\n        'preview load failed for ${file.fullPath}: $e',\n        name: 'photo_preview',\n      );\n      if (!mounted) return;\n      setState(() {\n        _error.add(key);\n        _loading.remove(key);\n      });\n    }\n  }\n'''
s = s[:old_start] + new_methods + s[old_end:]

old = '''  void _onPageChanged(int index) {\n    setState(() => _currentIndex = index);\n    _loadAround(index);\n  }\n'''
new = '''  void _onPageChanged(int index) {\n    setState(() => _currentIndex = index);\n    // Promote the newly visible item over queued downloads/preloads.\n    _loadAround(index);\n    unawaited(_refreshDownloadedHistory());\n  }\n'''
if old not in s:
    raise SystemExit('preview pageChanged marker not found')
s = s.replace(old, new, 1)

old = '''              IconButton(\n                icon: const Icon(Icons.download, color: kAccentColor),\n                tooltip: AppStrings.downloadTooltip,\n                onPressed: _downloadCurrent,\n              ),\n'''
new = '''              IconButton(\n                icon: Icon(\n                  _isDownloaded(file)\n                      ? Icons.download_done\n                      : Icons.download,\n                  color: kAccentColor,\n                ),\n                tooltip: _isDownloaded(file)\n                    ? 'Already downloaded · tap to download again'\n                    : AppStrings.downloadTooltip,\n                onPressed: _downloadCurrent,\n              ),\n'''
if old not in s:
    raise SystemExit('preview download button marker not found')
s = s.replace(old, new, 1)

# Append priority queue implementation.
append_marker = '\n}\n'
pos = s.rfind(append_marker)
if pos < 0:
    raise SystemExit('preview final class marker not found')
queue_code = '''\n}\n\nclass _PreviewCameraQueue {\n  final List<_QueuedPreviewTask> _pending = <_QueuedPreviewTask>[];\n  bool _running = false;\n  bool _disposed = false;\n  int _order = 0;\n\n  Future<Uint8List?> schedule({\n    required String key,\n    required int priority,\n    required Future<Uint8List?> Function() run,\n  }) {\n    if (_disposed) return Future<Uint8List?>.value(null);\n\n    for (final task in _pending) {\n      if (task.key == key) {\n        if (priority < task.priority) task.priority = priority;\n        return task.completer.future;\n      }\n    }\n\n    final task = _QueuedPreviewTask(\n      key: key,\n      priority: priority,\n      order: _order++,\n      run: run,\n    );\n    _pending.add(task);\n    unawaited(_drain());\n    return task.completer.future;\n  }\n\n  void promote(String key, int priority) {\n    for (final task in _pending) {\n      if (task.key == key && priority < task.priority) {\n        task.priority = priority;\n        break;\n      }\n    }\n  }\n\n  Future<void> _drain() async {\n    if (_running || _disposed) return;\n    _running = true;\n    try {\n      while (_pending.isNotEmpty && !_disposed) {\n        _pending.sort((a, b) {\n          final priorityCompare = a.priority.compareTo(b.priority);\n          if (priorityCompare != 0) return priorityCompare;\n          return a.order.compareTo(b.order);\n        });\n        final task = _pending.removeAt(0);\n        try {\n          final value = await task.run();\n          if (!task.completer.isCompleted) task.completer.complete(value);\n        } catch (error, stackTrace) {\n          if (!task.completer.isCompleted) {\n            task.completer.completeError(error, stackTrace);\n          }\n        }\n      }\n    } finally {\n      _running = false;\n      if (_pending.isNotEmpty && !_disposed) unawaited(_drain());\n    }\n  }\n\n  void dispose() {\n    _disposed = true;\n    for (final task in _pending) {\n      if (!task.completer.isCompleted) task.completer.complete(null);\n    }\n    _pending.clear();\n  }\n}\n\nclass _QueuedPreviewTask {\n  _QueuedPreviewTask({\n    required this.key,\n    required this.priority,\n    required this.order,\n    required this.run,\n  });\n\n  final String key;\n  int priority;\n  final int order;\n  final Future<Uint8List?> Function() run;\n  final Completer<Uint8List?> completer = Completer<Uint8List?>();\n}\n'''
s = s[:pos] + queue_code + s[pos + len(append_marker):]
p.write_text(s, encoding='utf-8')

# 5) Tests: four-finger near-simultaneous fallback.
p = root / 'test/four_finger_debug_trigger_test.dart'
s = p.read_text(encoding='utf-8')
insert = '''\n  testWidgets('four quick downs trigger even if one pointer was cancelled',\n      (tester) async {\n    var triggerCount = 0;\n    await tester.pumpWidget(\n      MaterialApp(\n        home: FourFingerDebugTrigger(\n          onTriggered: () => triggerCount++,\n          child: const SizedBox.expand(),\n        ),\n      ),\n    );\n\n    final first = await tester.startGesture(const Offset(30, 80), pointer: 1);\n    final second = await tester.startGesture(const Offset(60, 80), pointer: 2);\n    final third = await tester.startGesture(const Offset(90, 80), pointer: 3);\n    await first.cancel();\n    final fourth = await tester.startGesture(const Offset(120, 80), pointer: 4);\n    await tester.pump();\n\n    expect(triggerCount, 1);\n    await second.up();\n    await third.up();\n    await fourth.up();\n  });\n'''
last = s.rfind('\n}')
s = s[:last] + insert + s[last:]
p.write_text(s, encoding='utf-8')

# 6) Test downloaded marker in full-screen preview.
p = root / 'test/photo_preview_screen_test.dart'
s = p.read_text(encoding='utf-8')
insert = '''\n  testWidgets('downloaded file shows download-done marker in preview',\n      (tester) async {\n    final file = _file('DONE.JPG');\n    SharedPreferences.setMockInitialValues({\n      'download_history_v1': <String>[file.downloadHistoryKey],\n    });\n    await _pumpPreview(\n      tester,\n      files: [file],\n      initialIndex: 0,\n      api: _FakeApi(),\n    );\n    await _settle(tester);\n\n    expect(find.byIcon(Icons.download_done), findsOneWidget);\n  });\n'''
last = s.rfind('\n}')
s = s[:last] + insert + s[last:]
p.write_text(s, encoding='utf-8')

# 7) Bump diagnostic build so the device test is unambiguous.
p = root / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.4+11', 'version: 1.3.4+12')
p.write_text(s, encoding='utf-8')
p = root / 'lib/version.dart'
s = p.read_text(encoding='utf-8').replace("const String appBuild = '11';", "const String appBuild = '12';")
p.write_text(s, encoding='utf-8')

p = root / 'CHANGELOG.md'
s = p.read_text(encoding='utf-8')
needle = '### Fixed\n'
addition = ('### Fixed\n'
            '- Full-screen camera traffic is now serialized by priority: current visible preview first, active file download second, neighboring preview preloads last. Gallery thumbnail network work pauses while the viewer is open.\n'
            '- Downloading while the current preview is still loading no longer leaves the preview spinner stuck; downloaded JPEG bytes can immediately satisfy the preview.\n'
            '- Full-screen preview now shows a green `download_done` marker for files already recorded in persistent download history.\n'
            '- Diagnostics entry is more reliable: the About icon uses a direct long-press target without an `IconButton` tooltip conflict, and the four-finger recognizer tolerates Android pointer coalescing/cancellation.\n'
            '- Diagnostic test build bumped to **1.3.4+12**.\n')
if needle not in s:
    raise SystemExit('changelog fixed marker not found')
s = s.replace(needle, addition, 1)
p.write_text(s, encoding='utf-8')
