import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/ui/screens/library_screen.dart';
import 'package:exalere/ui/theme/app_themes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService Already Watched & Provider Availability Tests', () {
    test(
      'StorageService persists already watched items and toggle status',
      () async {
        final storage = StorageService();
        final movie = MediaItem(
          id: 'mv-1',
          title: 'Inception',
          mediaType: MediaType.movie,
        );

        expect(await storage.isAlreadyWatched('mv-1'), isFalse);
        expect(await storage.getAlreadyWatched(), isEmpty);

        // Toggle to watched
        final added = await storage.toggleAlreadyWatched(movie);
        expect(added, isTrue);
        expect(await storage.isAlreadyWatched('mv-1'), isTrue);
        final list = await storage.getAlreadyWatched();
        expect(list.length, equals(1));
        expect(list.first.id, equals('mv-1'));

        // Toggle to unwatched
        final removed = await storage.toggleAlreadyWatched(movie);
        expect(removed, isFalse);
        expect(await storage.isAlreadyWatched('mv-1'), isFalse);
        expect(await storage.getAlreadyWatched(), isEmpty);
      },
    );

    test(
      'StorageService persists onlyShowAvailableOnProviders setting',
      () async {
        final storage = StorageService();
        // Default is true
        expect(await storage.getOnlyShowAvailableOnProviders(), isTrue);

        await storage.setOnlyShowAvailableOnProviders(false);
        expect(await storage.getOnlyShowAvailableOnProviders(), isFalse);

        await storage.setOnlyShowAvailableOnProviders(true);
        expect(await storage.getOnlyShowAvailableOnProviders(), isTrue);
      },
    );
  });

  group('LibraryProvider Already Watched & Continue Watching Logic', () {
    test('toggleAlreadyWatched updates list and notifies listeners', () async {
      final library = LibraryProvider();
      await library.init();

      final movie = MediaItem(
        id: 'mv-42',
        title: 'The Dark Knight',
        mediaType: MediaType.movie,
      );

      expect(library.isAlreadyWatched('mv-42'), isFalse);
      expect(library.alreadyWatched, isEmpty);

      await library.toggleAlreadyWatched(movie);
      expect(library.isAlreadyWatched('mv-42'), isTrue);
      expect(library.alreadyWatched.length, equals(1));
      expect(library.alreadyWatched.first.id, equals('mv-42'));

      await library.toggleAlreadyWatched(movie);
      expect(library.isAlreadyWatched('mv-42'), isFalse);
      expect(library.alreadyWatched, isEmpty);
    });

    test('isAlreadyWatched returns true for completed history items (progress >= 95% or isWatched)', () async {
      final library = LibraryProvider();
      await library.init();

      final movie = MediaItem(
        id: 'mv-complete',
        title: 'Interstellar',
        mediaType: MediaType.movie,
      );

      // Watch 98% of 10,000s
      await library.recordProgress(
        item: movie,
        positionSeconds: 9800,
        totalSeconds: 10000,
      );

      expect(library.isAlreadyWatched('mv-complete'), isTrue);
    });

    test(
      'continueWatching getter excludes items that are in alreadyWatched',
      () async {
        final library = LibraryProvider();
        await library.init();

        final movie1 = MediaItem(
          id: 'mv-in-progress',
          title: 'Dune',
          mediaType: MediaType.movie,
        );
        final movie2 = MediaItem(
          id: 'mv-watched',
          title: 'Oppenheimer',
          mediaType: MediaType.movie,
        );

        // Both have watch progress
        await library.recordProgress(
          item: movie1,
          positionSeconds: 3600,
          totalSeconds: 7200,
        );
        await library.recordProgress(
          item: movie2,
          positionSeconds: 3600,
          totalSeconds: 7200,
        );

        expect(library.continueWatching.length, equals(2));

        // Mark movie2 as already watched
        await library.toggleAlreadyWatched(movie2);

        // movie2 should now be excluded from continueWatching
        expect(library.continueWatching.length, equals(1));
        expect(
          library.continueWatching.first.item.id,
          equals('mv-in-progress'),
        );
        expect(library.alreadyWatched.any((m) => m.id == 'mv-watched'), isTrue);
      },
    );

    test('markAsAlreadyWatched explicitly sets watched state', () async {
      final library = LibraryProvider();
      await library.init();

      final item = MediaItem(
        id: 'series-1',
        title: 'Breaking Bad',
        mediaType: MediaType.series,
      );

      await library.markAsAlreadyWatched(item, true);
      expect(library.isAlreadyWatched('series-1'), isTrue);

      await library.markAsAlreadyWatched(item, false);
      expect(library.isAlreadyWatched('series-1'), isFalse);
    });
  });

  group('AppProvider Content Filtering & Fallback Search', () {
    test('AppProvider gets and sets onlyShowAvailableOnProviders', () async {
      final app = AppProvider();
      await app.init();

      expect(app.onlyShowAvailableOnProviders, isTrue);

      await app.setOnlyShowAvailableOnProviders(false);
      expect(app.onlyShowAvailableOnProviders, isFalse);

      await app.setOnlyShowAvailableOnProviders(true);
      expect(app.onlyShowAvailableOnProviders, isTrue);
    });
  });

  group('LibraryScreen 3-Tab UI Widget Tests', () {
    testWidgets(
      'LibraryScreen renders 3 tabs (Watchlist, Continue Watching, Already Watched)',
      (tester) async {
        final library = LibraryProvider();
        await library.init();
        final app = AppProvider();
        await app.init();
        final plugin = PluginProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: library),
              ChangeNotifierProvider.value(value: app),
              ChangeNotifierProvider.value(value: plugin),
            ],
            child: MaterialApp(
              theme: AppThemes.darkTheme.themeData,
              home: const Scaffold(body: LibraryScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify all 3 tab labels exist
        expect(find.text('Watchlist'), findsWidgets);
        expect(find.text('Continue Watching'), findsOneWidget);
        expect(find.text('Already Watched'), findsOneWidget);

        // Verify initial page shows empty state for Watchlist
        expect(find.text('Your Watchlist is empty'), findsOneWidget);

        // Tap on "Already Watched"
        await tester.tap(find.text('Already Watched'));
        await tester.pumpAndSettle();

        // Verify page switched to Already Watched empty state
        expect(find.text('No watched titles yet'), findsOneWidget);
        expect(
          find.text(
            'Mark movies and shows as Already Watched to track your viewing history',
          ),
          findsOneWidget,
        );

        // Tap on "Continue Watching"
        await tester.tap(find.text('Continue Watching'));
        await tester.pumpAndSettle();

        // Verify page switched to Continue Watching empty state
        expect(find.text('No active playback history'), findsOneWidget);
      },
    );
  });
}
