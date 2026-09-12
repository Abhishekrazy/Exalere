import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/media_card.dart';
import 'package:exalere/ui/widgets/tv/tv_episode_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TV Performance & Memory Protection Tests', () {
    testWidgets(
      'TvEpisodeCard uses bounded memory cache and zero fade to protect TV heap',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider()..setTvMode(true);
        final libraryProvider = LibraryProvider();

        const episode = Episode(
          season: 1,
          episode: 1,
          title: 'Pilot',
          overview: 'Test overview',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: appProvider),
              ChangeNotifierProvider.value(value: libraryProvider),
            ],
            child: MaterialApp(
              theme: AppThemes.netflixBlack.themeData,
              home: Scaffold(
                body: TvEpisodeCard(
                  episode: episode,
                  thumbnailUrl: 'https://image.tmdb.org/t/p/w500/test.jpg',
                  title: 'Pilot',
                  overview: 'Test overview',
                  resumePositionSeconds: 0,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final cachedImageFinder = find.byType(CachedNetworkImage);
        expect(cachedImageFinder, findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(
          cachedImageFinder,
        );
        expect(cachedImage.memCacheWidth, 260);
        expect(cachedImage.memCacheHeight, 150);
        expect(cachedImage.maxWidthDiskCache, 350);
        expect(cachedImage.fadeInDuration, Duration.zero);
        expect(cachedImage.fadeOutDuration, Duration.zero);

        // Verify placeholder does NOT contain spinning CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'MediaCard uses TV-bounded memory cache and static placeholder without CircularProgressIndicator',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final appProvider = AppProvider()..setTvMode(true);

        const mediaItem = MediaItem(
          id: 'm1',
          title: 'Test Movie',
          mediaType: MediaType.movie,
          posterUrl: 'https://image.tmdb.org/t/p/w500/poster.jpg',
        );

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: appProvider,
            child: MaterialApp(
              theme: AppThemes.netflixBlack.themeData,
              home: Scaffold(
                body: MediaCard(
                  item: mediaItem,
                  width: 140,
                  height: 210,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final cachedImageFinder = find.byType(CachedNetworkImage);
        expect(cachedImageFinder, findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(
          cachedImageFinder,
        );
        // On TV, memory cache width is strictly bounded to 180x260
        expect(cachedImage.memCacheWidth, 180);
        expect(cachedImage.memCacheHeight, 260);
        expect(cachedImage.maxWidthDiskCache, 300);

        // Verify placeholder does NOT spin CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });
}
