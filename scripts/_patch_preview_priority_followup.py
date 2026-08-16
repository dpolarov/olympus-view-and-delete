from pathlib import Path

root = Path('.')

# Make visible preview deterministic before any neighbor preload is queued.
p = root / 'lib/screens/photo_preview_screen.dart'
s = p.read_text(encoding='utf-8')
old = '''  void _loadAround(int index) {\n    if (index < 0 || index >= _files.length) return;\n    unawaited(_loadImage(index, priority: _priorityVisiblePreview));\n    for (int d = 1; d <= _keepNeighbors; d++) {\n      if (index - d >= 0) {\n        unawaited(_loadImage(\n          index - d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n      if (index + d < _files.length) {\n        unawaited(_loadImage(\n          index + d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n    }\n    _evictFar(index);\n  }\n'''
new = '''  void _loadAround(int index) {\n    unawaited(_loadAroundPrioritized(index));\n  }\n\n  Future<void> _loadAroundPrioritized(int index) async {\n    if (index < 0 || index >= _files.length) return;\n\n    // Do not even enqueue neighbor network work until the visible frame has\n    // finished (or failed). This makes the user's current screen deterministic.\n    await _loadImage(index, priority: _priorityVisiblePreview);\n    if (!mounted || index != _currentIndex) return;\n\n    // Give an immediately requested Download a short chance to enter the queue\n    // before low-priority neighbor preloads begin.\n    await Future<void>.delayed(const Duration(milliseconds: 100));\n    if (!mounted || index != _currentIndex || _busy) return;\n\n    for (int d = 1; d <= _keepNeighbors; d++) {\n      if (index - d >= 0) {\n        unawaited(_loadImage(\n          index - d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n      if (index + d < _files.length) {\n        unawaited(_loadImage(\n          index + d,\n          priority: _priorityNeighborPreload,\n        ));\n      }\n    }\n    _evictFar(index);\n  }\n'''
if old not in s:
    raise SystemExit('loadAround block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Refresh grid download markers whenever returning from full-screen preview.
p = root / 'lib/screens/home_screen.dart'
s = p.read_text(encoding='utf-8')
old = '''                        );\n                        if (deleted == true && mounted) {\n                          unawaited(_loadFiles());\n                        }\n                      },\n'''
new = '''                        );\n                        if (!mounted) return;\n                        await _refreshDownloadedHistory();\n                        if (deleted == true && mounted) {\n                          unawaited(_loadFiles());\n                        }\n                      },\n'''
if old not in s:
    raise SystemExit('home preview return block not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
