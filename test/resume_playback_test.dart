import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Resume Playback & LibraryProvider Tests', () {
    test('getResumePosition returns 0 when item not in history', () async {
      final provider = LibraryProvider();
      await provider.init();

      expect(provider.getResumePosition('non-existent-id'), equals(0));
    });

    test(
      'getResumePosition returns saved position for mid-movie watch',
      () async {
        final provider = LibraryProvider();
        await provider.init();

        final movie = MediaItem(
          id: 'movie-101',
          title: 'Test Movie',
          mediaType: MediaType.movie,
        );

        // Watched 25 minutes (1500s) of a 2 hour movie (7200s)
        await provider.recordProgress(
          item: movie,
          positionSeconds: 1500,
          totalSeconds: 7200,
        );

        expect(provider.getResumePosition('movie-101'), equals(1500));
      },
    );

    test(
      'getResumePosition returns 0 when movie is finished or near end',
      () async {
        final provider = LibraryProvider();
        await provider.init();

        final movie = MediaItem(
          id: 'movie-102',
          title: 'Finished Movie',
          mediaType: MediaType.movie,
        );

        // Watched 7190s of 7200s (within 15s of end)
        await provider.recordProgress(
          item: movie,
          positionSeconds: 7190,
          totalSeconds: 7200,
        );

        expect(provider.getResumePosition('movie-102'), equals(0));
      },
    );

    test('getResumePosition correctly filters by season and episode for series', () async {
      final provider = LibraryProvider();
      await provider.init();

      final series = MediaItem(
        id: 'series-201',
        title: 'Test Series',
        mediaType: MediaType.series,
      );

      // Watched S1:E1 at 500s
      await provider.recordProgress(
        item: series,
        positionSeconds: 500,
        totalSeconds: 2400,
        season: 1,
        episode: 1,
      );

      // Watched S1:E2 at 1200s
      await provider.recordProgress(
        item: series,
        positionSeconds: 1200,
        totalSeconds: 2400,
        season: 1,
        episode: 2,
      );

      expect(
        provider.getResumePosition('series-201', season: 1, episode: 1),
        equals(500),
      );
      expect(
        provider.getResumePosition('series-201', season: 1, episode: 2),
        equals(1200),
      );
      // Unwatched S1:E3 should return 0
      expect(
        provider.getResumePosition('series-201', season: 1, episode: 3),
        equals(0),
      );
      // Generic query without season/episode should return most recent (S1:E2)
      expect(provider.getResumePosition('series-201'), equals(1200));
    });

    test(
      'continueWatching deduplicates series to only the latest played episode',
      () async {
        final provider = LibraryProvider();
        await provider.init();

        final series = MediaItem(
          id: 'series-anime-1',
          title: '3 Seconds Later',
          mediaType: MediaType.series,
        );

        // Played Episode 2, then Episode 3, then Episode 4
        await provider.recordProgress(
          item: series,
          positionSeconds: 200,
          totalSeconds: 1200,
          season: 1,
          episode: 2,
        );
        await provider.recordProgress(
          item: series,
          positionSeconds: 300,
          totalSeconds: 1200,
          season: 1,
          episode: 3,
        );
        await provider.recordProgress(
          item: series,
          positionSeconds: 400,
          totalSeconds: 1200,
          season: 1,
          episode: 4,
        );

        // Verify that continueWatching has EXACTLY 1 item for this series, which is Episode 4
        final cw = provider.continueWatching;
        expect(cw.length, equals(1));
        expect(cw.first.item.id, equals('series-anime-1'));
        expect(cw.first.episode, equals(4));
      },
    );

    test('marking episode as watched removes it from continueWatching', () async {
      final provider = LibraryProvider();
      await provider.init();

      final series = MediaItem(
        id: 'series-anime-2',
        title: 'Anime Series',
        mediaType: MediaType.series,
      );

      await provider.recordProgress(
        item: series,
        positionSeconds: 300,
        totalSeconds: 1200,
        season: 1,
        episode: 5,
      );

      expect(provider.continueWatching.length, equals(1));
      expect(provider.isEpisodeWatched('series-anime-2', 1, 5), isFalse);

      // User marks episode 5 as watched
      await provider.markAsWatched(
        'series-anime-2',
        season: 1,
        episode: 5,
        isWatched: true,
        item: series,
      );

      expect(provider.isEpisodeWatched('series-anime-2', 1, 5), isTrue);
      // It must be removed from continueWatching now
      expect(provider.continueWatching.isEmpty, isTrue);

      // User unmarks episode 5
      await provider.toggleEpisodeWatched(
        series: series,
        season: 1,
        episode: 5,
      );
      expect(provider.isEpisodeWatched('series-anime-2', 1, 5), isFalse);
      // Since it's unwatched and has progress, it reappears in continueWatching
      expect(provider.continueWatching.length, equals(1));
    });
  });
}
