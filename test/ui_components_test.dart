import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/ui/screens/main_screen.dart';
import 'package:exalere/ui/widgets/media_card.dart';
import 'package:exalere/ui/widgets/top_ten_card.dart';
import 'package:exalere/ui/widgets/continue_watching_card.dart';
import 'package:exalere/ui/widgets/tv/tv_continue_watching_dialog.dart';
import 'package:exalere/ui/widgets/banner_carousel.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/ui/widgets/episode_tile.dart';
import 'package:exalere/ui/widgets/settings/tv_setting_tile.dart';

void main() {
  group('UI/UX Components Tests', () {
    testWidgets('TopTenCard renders rank number and title', (
      WidgetTester tester,
    ) async {
      final item = MediaItem(
        id: '123',
        title: 'Stranger Things',
        mediaType: MediaType.series,
        year: '2022',
        rating: 8.7,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopTenCard(item: item, rank: 1, onTap: () => tapped = true),
          ),
        ),
      );

      expect(find.text('1'), findsWidgets);
      expect(find.text('TOP 10'), findsOneWidget);

      await tester.tap(find.byType(TopTenCard));
      expect(tapped, isTrue);
    });

    testWidgets('ContinueWatchingCard renders title and progress bar', (
      WidgetTester tester,
    ) async {
      final item = MediaItem(
        id: '456',
        title: 'Inception',
        mediaType: MediaType.movie,
        year: '2010',
      );

      final historyItem = WatchHistoryItem(
        item: item,
        positionSeconds: 1200,
        totalSeconds: 2400,
        lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
        season: 1,
        episode: 3,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContinueWatchingCard(
              historyItem: historyItem,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('S1 E3'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, 0.5);

      await tester.tap(find.byType(ContinueWatchingCard));
      expect(tapped, isTrue);
    });

    testWidgets(
      'ContinueWatchingCard triggers onPlay when play button tapped, onTap otherwise',
      (WidgetTester tester) async {
        final item = MediaItem(
          id: '789',
          title: 'Breaking Bad',
          mediaType: MediaType.series,
          year: '2008',
        );

        final historyItem = WatchHistoryItem(
          item: item,
          positionSeconds: 600,
          totalSeconds: 3000,
          lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
          season: 1,
          episode: 1,
        );

        bool playTapped = false;
        bool detailsTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ContinueWatchingCard(
                historyItem: historyItem,
                onPlay: () => playTapped = true,
                onTap: () => detailsTapped = true,
              ),
            ),
          ),
        );

        // Tap specifically on the play button icon
        await tester.tap(find.byIcon(Icons.play_arrow_rounded));
        await tester.pump();
        expect(playTapped, isTrue);
        expect(detailsTapped, isFalse);

        // Tap on title text (outside play button)
        await tester.tap(find.text('Breaking Bad'));
        await tester.pump();
        expect(detailsTapped, isTrue);
      },
    );

    testWidgets(
      'ContinueWatchingCard in TV mode opens context dialog on Hold-OK',
      (WidgetTester tester) async {
        final item = MediaItem(
          id: '789',
          title: 'Reacher',
          mediaType: MediaType.series,
          year: '2022',
        );

        final historyItem = WatchHistoryItem(
          item: item,
          positionSeconds: 600,
          totalSeconds: 3000,
          lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
          season: 1,
          episode: 7,
        );

        bool playTapped = false;
        bool detailsTapped = false;
        bool removeTapped = false;

        final appProvider = AppProvider();
        appProvider.setTvMode(true);

        final cardFocus = FocusNode(debugLabel: 'TestCardFocus');

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: Scaffold(
                body: ContinueWatchingCard(
                  historyItem: historyItem,
                  focusNode: cardFocus,
                  onPlay: () => playTapped = true,
                  onTap: () => detailsTapped = true,
                  onRemove: () => removeTapped = true,
                ),
              ),
            ),
          ),
        );

        // Focus the ContinueWatchingCard
        cardFocus.requestFocus();
        await tester.pump();

        // Send KeyDown for Select key (Hold OK)
        await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
        // Wait 600ms to trigger the long press timer
        await tester.pump(const Duration(milliseconds: 600));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // Context dialog is now visible!
        expect(find.byType(TvContinueWatchingDialog), findsOneWidget);
        expect(find.text('Resume Playback'), findsOneWidget);
        expect(find.text('View Details Page'), findsOneWidget);
        expect(find.text('Remove from Continue Watching'), findsOneWidget);

        // Tap View Details Page
        await tester.tap(find.text('View Details Page'));
        await tester.pumpAndSettle();
        expect(detailsTapped, isTrue);
        expect(playTapped, isFalse);
        expect(removeTapped, isFalse);
      },
    );

    test('MediaItem.fromMovieBoxJson correctly extracts horizontalCover and banner as backdropUrl', () {
      final json1 = {
        'subjectId': 'sub123',
        'title': 'House of the Dragon',
        'subjectType': 2,
        'cover': {'url': 'https://example.com/poster.jpg'},
        'horizontalCover': {'url': 'https://example.com/backdrop.jpg'},
      };
      final item1 = MediaItem.fromMovieBoxJson(json1);
      expect(item1.backdropUrl, 'https://example.com/backdrop.jpg');
      expect(item1.posterUrl, 'https://example.com/poster.jpg');

      final json2 = {
        'id': 'sub456',
        'name': 'Dune: Part Two',
        'banner': {'url': 'https://example.com/banner.jpg'},
      };
      final item2 = MediaItem.fromMovieBoxJson(json2);
      expect(item2.backdropUrl, 'https://example.com/banner.jpg');

      final updated = item2.copyWith(
        backdropUrl: 'https://image.tmdb.org/t/p/w1280/dune.jpg',
      );
      expect(updated.backdropUrl, 'https://image.tmdb.org/t/p/w1280/dune.jpg');
      expect(updated.title, 'Dune: Part Two');
    });

    testWidgets('BannerCarousel renders featured items, title, and buttons', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final library = LibraryProvider();
      await library.init();

      final items = [
        const MediaItem(
          id: 'sub123',
          title: 'House of the Dragon',
          mediaType: MediaType.series,
          year: '2024',
          rating: 8.5,
          genre: 'Action & Adventure',
        ),
      ];

      MediaItem? selectedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<LibraryProvider>.value(
            value: library,
            child: Scaffold(
              body: BannerCarousel(
                items: items,
                onSelect: (item) => selectedItem = item,
              ),
            ),
          ),
        ),
      );

      expect(find.text('House of the Dragon'), findsOneWidget);
      expect(find.text('SERIES SPOTLIGHT'), findsOneWidget);
      expect(find.text('4K ULTRA HD'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('My List'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

      await tester.tap(find.text('Play'));
      expect(selectedItem?.id, 'sub123');
    });

    testWidgets(
      'BannerCarousel infinite forward scroll loops seamlessly in one direction',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final library = LibraryProvider();
        await library.init();

        final items = [
          const MediaItem(
            id: '1',
            title: 'Movie One',
            mediaType: MediaType.movie,
          ),
          const MediaItem(
            id: '2',
            title: 'Movie Two',
            mediaType: MediaType.movie,
          ),
          const MediaItem(
            id: '3',
            title: 'Movie Three',
            mediaType: MediaType.movie,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider<LibraryProvider>.value(
              value: library,
              child: Scaffold(
                body: BannerCarousel(items: items, onSelect: (_) {}),
              ),
            ),
          ),
        );

        // Initially on Movie One
        expect(find.text('Movie One'), findsOneWidget);

        // Swipe forward (drag left) -> advances forward to Movie Two
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.text('Movie Two'), findsOneWidget);

        // Swipe forward -> advances forward to Movie Three
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.text('Movie Three'), findsOneWidget);

        // Swipe forward again -> loops forward seamlessly to Movie One (no abrupt rewind!)
        await tester.drag(find.byType(PageView), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(find.text('Movie One'), findsOneWidget);
      },
    );

    testWidgets(
      'BannerCarousel in TV mode hides Prev/Next and advances slide with D-Pad Right',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final library = LibraryProvider();
        await library.init();
        final appProvider = AppProvider();
        appProvider.setTvMode(true);

        final items = [
          const MediaItem(
            id: '1',
            title: 'Movie One',
            mediaType: MediaType.movie,
          ),
          const MediaItem(
            id: '2',
            title: 'Movie Two',
            mediaType: MediaType.movie,
          ),
        ];

        MediaItem? playedItem;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LibraryProvider>.value(value: library),
              ChangeNotifierProvider<AppProvider>.value(value: appProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: BannerCarousel(
                  items: items,
                  onSelect: (_) {},
                  onPlayDirect: (item) => playedItem = item,
                ),
              ),
            ),
          ),
        );

        // In TV mode, TV Prev & Next buttons and My List button are NOT present
        expect(find.text('Prev'), findsNothing);
        expect(find.text('Next'), findsNothing);
        expect(find.text('Watch'), findsOneWidget);
        expect(find.text('My List'), findsNothing);
        expect(find.text('1 of 2'), findsOneWidget);
        expect(find.text('Movie One'), findsOneWidget);

        // Press D-Pad Right on Watch button to advance slide
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // Indicator updates to 2 of 2, title updates to Movie Two
        expect(find.text('2 of 2'), findsOneWidget);
        expect(find.text('Watch'), findsOneWidget);
        expect(find.text('Movie Two'), findsOneWidget);

        // Tapping Watch plays Movie Two
        await tester.tap(find.text('Watch'));
        expect(playedItem?.id, '2');
      },
    );

    testWidgets(
      'MainScreen does not wrap content in SelectionArea to prevent text selection on buttons',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        final libraryProvider = LibraryProvider();
        await libraryProvider.init();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>.value(value: appProvider),
              ChangeNotifierProvider<LibraryProvider>.value(
                value: libraryProvider,
              ),
            ],
            child: const MaterialApp(home: MainScreen()),
          ),
        );

        expect(find.byType(SelectionArea), findsNothing);
        expect(find.text('Home'), findsWidgets);
      },
    );

    testWidgets('EpisodeGridCard renders in grid without bottom overflow', (
      WidgetTester tester,
    ) async {
      const episode = Episode(
        season: 1,
        episode: 1,
        title: 'Chauhano Ki Shaan',
        overview: 'A deep story exploring family ties and rivalries.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                height: 224, // 280 / 1.25
                child: EpisodeGridCard(
                  episode: episode,
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1. Chauhano Ki Shaan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'MediaCard and TopTenCard render Hero with correct tag when provided',
      (WidgetTester tester) async {
        final item = MediaItem(
          id: 'hero_101',
          title: 'Interstellar',
          mediaType: MediaType.movie,
          posterUrl: 'https://image.tmdb.org/t/p/w500/test.jpg',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaCard(
                item: item,
                heroTag: 'movies_hero_101_0',
                onTap: () {},
              ),
            ),
          ),
        );

        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsOneWidget);
        final heroWidget = tester.widget<Hero>(heroFinder);
        expect(heroWidget.tag, 'movies_hero_101_0');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TopTenCard(
                item: item,
                rank: 1,
                heroTag: 'top10_hero_101_0',
                onTap: () {},
              ),
            ),
          ),
        );

        final topTenHeroFinder = find.byType(Hero);
        expect(topTenHeroFinder, findsOneWidget);
        final topTenHeroWidget = tester.widget<Hero>(topTenHeroFinder);
        expect(topTenHeroWidget.tag, 'top10_hero_101_0');
      },
    );

    test(
      'MediaItem.parseTitleTags strips bracketed tags and extracts languageTag',
      () {
        final res1 = MediaItem.parseTitleTags('My Bias, My Boss [Hindi]');
        expect(res1.cleanTitle, 'My Bias, My Boss');
        expect(res1.languageTag, 'Hindi');

        final res2 = MediaItem.parseTitleTags('Solo Leveling [Dual Audio]');
        expect(res2.cleanTitle, 'Solo Leveling');
        expect(res2.languageTag, 'Dual Audio');

        final res3 = MediaItem.parseTitleTags('Demon Slayer (Hindi Dubbed)');
        expect(res3.cleanTitle, 'Demon Slayer');
        expect(res3.languageTag, 'Hindi Dubbed');

        final res4 = MediaItem.parseTitleTags('Inception');
        expect(res4.cleanTitle, 'Inception');
        expect(res4.languageTag, isNull);
      },
    );

    testWidgets(
      'MediaCard renders clean title and HINDI badge when title has [Hindi]',
      (WidgetTester tester) async {
        final item = const MediaItem(
          id: '999',
          title: 'My Bias, My Boss [Hindi]',
          mediaType: MediaType.series,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaCard(item: item, onTap: () {}),
            ),
          ),
        );

        // Clean title rendered, cheap bracketed text removed from title
        expect(find.text('My Bias, My Boss'), findsOneWidget);
        expect(find.text('My Bias, My Boss [Hindi]'), findsNothing);

        // Distinct language badge rendered
        expect(find.text('HINDI'), findsOneWidget);
      },
    );

    testWidgets(
      'TvSettingSwitchTile toggles value with D-Pad Select and click',
      (WidgetTester tester) async {
        bool settingValue = false;
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return TvSettingSwitchTile(
                    title: 'Auto-Skip Intro',
                    subtitle: 'Jump past opening titles',
                    value: settingValue,
                    focusNode: focusNode,
                    onChanged: (val) {
                      setState(() => settingValue = val);
                    },
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Auto-Skip Intro'), findsOneWidget);
        expect(find.text('Jump past opening titles'), findsOneWidget);
        expect(settingValue, isFalse);

        // Tap tile to toggle
        await tester.tap(find.text('Auto-Skip Intro'));
        await tester.pumpAndSettle();
        expect(settingValue, isTrue);

        // Focus and press D-Pad Select key to toggle
        focusNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(settingValue, isFalse);
      },
    );

    testWidgets(
      'TvSettingActionTile invokes onTap when clicked or D-Pad Select pressed',
      (WidgetTester tester) async {
        bool actionTriggered = false;
        final focusNode = FocusNode();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvSettingActionTile(
                title: 'Check for Updates',
                subtitle: 'Check GitHub releases',
                focusNode: focusNode,
                onTap: () => actionTriggered = true,
              ),
            ),
          ),
        );

        expect(find.text('Check for Updates'), findsOneWidget);

        // Focus and press D-Pad Select key
        focusNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(actionTriggered, isTrue);
      },
    );
  });
}
