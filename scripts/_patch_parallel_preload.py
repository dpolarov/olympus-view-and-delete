from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'Expected block not found in {path}')
    p.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/screens/photo_preview_screen.dart',
    "  void _loadAround(int index) {\n    final generation = ++_preloadGeneration;\n    unawaited(_loadAroundPrioritized(index, generation));\n  }",
    "  void _loadAround(int index) {\n    final generation = ++_preloadGeneration;\n    final currentKey = _cacheKey(_files[index]);\n    _cameraQueue.cancelPendingPreloads(\n      exceptKey: 'preview:$currentKey',\n    );\n    unawaited(_loadAroundPrioritized(index, generation));\n  }",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "    // Priority 3: fetch exactly one neighbor at a time. For every distance the\n    // right-hand photo goes first, then the left: +1, -1, +2, -2, +3, -3.\n    // Before every request we re-check downloads so a new Download stops the\n    // sequence at the next safe boundary.\n    for (int distance = 1; distance <= _keepNeighbors; distance++) {\n      final right = index + distance;\n      if (right < _files.length) {\n        if (!await _waitForDownloadsIdle(index, generation)) return;\n        await _loadImage(right, priority: _priorityNeighborPreload);\n        if (!_isCurrentPreload(index, generation)) return;\n      }\n\n      final left = index - distance;\n      if (left >= 0) {\n        if (!await _waitForDownloadsIdle(index, generation)) return;\n        await _loadImage(left, priority: _priorityNeighborPreload);\n        if (!_isCurrentPreload(index, generation)) return;\n      }\n    }",
    "    // Priority 3: preload neighbors in distance pairs. The right and left\n    // images at the same distance may use two camera connections in parallel,\n    // but we never start the next pair until both have completed. The order is\n    // therefore (+1, -1), then (+2, -2), then (+3, -3).\n    for (int distance = 1; distance <= _keepNeighbors; distance++) {\n      if (!await _waitForDownloadsIdle(index, generation)) return;\n\n      final pair = <Future<void>>[];\n      final right = index + distance;\n      if (right < _files.length) {\n        pair.add(_loadImage(right, priority: _priorityNeighborPreload));\n      }\n      final left = index - distance;\n      if (left >= 0) {\n        pair.add(_loadImage(left, priority: _priorityNeighborPreload));\n      }\n\n      if (pair.isNotEmpty) await Future.wait(pair);\n      if (!_isCurrentPreload(index, generation)) return;\n    }",
)

old_queue = '''class _PreviewCameraQueue {
  final List<_QueuedPreviewTask> _pending = <_QueuedPreviewTask>[];
  bool _running = false;
  bool _disposed = false;
  int _order = 0;

  Future<Uint8List?> schedule({
    required String key,
    required int priority,
    required Future<Uint8List?> Function() run,
  }) {
    if (_disposed) return Future<Uint8List?>.value(null);

    for (final task in _pending) {
      if (task.key == key) {
        if (priority < task.priority) task.priority = priority;
        return task.completer.future;
      }
    }

    final task = _QueuedPreviewTask(
      key: key,
      priority: priority,
      order: _order++,
      run: run,
    );
    _pending.add(task);
    unawaited(_drain());
    return task.completer.future;
  }

  void promote(String key, int priority) {
    for (final task in _pending) {
      if (task.key == key && priority < task.priority) {
        task.priority = priority;
        break;
      }
    }
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (_pending.isNotEmpty && !_disposed) {
        _pending.sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.order.compareTo(b.order);
        });
        final task = _pending.removeAt(0);
        try {
          final value = await task.run();
          if (!task.completer.isCompleted) task.completer.complete(value);
        } catch (error, stackTrace) {
          if (!task.completer.isCompleted) {
            task.completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _running = false;
      if (_pending.isNotEmpty && !_disposed) unawaited(_drain());
    }
  }

  void dispose() {
    _disposed = true;
    for (final task in _pending) {
      if (!task.completer.isCompleted) task.completer.complete(null);
    }
    _pending.clear();
  }
}
'''

