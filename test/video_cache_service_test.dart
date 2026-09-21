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

    test('Constants match 500MB specification and resilient readahead', () {
      expect(VideoCacheService.kMaxCacheSizeBytes, equals(500 * 1024 * 1024));
      expect(
        VideoCacheService.kMaxBackCacheSizeBytes,
        equals(50 * 1024 * 1024),
      );
      expect(VideoCacheService.kReadaheadSeconds, equals(300));
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

    test('getMpvCacheProperties supplies valid disk-backed 500MB options', () {
      final props = service.getMpvCacheProperties();

      expect(props['cache'], equals('yes'));
      expect(props['cache-on-disk'], equals('yes'));
      expect(props['demuxer-cache-dir'], equals(service.cacheDirectoryPath));
      expect(props['demuxer-max-bytes'], equals('${500 * 1024 * 1024}'));
      expect(props['demuxer-max-back-bytes'], equals('${50 * 1024 * 1024}'));
      expect(props['demuxer-readahead-secs'], equals('300'));
      expect(props['cache-secs'], equals('300'));
      expect(props['cache-pause'], equals('no'));

      // Check ffmpeg network reconnect options
      final lavfOpts = props['demuxer-lavf-o'];
      expect(lavfOpts, isNotNull);
      expect(lavfOpts, contains('reconnect=1'));
      expect(lavfOpts, contains('reconnect_streamed=1'));
      expect(lavfOpts, contains('reconnect_delay_max=5'));
      expect(lavfOpts, contains('seg_max_retry=5'));
    });
  });
}
