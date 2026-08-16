/// Builds deterministic neighbor preload pairs around [center].
///
/// Every inner list is one preload wave. The right-hand neighbor is listed
/// first, followed by the left-hand neighbor at the same distance. A caller may
/// execute the two items in a wave in parallel, but should await the whole wave
/// before starting the next one.
List<List<int>> buildPreviewPreloadPairs({
  required int center,
  required int itemCount,
  required int radius,
}) {
  if (itemCount <= 0 || radius <= 0 || center < 0 || center >= itemCount) {
    return const <List<int>>[];
  }

  final result = <List<int>>[];
  for (var distance = 1; distance <= radius; distance++) {
    final pair = <int>[];
    final right = center + distance;
    if (right < itemCount) pair.add(right);

    final left = center - distance;
    if (left >= 0) pair.add(left);

    if (pair.isNotEmpty) result.add(pair);
  }
  return result;
}
