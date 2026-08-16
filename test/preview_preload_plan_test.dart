import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/preview_preload_plan.dart';

void main() {
  test('builds right-left pairs out to radius three', () {
    expect(
      buildPreviewPreloadPairs(center: 3, itemCount: 7, radius: 3),
      <List<int>>[
        <int>[4, 2],
        <int>[5, 1],
        <int>[6, 0],
      ],
    );
  });

  test('keeps right-first expansion at list edges', () {
    expect(
      buildPreviewPreloadPairs(center: 0, itemCount: 5, radius: 3),
      <List<int>>[
        <int>[1],
        <int>[2],
        <int>[3],
      ],
    );
    expect(
      buildPreviewPreloadPairs(center: 4, itemCount: 5, radius: 3),
      <List<int>>[
        <int>[3],
        <int>[2],
        <int>[1],
      ],
    );
  });
}
