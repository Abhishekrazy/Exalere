import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';

/// Searches on these sites answer loosely, and a picker that walks the first hit
/// plays a different video. The scorer alone cannot stop that: agreeing on media
/// type is worth 150 points, which clears a threshold of 100 on its own.
void main() {
  MediaItem item(String title, {String? year, bool series = false}) =>
      MediaItem(
        id: title.toLowerCase().replaceAll(' ', '-'),
        title: title,
        year: year,
        mediaType: series ? MediaType.series : MediaType.movie,
      );

  group('title evidence', () {
    test('a same-kind but unrelated hit is not evidence', () {
      // The shape of the user's complaint: the search returns a more popular
      // series, the kind agrees, and the old rule walked it.
      expect(
        MediaItem.sharesTitleWords(
          item('Teen Tigada (Season 1) 2026 [Hindi] Series', series: true),
          'Breaking Bad',
        ),
        isFalse,
      );
      expect(
        MediaItem.sharesTitleWords(item('A Christmas Carol'), 'Dune'),
        isFalse,
      );
      expect(
        MediaItem.sharesTitleWords(
          item("Netflix Kapil Sharma - I'm Not Done Yet (2022)"),
          'Dune',
        ),
        isFalse,
      );
    });

    test('a sequel shares words — the year decides', () {
      final candidates = [
        item('Dune Part Two', year: '2024'),
        item('Dune', year: '2021'),
      ];
      expect(MediaItem.sharesTitleWords(candidates.first, 'Dune'), isTrue);
      final best = MediaItem.findBestMatch(
        candidates: candidates,
        title: 'Dune',
        year: '2021',
        isSeries: false,
        requireTitleMatch: true,
      );
      expect(best?.year, '2021', reason: 'the sequel must not win');
    });

    test('a film in the same franchise is not the series', () {
      // "El Camino: A Breaking Bad Movie" shares words with "Breaking Bad", so
      // only the media-type rule separates them.
      final candidates = [
        item('El Camino: A Breaking Bad Movie', year: '2019'),
        item('Breaking Bad (Season 1)', year: '2008', series: true),
      ];
      final best = MediaItem.findBestMatch(
        candidates: candidates,
        title: 'Breaking Bad',
        year: '2008',
        isSeries: true,
        requireTitleMatch: true,
      );
      expect(best?.mediaType, MediaType.series);
    });

    test('nothing close means no match, not the first hit', () {
      final best = MediaItem.findBestMatch(
        candidates: [
          item('The Blue Road (Season 1) 2026', series: true),
          item('Teen Tigada (Season 1)', series: true),
        ],
        title: 'Breaking Bad',
        year: '2008',
        isSeries: true,
        requireTitleMatch: true,
      );
      expect(best, isNull);
    });

    test('a release-tagged site title still matches', () {
      final best = MediaItem.findBestMatch(
        candidates: [
          item('dune part two 2024 , zeefliz'),
          item('dune 2021 , zeefliz'),
        ],
        title: 'Dune',
        year: '2021',
        isSeries: false,
        requireTitleMatch: true,
      );
      expect(best?.title, contains('2021'));
    });
  });
}
