import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/direct_stream_service.dart';

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

    test('deriveFileName prioritizes custom title and sanitizes illegal characters', () {
      final name = service.deriveFileName(
        'https://cdn.example.com/v1234.mp4',
        'My Cool Movie: Episode 1 / 4',
      );
      expect(name, equals('My Cool Movie_ Episode 1 _ 4.mp4'));
    });

    test('deriveFileName defaults to mp4 extension if URL lacks known media extension', () {
      final name = service.deriveFileName(
        'https://stream.server.org/live/channel',
        'Live Broadcast',
      );
      expect(name, equals('Live Broadcast.mp4'));
    });

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
}
