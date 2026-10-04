import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/direct_stream_service.dart';
import 'package:exalere/ui/widgets/download_server_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DirectStreamService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = DirectStreamService.instance;
  });

  group('DirectStreamService - File Name & Format Detection', () {
    test('deriveFileName extracts clean filename from standard media URL', () {
      final name = service.deriveFileName(
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        null,
      );
      expect(name, equals('BigBuckBunny.mp4'));
    });

    test(
      'deriveFileName strips URL query parameters when extracting filename',
      () {
        final name = service.deriveFileName(
          'https://cdn.example.com/streams/ocean_clip.mkv?token=xyz123&expires=999999',
          null,
        );
        expect(name, equals('ocean_clip.mkv'));
      },
    );

    test(
      'deriveFileName prioritizes custom title and sanitizes illegal characters',
      () {
        final name = service.deriveFileName(
          'https://cdn.example.com/v1234.mp4',
          'My Cool Movie: Episode 1 / 4',
        );
        expect(name, equals('My Cool Movie_ Episode 1 _ 4.mp4'));
      },
    );

    test(
      'deriveFileName defaults to mp4 extension if URL lacks known media extension',
      () {
        final name = service.deriveFileName(
          'https://stream.server.org/live/channel',
          'Live Broadcast',
        );
        expect(name, equals('Live Broadcast.mp4'));
      },
    );

    test('createStreamSource detects HLS format for .m3u8 URLs', () {
      final source = service.createStreamSource(
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      );
      expect(source.format, equals('HLS'));
      expect(
        source.url,
        equals('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
      );
    });

    test('createStreamSource detects DASH format for .mpd URLs', () {
      final source = service.createStreamSource(
        'https://dash.akamaized.net/envivio/EnvivioDash3/manifest.mpd',
      );
      expect(source.format, equals('DASH'));
    });

    test(
      'createStreamSource defaults to MP4 format for progressive streams',
      () {
        final source = service.createStreamSource(
          'https://example.com/movie.mp4',
        );
        expect(source.format, equals('MP4'));
      },
    );

    test('createMediaItem generates valid MediaItem metadata', () {
      final item = service.createMediaItem(
        'https://example.com/documentary.mp4',
        'Nature Life',
      );
      expect(item.id, startsWith('direct_'));
      expect(item.title, equals('Nature Life'));
      expect(item.isSeries, isFalse);
      expect(item.genre, equals('Direct Stream'));
    });
  });

  group('DirectStreamService - Recent URLs Management', () {
    test(
      'recordRecentUrl persists and retrieves entries in LIFO order',
      () async {
        await service.recordRecentUrl(
          url: 'https://example.com/video1.mp4',
          title: 'Video One',
        );
        await service.recordRecentUrl(
          url: 'https://example.com/video2.mp4',
          title: 'Video Two',
        );

        final history = await service.getRecentUrls();
        expect(history.length, equals(2));
        expect(history.first.url, equals('https://example.com/video2.mp4'));
        expect(history.first.title, equals('Video Two'));
        expect(history.last.url, equals('https://example.com/video1.mp4'));
      },
    );

    test(
      'recordRecentUrl deduplicates identical URLs by moving to top',
      () async {
        await service.recordRecentUrl(
          url: 'https://example.com/alpha.mp4',
          title: 'Alpha',
        );
        await service.recordRecentUrl(
          url: 'https://example.com/beta.mp4',
          title: 'Beta',
        );
        await service.recordRecentUrl(
          url: 'https://example.com/alpha.mp4',
          title: 'Alpha Renamed',
        );

        final history = await service.getRecentUrls();
        expect(history.length, equals(2));
        expect(history.first.url, equals('https://example.com/alpha.mp4'));
        expect(history.first.title, equals('Alpha Renamed'));
      },
    );

    test('removeRecentUrl removes targeted entry', () async {
      await service.recordRecentUrl(
        url: 'https://example.com/keep.mp4',
        title: 'Keep',
      );
      await service.recordRecentUrl(
        url: 'https://example.com/delete.mp4',
        title: 'Delete',
      );

      await service.removeRecentUrl('https://example.com/delete.mp4');

      final history = await service.getRecentUrls();
      expect(history.length, equals(1));
      expect(history.first.url, equals('https://example.com/keep.mp4'));
    });

    test('clearRecentUrls purges all entries', () async {
      await service.recordRecentUrl(
        url: 'https://example.com/1.mp4',
        title: '1',
      );
      await service.recordRecentUrl(
        url: 'https://example.com/2.mp4',
        title: '2',
      );

      await service.clearRecentUrls();

      final history = await service.getRecentUrls();
      expect(history, isEmpty);
    });
  });

  group('VideoDownloadTask - Formatting & Calculations', () {
    test('formattedProgress formats percentage correctly', () {
      final task = VideoDownloadTask(
        id: '1',
        url: 'https://example.com/vid.mp4',
        title: 'Vid',
        fileName: 'vid.mp4',
        filePath: '/tmp/vid.mp4',
        progress: 0.754,
        startedAt: DateTime.now(),
      );
      expect(task.formattedProgress, equals('75.4%'));
    });

    test('formattedSpeed formats KB/s and MB/s appropriately', () {
      final taskKb = VideoDownloadTask(
        id: '1',
        url: 'https://example.com/vid.mp4',
        title: 'Vid',
        fileName: 'vid.mp4',
        filePath: '/tmp/vid.mp4',
        speedBytesPerSec: 512 * 1024,
        startedAt: DateTime.now(),
      );
      expect(taskKb.formattedSpeed, equals('512 KB/s'));

      final taskMb = taskKb.copyWith(speedBytesPerSec: 2.5 * 1024 * 1024);
      expect(taskMb.formattedSpeed, equals('2.5 MB/s'));
    });

    test('formattedSize formats KB, MB, and GB appropriately', () {
      final taskMb = VideoDownloadTask(
        id: '1',
        url: 'https://example.com/vid.mp4',
        title: 'Vid',
        fileName: 'vid.mp4',
        filePath: '/tmp/vid.mp4',
        totalBytes: 150 * 1024 * 1024,
        startedAt: DateTime.now(),
      );
      expect(taskMb.formattedSize, equals('150.0 MB'));

      final taskGb = taskMb.copyWith(totalBytes: 2 * 1024 * 1024 * 1024);
      expect(taskGb.formattedSize, equals('2.00 GB'));
    });
  });

  group('DirectStreamService - Queue & Batch Operations', () {
    test('enqueueSeason creates sequential queued tasks', () async {
      const media = MediaItem(
        id: 'series_123',
        title: 'Test Show',
        mediaType: MediaType.series,
        posterUrl: '',
      );

      final episodes = [
        const Episode(season: 1, episode: 1, title: 'Pilot'),
        const Episode(season: 1, episode: 2, title: 'The Next Step'),
      ];

      final tasks = await service.enqueueSeason(
        mediaItem: media,
        seasonNumber: 1,
        episodes: episodes,
      );

      expect(tasks.length, equals(2));
      expect(tasks[0].title, contains('S1E1: Pilot'));
      expect(tasks[1].title, contains('S1E2: The Next Step'));
      expect(tasks[0].season, equals(1));
      expect(tasks[0].episode, equals(1));
      expect(tasks[1].episode, equals(2));

      // Clean up test tasks
      for (final t in tasks) {
        service.removeTask(t.id);
      }
    });

    test(
      'pauseDownload, resumeDownload, and removeTask work properly',
      () async {
        final task = await service.enqueueDownload(
          url: 'https://example.com/queued_video.mp4',
          title: 'Queued Video',
        );

        expect(
          service.inProgressAndQueuedTasks.any((t) => t.id == task.id),
          isTrue,
        );

        service.pauseDownload(task.id);
        final paused = service.tasks.firstWhere((t) => t.id == task.id);
        expect(paused.status, equals(DownloadTaskStatus.paused));

        service.resumeDownload(task.id);
        final resumed = service.tasks.firstWhere((t) => t.id == task.id);
        expect(resumed.status, equals(DownloadTaskStatus.queued));

        service.removeTask(task.id);
        expect(service.tasks.any((t) => t.id == task.id), isFalse);
      },
    );
  });

  group('isStreamDownloadable Validation', () {
    test('accepts progressive MP4 streams for download', () {
      final source = StreamSource(
        quality: '1080p',
        resolution: '1080p',
        url: 'https://cdn.example.com/video/stream.mp4',
        format: 'MP4',
      );
      expect(isStreamDownloadable(source), isTrue);
    });

    test('accepts MovieBox Direct progressive streams for download', () {
      final source = StreamSource(
        quality: '1080p Direct',
        resolution: '1080p',
        format: 'MP4',
        url: 'https://sportslive.wine/resource/media/file_1080.mp4',
        headers: {
          'User-Agent': 'MovieBox/1.0',
          'Referer': 'https://sportslive.wine',
          'Cookie': 'CloudFront-Key-Pair-Id=K123',
        },
        server: 'MovieBox Direct',
        providerId: 'moviebox',
        providerName: 'MovieBox',
      );
      expect(isStreamDownloadable(source), isTrue);
    });

    test('accepts DASH manifests (.mpd and DASH format)', () {
      final dashByFormat = StreamSource(
        quality: 'Auto',
        resolution: '1080p',
        url: 'https://cdn.example.com/dash/stream',
        format: 'DASH',
      );
      final dashByUrl = StreamSource(
        quality: 'Auto',
        resolution: '1080p',
        url: 'https://cdn.example.com/video/index.mpd',
        format: 'DASH',
      );
      expect(isStreamDownloadable(dashByFormat), isTrue);
      expect(isStreamDownloadable(dashByUrl), isTrue);
    });

    test('accepts HLS playlists (.m3u8 and HLS format)', () {
      final hlsByFormat = StreamSource(
        quality: '1080p',
        resolution: '1080p',
        url: 'https://cdn.example.com/live/playlist',
        format: 'HLS',
      );
      final hlsByUrl = StreamSource(
        quality: '1080p',
        resolution: '1080p',
        url: 'https://cdn.example.com/live/master.m3u8',
        format: 'HLS',
      );
      expect(isStreamDownloadable(hlsByFormat), isTrue);
      expect(isStreamDownloadable(hlsByUrl), isTrue);
    });

    test('rejects web embeds and torrent magnets', () {
      final embedSource = StreamSource(
        quality: 'Auto',
        resolution: 'Auto',
        url: 'https://vidsrc.me/embed/movie?imdb=tt1234567',
        format: 'WEB EMBED',
      );
      final magnetSource = StreamSource(
        quality: '1080p',
        resolution: '1080p',
        url: 'magnet:?xt=urn:btih:d1234567890abcdef',
        format: 'TORRENT',
      );
      expect(isStreamDownloadable(embedSource), isFalse);
      expect(isStreamDownloadable(magnetSource), isFalse);
    });
  });
}
