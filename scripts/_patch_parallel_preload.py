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
    "import '../services/image_cache.dart';\nimport '../services/service_config.dart';",
    "import '../services/image_cache.dart';\nimport '../services/preview_preload_plan.dart';\nimport '../services/service_config.dart';",
)

replace_once(
    'lib/screens/photo_preview_screen.dart',
    "    // Priority 3: preload neighbors in distance pairs. The right and left\n    // images at the same distance may use two camera connections in parallel,\n    // but we never start the next pair until both have completed. The order is\n    // therefore (+1, -1), then (+2, -2), then (+3, -3).\n    for (int distance = 1; distance <= _keepNeighbors; distance++) {\n      if (!await _waitForDownloadsIdle(index, generation)) return;\n\n      final pair = <Future<void>>[];\n      final right = index + distance;\n      if (right < _files.length) {\n        pair.add(_loadImage(right, priority: _priorityNeighborPreload));\n      }\n      final left = index - distance;\n      if (left >= 0) {\n        pair.add(_loadImage(left, priority: _priorityNeighborPreload));\n      }\n\n      if (pair.isNotEmpty) await Future.wait(pair);\n      if (!_isCurrentPreload(index, generation)) return;\n    }",
    "    // Priority 3: preload neighbors in distance pairs. The planner yields\n    // right first, then left for each distance: (+1, -1), (+2, -2), (+3, -3).\n    // Both members of a pair may use two camera connections concurrently, but\n    // the next pair never starts until this pair has completed.\n    final preloadPairs = buildPreviewPreloadPairs(\n      center: index,\n      itemCount: _files.length,\n      radius: _keepNeighbors,\n    );\n    for (final indexes in preloadPairs) {\n      if (!await _waitForDownloadsIdle(index, generation)) return;\n\n      final pair = indexes\n          .map((neighbor) => _loadImage(\n                neighbor,\n                priority: _priorityNeighborPreload,\n              ))\n          .toList(growable: false);\n      await Future.wait(pair);\n      if (!_isCurrentPreload(index, generation)) return;\n    }",
)
