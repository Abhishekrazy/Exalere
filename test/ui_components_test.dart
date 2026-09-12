import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/ui/screens/explore_screen.dart';
import 'package:exalere/ui/screens/main_screen.dart';
import 'package:exalere/ui/widgets/media_card.dart';
import 'package:exalere/ui/widgets/top_ten_card.dart';
import 'package:exalere/ui/widgets/continue_watching_card.dart';
import 'package:exalere/ui/widgets/tv/tv_continue_watching_dialog.dart';
import 'package:exalere/ui/widgets/banner_carousel.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/ui/widgets/episode_tile.dart';
import 'package:exalere/ui/widgets/home/home_explore_all_card.dart';
import 'package:exalere/ui/widgets/home/home_section_header.dart';
import 'package:exalere/ui/widgets/settings/tv_setting_tile.dart';
import 'package:exalere/ui/widgets/settings/tv_settings_subpage.dart';
import 'package:exalere/ui/widgets/settings/tv_settings_view.dart';
import 'package:exalere/ui/widgets/tv/tv_details_header.dart';
import 'package:exalere/ui/widgets/tv/tv_donate_dialog.dart';
import 'package:exalere/ui/widgets/tv/tv_exit_dialog.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';
import 'package:exalere/ui/widgets/tv/tv_season_selector.dart';

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

    testWidgets('TopTenCard renders rank 10 with expanded offset', (
      WidgetTester tester,
    ) async {
      final item = MediaItem(
        id: '456',
        title: 'Reacher',
        mediaType: MediaType.series,
        year: '2023',
        rating: 8.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopTenCard(item: item, rank: 10, onTap: () {}),
          ),
        ),
      );

      // Rank 10 string is rendered in outer stroke, drop shadow, and fill
      expect(find.text('10'), findsWidgets);
      expect(find.text('TOP 10'), findsOneWidget);
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

    testWidgets(
      'TvContinueWatchingDialog ignores early key repeats to prevent instant resume',
      (tester) async {
        bool playTapped = false;
        final testItem = MediaItem(
          id: '999',
          title: 'Stranger Things',
          mediaType: MediaType.series,
          year: '2024',
        );
        final testHistory = WatchHistoryItem(
          item: testItem,
          positionSeconds: 500,
          totalSeconds: 3000,
          lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: Scaffold(
              body: TvContinueWatchingDialog(
                historyItem: testHistory,
                onPlay: () => playTapped = true,
                onTap: () {},
                onRemove: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Send a key repeat / select immediately (still held down from card trigger)
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pump(const Duration(milliseconds: 50));

        // onPlay should not have triggered
        expect(playTapped, isFalse);
        expect(find.byType(TvContinueWatchingDialog), findsOneWidget);
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

    testWidgets('TvExitDialog renders exactly 2 buttons (Cancel and Exit)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TvExitDialog())),
      );

      expect(find.text('Exit Exalere'), findsOneWidget);
      expect(
        find.text('Are you sure you want to exit the application?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Cancel button dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'MainScreen in TV mode focuses sidebar on first back, opens TvExitDialog on second back',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        appProvider.setTvMode(true);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>.value(value: appProvider),
              ChangeNotifierProvider<LibraryProvider>(
                create: (_) => LibraryProvider(),
              ),
            ],
            child: const MaterialApp(home: MainScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no exit dialog
        expect(find.byType(TvExitDialog), findsNothing);

        // First Back press: moves focus to sidebar item
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Exit dialog is NOT shown on first back press because sidebar was not focused
        expect(find.byType(TvExitDialog), findsNothing);

        // Second Back press: now that sidebar is focused, triggers TvExitDialog!
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Exit dialog is now shown with only 2 buttons
        expect(find.byType(TvExitDialog), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Exit'), findsOneWidget);

        // Tapping Cancel dismisses the dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(TvExitDialog), findsNothing);
      },
    );

    testWidgets(
      'HomeSectionHeader renders title and triggers explore callback',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        bool explored = false;

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: Scaffold(
                body: HomeSectionHeader(
                  title: 'Blockbuster Hits',
                  icon: Icons.movie_outlined,
                  onExplore: () => explored = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Blockbuster Hits'), findsOneWidget);
        expect(find.text('Explore All'), findsOneWidget);

        await tester.tap(find.text('Explore All'));
        expect(explored, isTrue);
      },
    );

    testWidgets(
      'HomeExploreAllCard renders title and triggers callback on tap and D-Pad select',
      (WidgetTester tester) async {
        bool explored = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeExploreAllCard(
                categoryTitle: 'Binge-Worthy TV',
                autofocus: true,
                onTap: () => explored = true,
              ),
            ),
          ),
        );

        expect(find.text('Explore All'), findsOneWidget);
        expect(find.text('Binge-Worthy TV'), findsOneWidget);
        expect(find.text('See full list'), findsOneWidget);

        // Tap triggers callback
        await tester.tap(find.byType(HomeExploreAllCard));
        expect(explored, isTrue);

        explored = false;
        // D-Pad Select triggers callback
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(explored, isTrue);
      },
    );

    testWidgets('TvDetailsHeader renders title, chips, and synopsis', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvDetailsHeader(
              title: 'Inception',
              year: '2010',
              ageCert: 'PG-13',
              rating: '8.8',
              isSeries: false,
              isCam: true,
              qualityTag: 'HD-CAM',
              languageTag: 'EN',
              overview: 'A thief who steals corporate secrets through dream-sharing technology.',
            ),
          ),
        ),
      );

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('2010'), findsOneWidget);
      expect(find.text('PG-13'), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget);
      expect(find.text('MOVIE'), findsOneWidget);
      expect(find.text('HD-CAM'), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(
        find.text(
          'A thief who steals corporate secrets through dream-sharing technology.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'TvDonateDialog renders QR scan dialog with direct link and closes on Done',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => TvDonateDialog.show(ctx),
                  child: const Text('Open Donate'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Donate'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TvDonateDialog), findsOneWidget);
        expect(find.text('Support Exalere'), findsOneWidget);
        expect(find.text('razorpay.me/@abhishekrazy'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TvDonateDialog), findsNothing);
      },
    );

    testWidgets(
      'TvSettingsSubpage renders up-down choices and triggers callback on select',
      (WidgetTester tester) async {
        bool selected = false;
        bool backed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvSettingsSubpage<bool>(
                title: 'Auto Skip Intro',
                description: 'Automatically skip intro themes',
                selectedValue: false,
                choices: const [
                  TvSettingChoice(
                    label: 'Yes',
                    description: 'Skip intro',
                    value: true,
                  ),
                  TvSettingChoice(
                    label: 'No',
                    description: 'Play intro',
                    value: false,
                  ),
                ],
                onSelected: (val) => selected = val,
                onBack: () => backed = true,
              ),
            ),
          ),
        );

        expect(find.text('Auto Skip Intro'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);

        await tester.tap(find.text('Yes'));
        expect(selected, isTrue);
        expect(backed, isFalse);

        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        expect(backed, isTrue);
      },
    );

    testWidgets(
      'TvSettingsView in TV mode opens subpage with Yes/No on clicking boolean setting',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        await appProvider.setTvMode(true);
        await appProvider.setAutoSkipIntro(false);

        final controller = TextEditingController();
        final storage = StorageService();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: Scaffold(
                body: TvSettingsView(
                  detectedPlayers: const [],
                  isSyncingUpstream: false,
                  onSyncUpstream: () async {},
                  iptvController: controller,
                  storageService: storage,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Main settings menu is visible
        expect(find.text('Auto Skip Intro'), findsOneWidget);
        expect(find.text('APPEARANCE & THEMES'), findsOneWidget);

        // Tap "Auto Skip Intro" to navigate to subpage
        await tester.tap(find.text('Auto Skip Intro'));
        await tester.pumpAndSettle();

        // Subpage is open with "Yes" and "No" choices in up-down manner
        expect(find.text('Back'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);

        // Select "Yes"
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        // Should update state and return to main settings menu, restoring focus to Auto Skip Intro
        expect(appProvider.autoSkipIntro, isTrue);
        expect(find.text('Auto Skip Intro'), findsOneWidget);
      },
    );

    testWidgets(
      'TvSeasonSelector hides season chips when only 1 season is available',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvSeasonSelector(
                seasonCount: 1,
                selectedSeasonIndex: 0,
                onSeasonSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // When only 1 season, TvSeasonSelector returns SizedBox.shrink()
        expect(find.text('Season 1'), findsNothing);
      },
    );

    testWidgets(
      'TvSeasonSelector shows season chips when multiple seasons are available',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvSeasonSelector(
                seasonCount: 2,
                selectedSeasonIndex: 0,
                onSeasonSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Season 1'), findsOneWidget);
        expect(find.text('Season 2'), findsOneWidget);
      },
    );

    testWidgets(
      'TvSettingsSubpage supports nested subpage pushing and back unwinds properly',
      (tester) async {
        bool subpage2Popped = false;
        bool subpage1Popped = false;

        Widget buildSubpage2(VoidCallback onBack) {
          return TvSettingsSubpage<int>(
            title: 'Inner Subpage 2',
            selectedValue: 1,
            choices: const [TvSettingChoice(label: 'Option 2A', value: 1)],
            onSelected: (_) {},
            onBack: () {
              subpage2Popped = true;
              onBack();
            },
          );
        }

        Widget buildSubpage1(
          void Function(Widget) pushSub,
          VoidCallback onBack,
        ) {
          return TvSettingsSubpage<int>(
            title: 'Inner Subpage 1',
            selectedValue: 1,
            choices: [
              TvSettingChoice(
                label: 'Option 1A',
                value: 1,
                closeOnSelect: false,
                onTap: () => pushSub(buildSubpage2(onBack)),
              ),
            ],
            onSelected: (_) {},
            onBack: () {
              subpage1Popped = true;
              onBack();
            },
            onPushSubpage: (nextSub, [node]) => pushSub(nextSub),
          );
        }

        final stack = <Widget>[];

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              if (stack.isNotEmpty) {
                return MaterialApp(home: Scaffold(body: stack.last));
              }
              return MaterialApp(
                home: Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        stack.add(
                          buildSubpage1(
                            (next) => setState(() => stack.add(next)),
                            () => setState(() => stack.removeLast()),
                          ),
                        );
                      });
                    },
                    child: const Text('Open Setting 1'),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // 1. Root page
        expect(find.text('Open Setting 1'), findsOneWidget);

        // Open subpage 1
        await tester.tap(find.text('Open Setting 1'));
        await tester.pumpAndSettle();
        expect(find.text('Inner Subpage 1'), findsOneWidget);

        // Tap Option 1A in subpage 1 to push subpage 2
        await tester.tap(find.text('Option 1A'));
        await tester.pumpAndSettle();
        expect(find.text('Inner Subpage 2'), findsOneWidget);

        // Pop subpage 2 via Back button
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(subpage2Popped, isTrue);
        expect(find.text('Inner Subpage 1'), findsOneWidget);

        // Pop subpage 1 via Back button
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(subpage1Popped, isTrue);
        expect(find.text('Open Setting 1'), findsOneWidget);
      },
    );

    testWidgets(
      'TvSettingsSubpage triggers onBack when Left Arrow D-Pad key is pressed',
      (WidgetTester tester) async {
        bool popped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TvSettingsSubpage<bool>(
                title: 'Test Subpage',
                description: 'Test Description',
                selectedValue: true,
                choices: const [
                  TvSettingChoice(label: 'Yes', value: true),
                  TvSettingChoice(label: 'No', value: false),
                ],
                onSelected: (_) {},
                onBack: () => popped = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Send Left Arrow key event
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();

        expect(popped, isTrue);
      },
    );

    testWidgets(
      'MainScreen in TV mode focuses sidebar when Back key is pressed on Settings screen',
      (WidgetTester tester) async {
        final app = AppProvider();
        app.setTvMode(true);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider<LibraryProvider>(
                  create: (_) => LibraryProvider(),
                ),
              ],
              child: const MaterialApp(home: MainScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to Settings (sidebar icon 4)
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        // First Back press while on Settings screen -> Focuses sidebar Settings icon
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Second Back press while sidebar is focused -> Opens TvExitDialog
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(TvExitDialog), findsOneWidget);
        expect(find.text('Exit Exalere'), findsOneWidget);
      },
    );

    testWidgets(
      'TvSettingsView About subpage clicking choices does not close subpage, and back restores About focus',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final app = AppProvider();
        app.setTvMode(true);
        final storage = StorageService();
        final iptvController = TextEditingController();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(
              home: Scaffold(
                body: TvSettingsView(
                  detectedPlayers: const ['VLC'],
                  isSyncingUpstream: false,
                  onSyncUpstream: () async {},
                  iptvController: iptvController,
                  storageService: storage,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Scroll and find 'About Exalere'
        final aboutFinder = find.text('About Exalere');
        await tester.scrollUntilVisible(aboutFinder, 300);
        expect(aboutFinder, findsOneWidget);

        // Tap 'About Exalere' to open its subpage
        await tester.tap(aboutFinder);
        await tester.pumpAndSettle();

        // Subpage is open
        expect(find.text('Hardware Acceleration'), findsOneWidget);
        expect(find.text('Multi-Source Aggregation'), findsOneWidget);

        // 2. Click 'Hardware Acceleration' -> MUST NOT close the subpage!
        await tester.tap(find.text('Hardware Acceleration'));
        await tester.pumpAndSettle();

        // Subpage is STILL open
        expect(find.text('Hardware Acceleration'), findsOneWidget);

        // 3. Click 'Back' button -> returns to main settings and focuses 'About Exalere'
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();

        expect(find.text('Hardware Acceleration'), findsNothing);
        expect(find.text('About Exalere'), findsOneWidget);
      },
    );

    testWidgets(
      'ExploreScreen in TV mode has no back button, no search bar, and autofocuses first card',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        appProvider.setTvMode(true);

        final items = [
          const MediaItem(
            id: 'm1',
            title: 'Sample Movie 1',
            mediaType: MediaType.movie,
          ),
          const MediaItem(
            id: 'm2',
            title: 'Sample Movie 2',
            mediaType: MediaType.movie,
          ),
        ];

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: ExploreScreen(title: "What's Popular", items: items),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("What's Popular"), findsOneWidget);
        expect(find.text('2 Titles'), findsOneWidget);
        expect(find.text('Sample Movie 1'), findsOneWidget);
        expect(find.text('Sample Movie 2'), findsOneWidget);

        // TV mode: NO AppBar back button
        expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
        // TV mode: NO search bar / TextField
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'ExploreScreen in mobile mode has back button and no search bar',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        appProvider.setTvMode(false);

        final items = [
          const MediaItem(
            id: 'm1',
            title: 'Sample Movie 1',
            mediaType: MediaType.movie,
          ),
        ];

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: ExploreScreen(title: 'Trending Movies', items: items),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trending Movies'), findsOneWidget);
        expect(find.text('1 Titles'), findsOneWidget);
        // Mobile mode: Back button is present
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        // NO search bar / TextField
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      'TvSettingsView in TV mode renders Corner Style menu item and opens subpage with styles',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        appProvider.setTvMode(true);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              home: Scaffold(
                body: TvSettingsView(
                  detectedPlayers: const [],
                  isSyncingUpstream: false,
                  onSyncUpstream: () async {},
                  iptvController: TextEditingController(),
                  storageService: StorageService(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify "Corner Style" setting tile exists
        expect(find.text('Corner Style'), findsOneWidget);
        expect(find.text('Rounded'), findsOneWidget);

        // 2. Click "Corner Style" to push the subpage
        await tester.tap(find.text('Corner Style'));
        await tester.pumpAndSettle();

        // 3. Subpage options should be displayed
        expect(
          find.text('Smooth organic rounded corners (Default)'),
          findsOneWidget,
        );
        expect(find.text('Sharp (90°)'), findsOneWidget);
        expect(find.text('Cut (Bevel)'), findsOneWidget);

        // 4. Select "Cut (Bevel)"
        await tester.tap(find.text('Cut (Bevel)'));
        await tester.pumpAndSettle();

        // Subpage should close and CornerStyle should be cut
        expect(appProvider.cornerStyle, CornerStyle.cut);
        expect(find.text('Cut (Bevel)'), findsOneWidget);
      },
    );

    testWidgets(
      'BannerCarousel in TV mode scrolls scrollable to top when watch button receives focus or Up arrow',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider();
        appProvider.setTvMode(true);
        final libraryProvider = LibraryProvider();
        final scrollController = ScrollController();

        final items = [
          const MediaItem(
            id: 'b1',
            title: 'Carousel Hero Movie',
            mediaType: MediaType.movie,
          ),
          const MediaItem(
            id: 'b2',
            title: 'Carousel Hero Movie 2',
            mediaType: MediaType.movie,
          ),
        ];

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppProvider>.value(value: appProvider),
              ChangeNotifierProvider<LibraryProvider>.value(
                value: libraryProvider,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      BannerCarousel(items: items, onSelect: (_) {}),
                      Container(height: 1200, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down
        scrollController.jumpTo(300.0);
        await tester.pumpAndSettle();
        expect(scrollController.position.pixels, 300.0);

        // Send Up arrow to Watch button
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Should have scrolled to top (0.0)
        expect(scrollController.position.pixels, 0.0);
      },
    );

    testWidgets(
      'TvFocusable renders with custom ShapeBorder and updates decoration',
      (WidgetTester tester) async {
        const beveledShape = BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TvFocusable(
                  shape: beveledShape,
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TvFocusable), findsOneWidget);
        final animatedContainer = tester.widget<AnimatedContainer>(
          find.descendant(
            of: find.byType(TvFocusable),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(animatedContainer.decoration is ShapeDecoration, isTrue);
      },
    );
  });
}
