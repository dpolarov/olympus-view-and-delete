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
    expect(fileMatchesTypeFilter('P0001.MP4', FileTypeFilter.both), isFalse);
  });
}