new_queue = '''class _PreviewCameraQueue {
  static const int _exclusivePriorityMax = 1;
  static const int _maxParallelPreloads = 2;

  final List<_QueuedPreviewTask> _pending = <_QueuedPreviewTask>[];
  bool _exclusiveRunning = false;
  int _preloadsRunning = 0;
  bool _disposed = false;
  int _order = 0;

  Future<Uint8List?> schedule({
    required String key,
    required int priority,
    required Future<Uint8List?> Function() run,
  }) {
    if (_disposed) return Future<Uint8List?>.value(null);

    for (final task in _pending) {
      if (task.key == key) {
        if (priority < task.priority) task.priority = priority;
        _pump();
        return task.completer.future;
      }
    }

    final task = _QueuedPreviewTask(
      key: key,
      priority: priority,
      order: _order++,
      run: run,
    );
    _pending.add(task);
    _pump();
    return task.completer.future;
  }

  void promote(String key, int priority) {
    for (final task in _pending) {
      if (task.key == key && priority < task.priority) {
        task.priority = priority;
        break;
      }
    }
    _pump();
  }

  void cancelPendingPreloads({String? exceptKey}) {
    final cancelled = _pending
        .where((task) =>
            task.priority > _exclusivePriorityMax && task.key != exceptKey)
        .toList(growable: false);
    _pending.removeWhere((task) => cancelled.contains(task));
    for (final task in cancelled) {
      if (!task.completer.isCompleted) {
        task.completer.completeError(const _PreviewTaskCancelled());
      }
    }
    _pump();
  }

  void _pump() {
    if (_disposed || _exclusiveRunning) return;
    _pending.sort((a, b) {
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.order.compareTo(b.order);
    });

    final exclusiveIndex = _pending.indexWhere(
      (task) => task.priority <= _exclusivePriorityMax,
    );
    if (exclusiveIndex >= 0) {
      // Visible preview and Download are exclusive camera operations. If a
      // preload pair is already in flight, let that pair finish, then the new
      // high-priority task starts before any further preload.
      if (_preloadsRunning > 0) return;
      final task = _pending.removeAt(exclusiveIndex);
      _exclusiveRunning = true;
      unawaited(_runTask(task, preload: false));
      return;
    }

    while (_preloadsRunning < _maxParallelPreloads && _pending.isNotEmpty) {
      final task = _pending.removeAt(0);
      _preloadsRunning++;
      unawaited(_runTask(task, preload: true));
    }
  }

  Future<void> _runTask(
    _QueuedPreviewTask task, {
    required bool preload,
  }) async {
    try {
      final value = await task.run();
      if (!task.completer.isCompleted) task.completer.complete(value);
    } catch (error, stackTrace) {
      if (!task.completer.isCompleted) {
        task.completer.completeError(error, stackTrace);
      }
    } finally {
      if (preload) {
        _preloadsRunning--;
      } else {
        _exclusiveRunning = false;
      }
      _pump();
    }
  }

  void dispose() {
    _disposed = true;
    for (final task in _pending) {
      if (!task.completer.isCompleted) task.completer.complete(null);
    }
    _pending.clear();
  }
}

class _PreviewTaskCancelled implements Exception {
  const _PreviewTaskCancelled();
}
'''
replace_once('lib/screens/photo_preview_screen.dart', old_queue, new_queue)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "    } catch (e) {\n      AppLogger.debug(\n        'preview load failed for ${file.fullPath}: $e',",
    "    } on _PreviewTaskCancelled {\n      if (!mounted) return;\n      setState(() => _loading.remove(key));\n    } catch (e) {\n      AppLogger.debug(\n        'preview load failed for ${file.fullPath}: $e',",
)

replace_once(
    'CHANGELOG.md',
    '- Neighbor full-screen previews now preload strictly one at a time in **right, left, right, left** distance order (`+1, -1, +2, -2, +3, -3`) and wait for foreground/background downloads to finish before continuing.',
    '- Neighbor full-screen previews now preload in controlled **right/left pairs**: `(+1, -1)`, then `(+2, -2)`, then `(+3, -3)`. Each pair may use at most two parallel camera requests; the next pair waits for both to finish, and foreground/background downloads pause further preloading.',
)
