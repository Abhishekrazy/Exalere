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

    test('getResumePosition returns saved position for mid-movie watch', () async {
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
    });

    test('getResumePosition returns 0 when movie is finished or near end', () async {
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
    });

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

      expect(provider.getResumePosition('series-201', season: 1, episode: 1), equals(500));
      expect(provider.getResumePosition('series-201', season: 1, episode: 2), equals(1200));
      // Unwatched S1:E3 should return 0
      expect(provider.getResumePosition('series-201', season: 1, episode: 3), equals(0));
      // Generic query without season/episode should return most recent (S1:E2)
      expect(provider.getResumePosition('series-201'), equals(1200));
    });
  });
}
