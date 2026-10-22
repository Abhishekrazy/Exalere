import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/image_urls.dart';

/// Poster URLs come from providers and cached JSON at whatever size they stored,
/// so the upgrade has to be safe to call on anything.
void main() {
  const tmdb = 'https://image.tmdb.org/t/p';

  group('ImageUrls.upgrade', () {
    test('raises a small TMDB poster to the display width', () {
      expect(
        ImageUrls.upgrade('$tmdb/w500/poster.jpg'),
        '$tmdb/w780/poster.jpg',
      );
      expect(
        ImageUrls.upgrade('$tmdb/w342/poster.jpg'),
        '$tmdb/w780/poster.jpg',
      );
      expect(ImageUrls.upgrade('$tmdb/w92/still.jpg'), '$tmdb/w780/still.jpg');
    });

    test('leaves an already large enough size alone', () {
      // Re-downloading a bigger file for no visual gain would be wasteful.
      expect(
        ImageUrls.upgrade('$tmdb/w780/poster.jpg'),
        '$tmdb/w780/poster.jpg',
      );
      expect(
        ImageUrls.upgrade('$tmdb/w1280/backdrop.jpg'),
        '$tmdb/w1280/backdrop.jpg',
      );
    });

    test("never downgrades 'original'", () {
      expect(
        ImageUrls.upgrade('$tmdb/original/poster.jpg'),
        '$tmdb/original/poster.jpg',
      );
    });

    test('honours a custom minimum width', () {
      expect(
        ImageUrls.upgrade('$tmdb/w500/poster.jpg', minWidth: 1280),
        '$tmdb/w1280/poster.jpg',
      );
      // Below the smallest served width, it still picks a served one.
      expect(
        ImageUrls.upgrade('$tmdb/w92/still.jpg', minWidth: 100),
        '$tmdb/w154/still.jpg',
      );
    });

    test('only ever targets a width TMDB actually serves', () {
      for (final requested in [1, 100, 400, 600, 900, 4000]) {
        final upgraded = ImageUrls.upgrade(
          '$tmdb/w92/x.jpg',
          minWidth: requested,
        );
        final width = int.parse(
          RegExp(r'/w(\d+)/').firstMatch(upgraded!)!.group(1)!,
        );
        expect(
          ImageUrls.tmdbWidths.contains(width),
          isTrue,
          reason: 'minWidth $requested produced unserved width $width',
        );
      }
    });

    test('leaves non-TMDB artwork untouched', () {
      const other = 'https://cdn.example.com/poster.png';
      expect(ImageUrls.upgrade(other), other);
      expect(ImageUrls.upgrade('https://i.imgur.com/a.jpg'), isNotNull);
    });

    test('etags and query strings survive the rewrite', () {
      final upgraded = ImageUrls.upgrade('$tmdb/w500/poster.jpg?tag=abc');
      expect(upgraded, '$tmdb/w780/poster.jpg?tag=abc');
    });

    test('returns null for null and empty input', () {
      expect(ImageUrls.upgrade(null), isNull);
      expect(ImageUrls.upgrade(''), isNull);
      expect(ImageUrls.upgrade('   '), isNull);
    });

    test('trims surrounding whitespace', () {
      expect(
        ImageUrls.upgrade('  $tmdb/w500/poster.jpg  '),
        '$tmdb/w780/poster.jpg',
      );
    });

    test('is idempotent', () {
      final once = ImageUrls.upgrade('$tmdb/w500/poster.jpg');
      expect(ImageUrls.upgrade(once), once);
    });
  });

  group('ImageUrls.isTmdb', () {
    test('recognises TMDB artwork only', () {
      expect(ImageUrls.isTmdb('$tmdb/w500/poster.jpg'), isTrue);
      expect(ImageUrls.isTmdb('https://cdn.example.com/poster.png'), isFalse);
      expect(ImageUrls.isTmdb(null), isFalse);
    });
  });
}
