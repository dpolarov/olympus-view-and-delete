import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/file_type_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to JPG for existing installs', () async {
    expect(await FileTypeFilterPreferences.load(), FileTypeFilter.jpg);
  });

  test('persists the selected filter', () async {
    await FileTypeFilterPreferences.save(FileTypeFilter.raw);
    expect(await FileTypeFilterPreferences.load(), FileTypeFilter.raw);

    await FileTypeFilterPreferences.save(FileTypeFilter.both);
    expect(await FileTypeFilterPreferences.load(), FileTypeFilter.both);
  });

  test('invalid saved value falls back to JPG', () async {
    SharedPreferences.setMockInitialValues({'file_type_filter': 'invalid'});
    expect(await FileTypeFilterPreferences.load(), FileTypeFilter.jpg);
  });

  test('filters RAW, JPG, and both', () {
    expect(fileMatchesTypeFilter('P0001.ORF', FileTypeFilter.raw), isTrue);
    expect(fileMatchesTypeFilter('P0001.DNG', FileTypeFilter.raw), isTrue);
    expect(fileMatchesTypeFilter('P0001.RAW', FileTypeFilter.raw), isTrue);
    expect(fileMatchesTypeFilter('P0001.JPG', FileTypeFilter.raw), isFalse);

    expect(fileMatchesTypeFilter('P0001.JPG', FileTypeFilter.jpg), isTrue);
    expect(fileMatchesTypeFilter('P0001.JPEG', FileTypeFilter.jpg), isTrue);
    expect(fileMatchesTypeFilter('P0001.ORF', FileTypeFilter.jpg), isFalse);

    expect(fileMatchesTypeFilter('P0001.JPG', FileTypeFilter.both), isTrue);
    expect(fileMatchesTypeFilter('P0001.ORF', FileTypeFilter.both), isTrue);
  });

  test('video files stay visible for every still-photo filter', () {
    for (final filter in FileTypeFilter.values) {
      expect(fileMatchesTypeFilter('P0001.MOV', filter), isTrue);
      expect(fileMatchesTypeFilter('P0001.MP4', filter), isTrue);
      expect(fileMatchesTypeFilter('P0001.M4V', filter), isTrue);
      expect(fileMatchesTypeFilter('P0001.AVI', filter), isTrue);
      expect(fileMatchesTypeFilter('P0001.MTS', filter), isTrue);
      expect(fileMatchesTypeFilter('P0001.M2TS', filter), isTrue);
    }
  });

  test('RAW and movie files prefer the thumbnail endpoint in the grid', () {
    expect(prefersThumbnailGridPreview('P0001.ORF'), isTrue);
    expect(prefersThumbnailGridPreview('P0001.DNG'), isTrue);
    expect(prefersThumbnailGridPreview('P0001.RAW'), isTrue);
    expect(prefersThumbnailGridPreview('P0001.MOV'), isTrue);
    expect(prefersThumbnailGridPreview('P0001.MP4'), isTrue);
    expect(prefersThumbnailGridPreview('P0001.JPG'), isFalse);
    expect(prefersThumbnailGridPreview('P0001.JPEG'), isFalse);
  });
}
