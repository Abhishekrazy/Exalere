import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/video_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoCacheService Tests', () {
    final service = VideoCacheService.instance;

    setUp(() async {
      service.resetActiveMediaKey();
      await service.clearCache(retryOnLocked: false);
    });

    tearDown(() async {
      await service.clearCache(retryOnLocked: false);
      service.resetActiveMediaKey();
    });

    test('Constants match 128MB specification and resilient readahead', () {
      expect(VideoCacheService.kMaxCacheSizeBytes, equals(128 * 1024 * 1024));
      expect(
        VideoCacheService.kMaxBackCacheSizeBytes,
        equals(32 * 1024 * 1024),
      );
      expect(VideoCacheService.kReadaheadSeconds, equals(180));
      expect(
        VideoCacheService.kMaxLiveCacheSizeBytes,
        equals(16 * 1024 * 1024),
      );
      expect(VideoCacheService.kLiveReadaheadSeconds, equals(60));
    });

    test('ensureCacheDirectory creates and returns valid directory', () async {
      final dir = await service.ensureCacheDirectory();
      expect(await dir.exists(), isTrue);
      expect(dir.path, contains('exalere_video_cache'));
    });

    test(
      'shouldClearForNewVideo properly tracks and detects media changes',
      () {
        // First video played: should clear/prepare cache
        expect(service.shouldClearForNewVideo('movie_101'), isTrue);
        expect(service.lastPlayedMediaKey, equals('movie_101'));

        // Same video re-opened or resumed: should not clear
        expect(service.shouldClearForNewVideo('movie_101'), isFalse);

        // Different video played: should clear
        expect(service.shouldClearForNewVideo('movie_202'), isTrue);
        expect(service.lastPlayedMediaKey, equals('movie_202'));

        // Episode change in series: should clear
        expect(service.shouldClearForNewVideo('show_5_s1_e2'), isTrue);
        expect(service.lastPlayedMediaKey, equals('show_5_s1_e2'));
        expect(service.shouldClearForNewVideo('show_5_s1_e2'), isFalse);
      },
    );

    test(
      'setActiveMediaKey and resetActiveMediaKey manipulate state directly',
      () {
        service.setActiveMediaKey('manual_key');
        expect(service.lastPlayedMediaKey, equals('manual_key'));

        service.resetActiveMediaKey();
        expect(service.lastPlayedMediaKey, isNull);
      },
    );

    test('clearCache deletes created cache files and subdirectories', () async {
      final dir = await service.ensureCacheDirectory();
      final testFile = File(
        '${dir.path}${Platform.pathSeparator}stream_chunk.tmp',
      );
      await testFile.writeAsBytes(List.filled(1024 * 100, 42)); // 100 KB
      expect(await testFile.exists(), isTrue);

      final subDir = Directory('${dir.path}${Platform.pathSeparator}sub');
      await subDir.create();
      final subFile = File(
        '${subDir.path}${Platform.pathSeparator}sub_chunk.tmp',
      );
      await subFile.writeAsBytes(List.filled(1024 * 50, 24)); // 50 KB

      final sizeBefore = await service.getCacheSizeBytes();
      expect(sizeBefore, equals(150 * 1024));

      await service.clearCache(retryOnLocked: false);

      final sizeAfter = await service.getCacheSizeBytes();
      expect(sizeAfter, equals(0));
      expect(await testFile.exists(), isFalse);
      expect(await subFile.exists(), isFalse);
    });

    test('getMpvCacheProperties supplies valid RAM-backed 128MB options', () {
      final props = service.getMpvCacheProperties();

      expect(props['cache'], equals('yes'));
      expect(props['cache-on-disk'], equals('no'));
      expect(props['demuxer-max-bytes'], equals('${128 * 1024 * 1024}'));
      expect(props['demuxer-max-back-bytes'], equals('${32 * 1024 * 1024}'));
      expect(props['demuxer-readahead-secs'], equals('180'));
      expect(props['cache-secs'], equals('180'));
      expect(props['cache-pause'], equals('yes'));
      expect(props['cache-pause-initial'], equals('yes'));
      expect(props['cache-pause-wait'], equals('10'));
      expect(props['hr-seek'], equals('default'));

      // Check ffmpeg network reconnect options
      final streamLavfOpts = props['stream-lavf-o'];
      expect(streamLavfOpts, isNotNull);
      expect(streamLavfOpts, contains('reconnect=1'));
      expect(streamLavfOpts, contains('reconnect_streamed=1'));
      expect(streamLavfOpts, contains('multiple_requests=1'));

      final lavfOpts = props['demuxer-lavf-o'];
      expect(lavfOpts, isNotNull);
      expect(lavfOpts, contains('reconnect=1'));
      expect(lavfOpts, contains('reconnect_streamed=1'));
      expect(lavfOpts, contains('reconnect_delay_max=5'));
      expect(lavfOpts, contains('seg_max_retry=5'));
      expect(lavfOpts, contains('multiple_requests=1'));
    });

    test('getMpvCacheProperties for Live TV restricts to 16MB/1-min RAM buffer and no rewind', () {
      final props = service.getMpvCacheProperties(isLive: true);

      expect(props['cache'], equals('yes'));
      expect(props['cache-on-disk'], equals('no'));
      expect(props['demuxer-max-bytes'], equals('${16 * 1024 * 1024}'));
      expect(props['demuxer-max-back-bytes'], equals('0'));
      expect(props['demuxer-readahead-secs'], equals('60'));
      expect(props['cache-secs'], equals('60'));
      expect(props['cache-pause'], equals('yes'));
      expect(props['cache-pause-initial'], equals('yes'));
      expect(props['cache-pause-wait'], equals('3'));
      expect(props['force-seekable'], equals('no'));
      expect(props['hr-seek'], equals('no'));

      final lavfOpts = props['demuxer-lavf-o'];
      expect(lavfOpts, isNotNull);
      expect(lavfOpts, contains('reconnect=1'));
      expect(lavfOpts, contains('seg_max_retry=5'));
    });

    test(
      'Adaptive caching returns 32MB budget for 32-bit / ARMv7 platforms',
      () {
        service.set32BitOverride(true);
        expect(service.is32BitOrLowRam, isTrue);
        expect(service.maxCacheSizeBytes, equals(32 * 1024 * 1024));
        expect(service.maxBackCacheSizeBytes, equals(8 * 1024 * 1024));
        expect(service.readaheadSeconds, equals(60));

        final props = service.getMpvCacheProperties();
        expect(props['demuxer-max-bytes'], equals('${32 * 1024 * 1024}'));
        expect(props['demuxer-max-back-bytes'], equals('${8 * 1024 * 1024}'));
        expect(props['demuxer-readahead-secs'], equals('60'));
        expect(props['demuxer-lavf-o'], contains('multiple_requests=1'));

        service.set32BitOverride(false);
        expect(service.maxCacheSizeBytes, equals(128 * 1024 * 1024));
        expect(service.maxBackCacheSizeBytes, equals(32 * 1024 * 1024));
        expect(service.readaheadSeconds, equals(180));
        service.set32BitOverride(null);
      },
    );
  });
}
