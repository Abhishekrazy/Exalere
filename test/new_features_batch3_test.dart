import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/app_feature.dart';
import 'package:exalere/services/tmdb_service.dart';
import 'package:exalere/services/video_cache_service.dart';
import 'package:exalere/services/web_remote_service.dart';
import 'package:exalere/ui/screens/player/player_picture_tuner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch 3 - In-Player Video Picture Tuner', () {
    test('Picture presets have correct calibrated values', () {
      expect(PicturePreset.standard.brightness, equals(0));
      expect(PicturePreset.standard.contrast, equals(0));
      expect(PicturePreset.standard.saturation, equals(0));
      expect(PicturePreset.standard.gamma, equals(0));

      expect(PicturePreset.cinema.contrast, equals(6));
      expect(PicturePreset.cinema.saturation, equals(8));

      expect(PicturePreset.vivid.contrast, equals(14));
      expect(PicturePreset.vivid.saturation, equals(18));

      expect(PicturePreset.shadowBoost.brightness, equals(14));
      expect(PicturePreset.shadowBoost.gamma, equals(16));

      expect(PicturePreset.highContrast.brightness, equals(-6));
      expect(PicturePreset.highContrast.contrast, equals(16));
    });

    test('Picture preset labels are distinct and informative', () {
      final labels = PicturePreset.values.map((p) => p.label).toSet();
      expect(labels.length, equals(PicturePreset.values.length));
      expect(labels.contains('Standard'), isTrue);
      expect(labels.contains('Cinema Warm'), isTrue);
      expect(labels.contains('Vivid OLED'), isTrue);
      expect(labels.contains('Shadow Boost'), isTrue);
      expect(labels.contains('High Contrast'), isTrue);
    });
  });

  group('Batch 3 - Web Companion TV Remote Service', () {
    late WebRemoteService remoteService;

    setUp(() {
      remoteService = WebRemoteService();
      remoteService.resetForTesting();
    });

    tearDown(() async {
      await remoteService.stopServer();
    });

    test('Service starts with default initial state', () {
      expect(remoteService.port, equals(WebRemoteService.defaultPort));
      expect(remoteService.commandCount, equals(0));
    });

    test('Dispatches actions and emits to stream', () async {
      final actionsReceived = <WebRemoteAction>[];
      final sub = remoteService.onAction.listen((a) => actionsReceived.add(a));

      remoteService.dispatchAction(WebRemoteAction.up);
      remoteService.dispatchAction(WebRemoteAction.select);
      remoteService.dispatchAction(WebRemoteAction.playPause);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(actionsReceived, [
        WebRemoteAction.up,
        WebRemoteAction.select,
        WebRemoteAction.playPause,
      ]);
      expect(remoteService.commandCount, equals(3));
      await sub.cancel();
    });

    test('Dispatches text input and emits to stream', () async {
      final textsReceived = <String>[];
      final sub = remoteService.onText.listen((t) => textsReceived.add(t));

      remoteService.dispatchText('Inception 2010');
      remoteService.dispatchText('Stranger Things');

      await Future.delayed(const Duration(milliseconds: 50));
      expect(textsReceived, ['Inception 2010', 'Stranger Things']);
      expect(remoteService.commandCount, equals(2));
      await sub.cancel();
    });

    test('Server lifecycle starts and stops cleanly', () async {
      // Use an alternative port for testing to prevent conflicts
      final started = await remoteService.startServer(port: 9876);
      expect(started, isTrue);
      expect(remoteService.isRunning, isTrue);
      expect(remoteService.remoteUrl, contains(':9876'));

      await remoteService.stopServer();
      expect(remoteService.isRunning, isFalse);
    });
  });

  group('Batch 3 - TMDB Reviews & Deep Discovery Models', () {
    test('TmdbReview parses JSON correctly with rating and avatar', () {
      final json = {
        'id': 'rev_12345',
        'author': 'MovieBuff99',
        'content':
            'An absolute masterpiece of cinema with breathtaking visuals.',
        'created_at': '2026-05-15T12:00:00.000Z',
        'url': 'https://www.themoviedb.org/review/rev_12345',
        'author_details': {'rating': 9.0, 'avatar_path': '/kX9aU.jpg'},
      };

      final review = TmdbReview.fromJson(json);
      expect(review.id, equals('rev_12345'));
      expect(review.author, equals('MovieBuff99'));
      expect(review.rating, equals(9.0));
      expect(review.avatarUrl, contains('/kX9aU.jpg'));
      expect(review.content, contains('masterpiece'));
      expect(review.createdAt?.year, equals(2026));

      final serialized = review.toJson();
      expect(serialized['id'], equals('rev_12345'));
      expect(serialized['author'], equals('MovieBuff99'));
      expect(serialized['rating'], equals(9.0));
    });

    test('TmdbReview handles null ratings and fallback avatars', () {
      final json = {
        'id': 'rev_empty',
        'content': 'Short review without rating',
      };

      final review = TmdbReview.fromJson(json);
      expect(review.id, equals('rev_empty'));
      expect(review.author, equals('Reviewer'));
      expect(review.rating, isNull);
      expect(review.avatarUrl, isNull);
      expect(review.createdAt, isNull);
    });
  });

  group('Batch 3 - Storage Hygiene & Video Cache', () {
    test('VideoCacheService reports cache size and clears safely', () async {
      final cacheService = VideoCacheService.instance;
      final size = await cacheService.getCacheSizeBytes();
      expect(size, isNonNegative);

      // Should complete without error
      await cacheService.clearCache();
      final newSize = await cacheService.getCacheSizeBytes();
      expect(newSize, isNonNegative);
    });
  });

  group('Batch 3 - AppFeaturesCatalog Verification', () {
    test('AppFeaturesCatalog contains all new Batch 3 capabilities', () {
      final all = AppFeaturesCatalog.allFeatures;
      final ids = all.map((f) => f.id).toSet();

      expect(ids.contains('video_picture_tuner'), isTrue);
      expect(ids.contains('web_companion_remote'), isTrue);
      expect(ids.contains('deep_discovery_filter'), isTrue);
      expect(ids.contains('reviews_and_ratings_hub'), isTrue);
      expect(ids.contains('quick_switcher_overlay'), isTrue);
      expect(ids.contains('storage_hygiene_cleaner'), isTrue);
    });

    test('Search finds features by title or keyword', () {
      final tunerResults = AppFeaturesCatalog.search('Picture Tuner');
      expect(tunerResults.isNotEmpty, isTrue);
      expect(tunerResults.first.id, equals('video_picture_tuner'));

      final remoteResults = AppFeaturesCatalog.search('Web Companion');
      expect(remoteResults.isNotEmpty, isTrue);
      expect(remoteResults.first.id, equals('web_companion_remote'));

      final discoverResults = AppFeaturesCatalog.search('Discovery');
      expect(discoverResults.isNotEmpty, isTrue);

      final reviewsResults = AppFeaturesCatalog.search('Reviews');
      expect(reviewsResults.isNotEmpty, isTrue);

      final switcherResults = AppFeaturesCatalog.search('Quick Switcher');
      expect(switcherResults.isNotEmpty, isTrue);

      final storageResults = AppFeaturesCatalog.search('Storage Hygiene');
      expect(storageResults.isNotEmpty, isTrue);
    });
  });
}
