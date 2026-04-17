import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';

CameraFile _file({
  String dir = '/DCIM/100OLYMP',
  String name = 'P1.JPG',
  int size = 1000,
  DateTime? date,
}) {
  final d = date ?? DateTime(2024, 6, 1, 12, 0);
  return CameraFile(
    directory: dir,
    filename: name,
    size: size,
    attributes: 0,
    dateRaw: 0,
    timeRaw: 0,
    date: d,
  );
}

void main() {
  group('CameraFile.decodeFatDateTime', () {
    test('decodes valid FAT datetime', () {
      // 2024-06-15 14:30:20
      // year offset 2024-1980=44 → 44<<9 = 22528
      // month 6 <<5 = 192; day 15 = 15 → date = 22528|192|15 = 22735
      final date = 22735;
      // hour 14 <<11 = 28672; minute 30 <<5 = 960; sec 10 (20/2) = 10 → 29642
      final time = 29642;
      final dt = CameraFile.decodeFatDateTime(date, time);
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
      expect(dt.month, 6);
      expect(dt.day, 15);
      expect(dt.hour, 14);
      expect(dt.minute, 30);
      expect(dt.second, 20);
    });

    test('returns null when month is 0', () {
      // date with month bits zero, day=1
      final date = (44 << 9) | 1; // year 2024, month 0, day 1
      final time = 0;
      expect(CameraFile.decodeFatDateTime(date, time), isNull);
    });

    test('returns null when day is 0', () {
      final date = (44 << 9) | (6 << 5); // year 2024, month 6, day 0
      expect(CameraFile.decodeFatDateTime(date, 0), isNull);
    });

    test('returns null when hour out of range', () {
      final date = (44 << 9) | (6 << 5) | 15;
      final time = (24 << 11); // hour 24 invalid — actually 24 is 5 bits wraps to 24; 24>23
      // Since `>> 11 & 0x1F` max is 31; 24 > 23
      expect(CameraFile.decodeFatDateTime(date, time), isNull);
    });

    test('returns null when month 13+', () {
      final date = (44 << 9) | (13 << 5) | 1;
      expect(CameraFile.decodeFatDateTime(date, 0), isNull);
    });
  });

  group('CameraFile.formatSize', () {
    test('formats bytes', () {
      expect(CameraFile.formatSize(0), '0 B');
      expect(CameraFile.formatSize(1023), '1023 B');
    });

    test('formats KB', () {
      expect(CameraFile.formatSize(1024), '1.0 KB');
      expect(CameraFile.formatSize(2048), '2.0 KB');
    });

    test('formats MB', () {
      expect(CameraFile.formatSize(1024 * 1024), '1.0 MB');
      expect(CameraFile.formatSize(5 * 1024 * 1024 + 512 * 1024), '5.5 MB');
    });

    test('formats GB', () {
      expect(CameraFile.formatSize(1024 * 1024 * 1024), '1.00 GB');
      expect(CameraFile.formatSize(3 * 1024 * 1024 * 1024 + 512 * 1024 * 1024),
          '3.50 GB');
    });

    test('instance sizeHuman matches static', () {
      final f = _file(size: 3 * 1024 * 1024);
      expect(f.sizeHuman, CameraFile.formatSize(3 * 1024 * 1024));
    });
  });

  group('sanitizeFilename', () {
    test('keeps safe name unchanged', () {
      expect(sanitizeFilename('P1010001.JPG'), 'P1010001.JPG');
    });

    test('strips path components', () {
      expect(sanitizeFilename('../../etc/passwd'), 'passwd');
      expect(sanitizeFilename(r'..\..\windows\system32.dll'), 'system32.dll');
      expect(sanitizeFilename('/DCIM/100/P1.JPG'), 'P1.JPG');
    });

    test('collapses directory-traversal-only input', () {
      expect(sanitizeFilename('..').startsWith('file_'), isTrue);
      expect(sanitizeFilename('.').startsWith('file_'), isTrue);
      expect(sanitizeFilename('').startsWith('file_'), isTrue);
    });

    test('strips NUL and control chars', () {
      expect(sanitizeFilename('ok\u0000name.jpg'), 'okname.jpg');
      expect(sanitizeFilename('a\tb\nc.jpg'), 'abc.jpg');
    });

    test('replaces Windows reserved chars', () {
      expect(sanitizeFilename('a:b|c?.jpg'), 'a_b_c_.jpg');
    });

    test('caps length to 180', () {
      final name = 'A' * 300 + '.jpg';
      final result = sanitizeFilename(name);
      expect(result.length, 180);
    });
  });

  group('CameraApi.filterByDate / filterByDateRange / getUniqueDates', () {
    final files = [
      _file(name: 'a.jpg', date: DateTime(2024, 1, 10, 10)),
      _file(name: 'b.jpg', date: DateTime(2024, 1, 10, 14)),
      _file(name: 'c.jpg', date: DateTime(2024, 2, 5, 9)),
      _file(name: 'd.jpg', date: DateTime(2024, 3, 20, 12)),
    ];

    test('filterByDate returns matches for exact day', () {
      final r = CameraApi.filterByDate(files, '2024-01-10');
      expect(r.map((f) => f.filename), ['a.jpg', 'b.jpg']);
    });

    test('filterByDate returns empty for missing day', () {
      expect(CameraApi.filterByDate(files, '2024-12-31'), isEmpty);
    });

    test('filterByDateRange inclusive on both ends', () {
      final r = CameraApi.filterByDateRange(
        files,
        DateTime(2024, 1, 10),
        DateTime(2024, 2, 5),
      );
      expect(r.map((f) => f.filename), ['a.jpg', 'b.jpg', 'c.jpg']);
    });

    test('filterByDateRange with only `from`', () {
      final r = CameraApi.filterByDateRange(files, DateTime(2024, 2, 1), null);
      expect(r.map((f) => f.filename), ['c.jpg', 'd.jpg']);
    });

    test('filterByDateRange with only `to`', () {
      final r = CameraApi.filterByDateRange(files, null, DateTime(2024, 1, 31));
      expect(r.map((f) => f.filename), ['a.jpg', 'b.jpg']);
    });

    test('filterByDateRange with null both returns all', () {
      final r = CameraApi.filterByDateRange(files, null, null);
      expect(r.length, files.length);
    });

    test('getUniqueDates is sorted newest first and deduped', () {
      final r = CameraApi.getUniqueDates(files);
      expect(r, ['2024-03-20', '2024-02-05', '2024-01-10']);
    });
  });

  group('CameraFile URL helpers', () {
    test('thumbnailUrl / resizeImgUrl / downloadUrl', () {
      final f = _file(dir: '/DCIM/100OLYMP', name: 'P1.JPG');
      expect(f.fullPath, '/DCIM/100OLYMP/P1.JPG');
      expect(f.thumbnailUrl, contains('/get_thumbnail.cgi?DIR=/DCIM/100OLYMP/P1.JPG'));
      expect(f.resizeImgUrl(1920),
          contains('/get_resizeimg.cgi?DIR=/DCIM/100OLYMP/P1.JPG&size=1920'));
      expect(f.downloadUrl, endsWith('/DCIM/100OLYMP/P1.JPG'));
    });
  });
}
