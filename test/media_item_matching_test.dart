import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';

void main() {
  group('MediaItem Title and Year Matching Tests', () {
    test(
      'normalizeTitleForMatching cleans punctuation, audio tags, and years',
      () {
        expect(
          MediaItem.normalizeTitleForMatching(
            'Avatar: The Way of Water (2022) [Hindi Dubbed]',
          ),
          equals('avatar the way of water'),
        );
        expect(
          MediaItem.normalizeTitleForMatching(
            'Deadpool & Wolverine (Dual Audio)',
          ),
          equals('deadpool and wolverine'),
        );
        expect(
          MediaItem.normalizeTitleForMatching(
            'Spider-Man: Across the Spider-Verse',
          ),
          equals('spider man across the spider verse'),
        );
      },
    );

    test(
      'findBestMatch selects exact year match when multiple titles exist',
      () {
        final candidates = [
          MediaItem(
            id: '/avatar-movie-774/',
            title: 'Avatar',
            year: '2009',
            mediaType: MediaType.movie,
          ),
          MediaItem(
            id: '/avatar-the-way-of-water-movie-459/',
            title: 'Avatar: The Way of Water',
            year: '2022',
            mediaType: MediaType.movie,
          ),
        ];

        final match2022 = MediaItem.findBestMatch(
          candidates: candidates,
          title: 'Avatar: The Way of Water',
          year: '2022',
          isSeries: false,
        );
        expect(match2022, isNotNull);
        expect(match2022!.id, equals('/avatar-the-way-of-water-movie-459/'));
        expect(match2022.year, equals('2022'));

        final match2009 = MediaItem.findBestMatch(
          candidates: candidates,
          title: 'Avatar',
          year: '2009',
          isSeries: false,
        );
        expect(match2009, isNotNull);
        expect(match2009!.id, equals('/avatar-movie-774/'));
        expect(match2009.year, equals('2009'));
      },
    );

    test(
      'findBestMatch discriminates franchise sequels with different years',
      () {
        final candidates = [
          MediaItem(
            id: '/dune-1984/',
            title: 'Dune',
            year: '1984',
            mediaType: MediaType.movie,
          ),
          MediaItem(
            id: '/dune-2021/',
            title: 'Dune',
            year: '2021',
            mediaType: MediaType.movie,
          ),
          MediaItem(
            id: '/dune-part-two-2024/',
            title: 'Dune: Part Two',
            year: '2024',
            mediaType: MediaType.movie,
          ),
        ];

        final matchDune2 = MediaItem.findBestMatch(
          candidates: candidates,
          title: 'Dune: Part Two',
          year: '2024',
          isSeries: false,
        );
        expect(matchDune2, isNotNull);
        expect(matchDune2!.id, equals('/dune-part-two-2024/'));
      },
    );

    test('findBestMatch discriminates series vs movies with same name', () {
      final candidates = [
        MediaItem(
          id: '/fallout-movie-2018/',
          title: 'Mission: Impossible - Fallout',
          year: '2018',
          mediaType: MediaType.movie,
        ),
        MediaItem(
          id: '/fallout-series-2024/',
          title: 'Fallout',
          year: '2024',
          mediaType: MediaType.series,
        ),
      ];

      final seriesMatch = MediaItem.findBestMatch(
        candidates: candidates,
        title: 'Fallout',
        year: '2024',
        isSeries: true,
      );
      expect(seriesMatch, isNotNull);
      expect(seriesMatch!.id, equals('/fallout-series-2024/'));
      expect(seriesMatch.isSeries, isTrue);

      final movieMatch = MediaItem.findBestMatch(
        candidates: candidates,
        title: 'Mission: Impossible - Fallout',
        year: '2018',
        isSeries: false,
      );
      expect(movieMatch, isNotNull);
      expect(movieMatch!.id, equals('/fallout-movie-2018/'));
      expect(movieMatch.isSeries, isFalse);
    });

    test('findBestMatch tolerates ±1 year discrepancy for international festival release', () {
      final candidates = [
        MediaItem(
          id: '/film-2023/',
          title: 'Indie Gem',
          year: '2023',
          mediaType: MediaType.movie,
        ),
        MediaItem(
          id: '/film-1990/',
          title: 'Indie Gem',
          year: '1990',
          mediaType: MediaType.movie,
        ),
      ];

      final match = MediaItem.findBestMatch(
        candidates: candidates,
        title: 'Indie Gem',
        year: '2024', // e.g. theatrical release was 2024 while catalog had 2023 festival date
        isSeries: false,
      );
      expect(match, isNotNull);
      expect(match!.id, equals('/film-2023/'));
    });
  });
}
