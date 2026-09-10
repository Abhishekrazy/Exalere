import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/window_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Player Features & SkipInterval Tests', () {
    test('SkipInterval accurately tests containment within time window', () {
      const interval = SkipInterval(
        type: SkipType.intro,
        startSeconds: 15,
        endSeconds: 85,
        label: 'Skip Intro',
      );

      expect(interval.contains(10), isFalse);
      expect(interval.contains(15), isTrue);
      expect(interval.contains(50), isTrue);
      expect(interval.contains(84), isTrue);
      expect(interval.contains(85), isFalse);
      expect(interval.contains(100), isFalse);
    });

    test('Episode parses skip markers from raw json', () {
      final epJson = {
        'season': 1,
        'episode': 3,
        'title': 'The Variant',
        'introStart': 10,
        'introEnd': 90,
        'outroStart': 2400,
        'outroEnd': 2520,
      };

      final ep = Episode.fromJson(epJson);
      expect(ep.season, equals(1));
      expect(ep.episode, equals(3));
      expect(ep.skipIntervals.length, equals(2));
      expect(ep.skipIntervals[0].type, equals(SkipType.intro));
      expect(ep.skipIntervals[0].startSeconds, equals(10));
      expect(ep.skipIntervals[0].endSeconds, equals(90));
      expect(ep.skipIntervals[1].type, equals(SkipType.outro));
      expect(ep.skipIntervals[1].startSeconds, equals(2400));
    });

    test('MediaDetails parses dubs correctly from MovieBox JSON', () {
      final json = {
        'subjectId': '12345',
        'title': 'Test Movie',
        'subjectType': 1,
        'dubs': [
          {'subjectId': '101', 'lanName': 'English', 'title': 'Original Audio'},
          {'subjectId': '102', 'lanName': 'Hindi', 'title': 'Hindi Dub'},
          {'subjectId': '103', 'lanName': 'Spanish', 'title': 'esla Dub'},
        ],
      };

      final details = MediaDetails.fromMovieBoxJson(json);
      expect(details.dubs.length, equals(3));
      expect(details.dubs[0].subjectId, equals('101'));
      expect(details.dubs[0].language, equals('English'));
      expect(details.dubs[0].label, equals('Original Audio'));
      expect(details.dubs[1].language, equals('Hindi'));
    });

    test('StorageService persists autoSkip and smartSkip preferences', () async {
      final storage = StorageService();

      expect(await storage.getAutoSkipIntro(), isFalse);
      expect(await storage.getAutoSkipOutro(), isFalse);
      expect(await storage.getEnableSmartSkip(), isTrue);

      await storage.setAutoSkipIntro(true);
      await storage.setAutoSkipOutro(true);
      await storage.setEnableSmartSkip(false);

      expect(await storage.getAutoSkipIntro(), isTrue);
      expect(await storage.getAutoSkipOutro(), isTrue);
      expect(await storage.getEnableSmartSkip(), isFalse);
    });

    test('Multi-source fallback sequence correctly navigates available sources', () {
      final s1 = StreamSource(quality: '1080p DASH', resolution: '1080', format: 'DASH', url: 'https://cdn1/dash.mpd', headers: {});
      final s2 = StreamSource(quality: '1080p MP4', resolution: '1080', format: 'MP4', url: 'https://cdn2/direct.mp4', headers: {});
      final s3 = StreamSource(quality: '720p MP4', resolution: '720', format: 'MP4', url: 'https://cdn3/backup.mp4', headers: {});

      final sources = [s1, s2, s3];
      int currentIndex = 0;

      // First failure -> advance
      expect(currentIndex + 1 < sources.length, isTrue);
      currentIndex++;
      expect(sources[currentIndex].quality, equals('1080p MP4'));

      // Second failure -> advance to backup
      expect(currentIndex + 1 < sources.length, isTrue);
      currentIndex++;
      expect(sources[currentIndex].quality, equals('720p MP4'));

      // Exhausted
      expect(currentIndex + 1 < sources.length, isFalse);
    });

    test('StorageService persists autoPlayTrailers preference', () async {
      final storage = StorageService();

      expect(await storage.getAutoPlayTrailers(), isTrue); // default is true
      await storage.setAutoPlayTrailers(false);
      expect(await storage.getAutoPlayTrailers(), isFalse);
      await storage.setAutoPlayTrailers(true);
      expect(await storage.getAutoPlayTrailers(), isTrue);
    });

    test('Episode parses relative duration intro correctly when introEnd is relative', () {
      final epJson = {
        'season': 1,
        'episode': 1,
        'title': 'Pilot',
        'introStart': 15,
        'introEnd': 75, // Treated as 75 absolute since 75 > 15
      };
      final ep = Episode.fromJson(epJson);
      expect(ep.skipIntervals[0].startSeconds, equals(15));
      expect(ep.skipIntervals[0].endSeconds, equals(75));

      final epJsonRelative = {
        'season': 1,
        'episode': 2,
        'title': 'Second',
        'introStart': 100,
        'introEnd': 40, // Since 40 < 100, it is treated as duration -> 100 + 40 = 140
      };
      final ep2 = Episode.fromJson(epJsonRelative);
      expect(ep2.skipIntervals[0].startSeconds, equals(100));
      expect(ep2.skipIntervals[0].endSeconds, equals(140));
    });

    test('WindowService singleton operates without exceptions', () {
      final ws1 = WindowService();
      final ws2 = WindowService();
      expect(identical(ws1, ws2), isTrue);
      expect(ws1.isFullscreen, isFalse);
    });

    test('Episode and Season copyWith supports TMDB thumbnail enrichment', () {
      const originalEp = Episode(
        season: 1,
        episode: 1,
        title: 'Episode 1',
      );
      expect(originalEp.thumbnail, isNull);

      final enrichedEp = originalEp.copyWith(
        title: 'Chapter One: The Vanishing of Will Byers',
        thumbnail: 'https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
        overview: 'Will disappears on his way home.',
      );
      expect(enrichedEp.thumbnail, equals('https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg'));
      expect(enrichedEp.title, equals('Chapter One: The Vanishing of Will Byers'));
      expect(enrichedEp.overview, equals('Will disappears on his way home.'));

      const season = Season(seasonNumber: 1, episodeCount: 1, episodes: [originalEp]);
      final updatedSeason = season.copyWith(episodes: [enrichedEp]);
      expect(updatedSeason.episodes.first.thumbnail, isNotNull);
    });

    test('Episode does not generate fake intro when introEnd and duration are missing', () {
      final epJsonNoEnd = {
        'season': 1,
        'episode': 5,
        'title': 'No End Episode',
        'introStart': 10,
        // introEnd and openingDuration are null
      };
      final ep = Episode.fromJson(epJsonNoEnd);
      expect(ep.skipIntervals.where((s) => s.type == SkipType.intro).isEmpty, isTrue);
    });

    test('StreamSource formats server details without overflowing', () {
      final source1 = StreamSource(
        quality: 'Multi-Res (Auto)',
        resolution: '1080,720,480',
        format: 'DASH',
        url: 'https://cdn.example.com/manifest.mpd',
        sizeBytes: 5153960755, // ~4.8 GB
        codec: 'hevc',
      );

      final source2 = StreamSource(
        quality: '1080p',
        resolution: '1080',
        format: 'MP4',
        url: 'https://cdn.example.com/stream.mp4',
        sizeBytes: 3435973836, // ~3.2 GB
      );

      expect(source1.formattedSize, '4.8 GB');
      expect(source2.formattedSize, '3.2 GB');

      final details1 = [
        if (source1.formattedSize.isNotEmpty) source1.formattedSize,
        if (source1.codec != null && source1.codec!.isNotEmpty) source1.codec!,
      ].join(' • ');

      expect(details1, '4.8 GB • hevc');
    });
  });
}
