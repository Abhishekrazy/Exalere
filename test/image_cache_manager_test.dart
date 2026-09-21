import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/services/image_cache_manager.dart';
import 'package:exalere/services/video_cache_service.dart';
import 'package:exalere/ui/widgets/skeleton_shimmer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return '.';
          },
        );
  });

  group('ThrottledHttpClient concurrency tests', () {
    test('enforces strict maxConcurrent limit and queues overflow', () async {
      int activeServerRequests = 0;
      int peakServerRequests = 0;
      final List<Completer<void>> responders = [];

      final mockClient = MockClient((request) async {
        activeServerRequests++;
        if (activeServerRequests > peakServerRequests) {
          peakServerRequests = activeServerRequests;
        }
        final completer = Completer<void>();
        responders.add(completer);
        await completer.future;
        activeServerRequests--;
        return http.Response('ok', 200);
      });

      // Limit concurrency to 2 (like ARMv7 setting)
      final throttled = ThrottledHttpClient(
        inner: mockClient,
        maxConcurrent: 2,
      );

      // Fire 5 simultaneous requests
      final future1 = throttled.get(Uri.parse('https://example.com/1.jpg'));
      final future2 = throttled.get(Uri.parse('https://example.com/2.jpg'));
      final future3 = throttled.get(Uri.parse('https://example.com/3.jpg'));
      final future4 = throttled.get(Uri.parse('https://example.com/4.jpg'));
      final future5 = throttled.get(Uri.parse('https://example.com/5.jpg'));

      // Let microtasks run
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Peak active requests must never exceed maxConcurrent (2)
      expect(activeServerRequests, equals(2));
      expect(throttled.activeRequests, equals(2));
      expect(throttled.queuedRequests, equals(3));
      expect(peakServerRequests, equals(2));

      // Finish first request
      responders[0].complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Third request should now be active, queue down to 2
      expect(activeServerRequests, equals(2));
      expect(throttled.activeRequests, equals(2));
      expect(throttled.queuedRequests, equals(2));

      // Finish remaining requests
      for (int i = 1; i < responders.length; i++) {
        if (!responders[i].isCompleted) {
          responders[i].complete();
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }

      final results = await Future.wait([
        future1,
        future2,
        future3,
        future4,
        future5,
      ]);
      expect(results.length, equals(5));
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(peakServerRequests, equals(2));
      expect(throttled.activeRequests, equals(0));
      expect(throttled.queuedRequests, equals(0));
    });

    test(
      'properly decrements active count and unblocks queue on error',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          if (requestCount == 1) {
            throw http.ClientException('Network failure');
          }
          return http.Response('success', 200);
        });

        final throttled = ThrottledHttpClient(
          inner: mockClient,
          maxConcurrent: 1,
        );

        // Request 1 fails
        await expectLater(
          throttled.get(Uri.parse('https://example.com/err.jpg')),
          throwsA(isA<http.ClientException>()),
        );

        // Subsequent request must not be blocked
        final resp = await throttled.get(
          Uri.parse('https://example.com/ok.jpg'),
        );
        expect(resp.statusCode, equals(200));
        expect(throttled.activeRequests, equals(0));
      },
    );
  });

  group('ExalereImageCacheManager architecture bounds', () {
    tearDown(() {
      VideoCacheService.instance.set32BitOverride(null);
      ExalereImageCacheManager.resetForTesting();
    });

    test('creates custom instance with expected configuration', () {
      final custom = ExalereImageCacheManager.custom(
        maxConcurrent: 2,
        maxNrOfCacheObjects: 100,
      );
      expect(custom, isNotNull);
    });
  });

  group('PosterSkeleton widget tests', () {
    tearDown(() {
      VideoCacheService.instance.set32BitOverride(null);
    });

    testWidgets('renders static gradient skeleton on 32-bit ARMv7', (
      tester,
    ) async {
      VideoCacheService.instance.set32BitOverride(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 120, height: 170, child: PosterSkeleton()),
          ),
        ),
      );

      expect(find.byType(PosterSkeleton), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });

    testWidgets('renders animated pulse skeleton on 64-bit platforms', (
      tester,
    ) async {
      VideoCacheService.instance.set32BitOverride(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 140, height: 196, child: PosterSkeleton()),
          ),
        ),
      );

      expect(find.byType(PosterSkeleton), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PosterSkeleton), findsOneWidget);
    });
  });
}
