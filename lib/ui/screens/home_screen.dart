import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/home/home_continue_watching_shelf.dart';
import '../widgets/home/home_media_shelf.dart';
import '../widgets/home/home_top_ten_shelf.dart';
import '../widgets/skeleton_shimmer.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'explore_screen.dart';
import 'tv_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleItemSelect(
    BuildContext context,
    MediaItem item,
    bool isTv, [
    String? heroTag,
  ]) {
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      _openDetails(context, item, heroTag);
    }
  }

  void _openDetails(BuildContext context, MediaItem item, [String? heroTag]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailsScreen(mediaItem: item, heroTag: heroTag),
      ),
    );
  }

  void _openExplore(
    BuildContext context,
    String title,
    List<MediaItem> items, [
    String? categoryKeyword,
  ]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreScreen(
          title: title,
          items: items,
          categoryKeyword: categoryKeyword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    if (app.isLoadingHome && app.featuredFeed.isEmpty) {
      return const SkeletonHomeScreen();
    }

    final topTenItems =
        (app.moviesFeed.isNotEmpty ? app.moviesFeed : app.featuredFeed)
            .take(10)
            .toList();

    final recommendation = library.getPersonalizedRecommendations(
      app.allCataloguePool.isNotEmpty ? app.allCataloguePool : app.featuredFeed,
    );

    final isDesktopOrLandscape =
        MediaQuery.of(context).size.width >= 800 || app.isTvMode;

    final sections = <WidgetBuilder>[
      // 1. Hero Billboard Carousel
      if (app.featuredFeed.isNotEmpty)
        (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BannerCarousel(
              items: app.featuredFeed.take(app.isTvMode ? 5 : 8).toList(),
              onSelect: (item) => TvPlayHelper.playItem(context, item),
              onPlayDirect: (item) => TvPlayHelper.playItem(context, item),
              onInfo: (item) => _handleItemSelect(context, item, app.isTvMode),
            ),
            const SizedBox(height: 12),
          ],
        ),

      // 2. Continue Watching Shelf
      if (library.continueWatching.isNotEmpty)
        (context) => HomeContinueWatchingShelf(
          onItemSelect: (item) =>
              _handleItemSelect(context, item, app.isTvMode),
        ),

      // 3. Top 10 Movies Today
      if (topTenItems.isNotEmpty)
        (context) => HomeTopTenShelf(
          items: topTenItems,
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 4. Personalized Recommendations
      if (recommendation.items.isNotEmpty)
        (context) => HomeMediaShelf(
          title: recommendation.title,
          icon: Icons.auto_awesome_rounded,
          items: recommendation.items,
          shelfPrefix: 'recommended',
          onExplore: () =>
              _openExplore(context, recommendation.title, recommendation.items),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 5. Trending Now Shelf
      if (app.trendingFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: "What's Trending",
          icon: Icons.local_fire_department_rounded,
          items: app.trendingFeed,
          shelfPrefix: 'trending',
          onExplore: () => _openExplore(
            context,
            "What's Trending",
            app.trendingFeed,
            'trending',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 6. What's Popular Shelf
      if (app.popularFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: "What's Popular",
          icon: Icons.star_rounded,
          items: app.popularFeed,
          shelfPrefix: 'popular',
          onExplore: () => _openExplore(
            context,
            "What's Popular",
            app.popularFeed,
            'popular',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 7. Blockbuster Movies Shelf
      if (app.moviesFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Blockbuster Movies',
          icon: Icons.movie_outlined,
          items: app.moviesFeed,
          shelfPrefix: 'movies',
          onExplore: () => _openExplore(
            context,
            'Blockbuster Movies',
            app.moviesFeed,
            'movies',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 8. Binge-Worthy TV Series Shelf
      if (app.seriesFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Binge-Worthy TV Series',
          icon: Icons.tv_rounded,
          items: app.seriesFeed,
          shelfPrefix: 'series',
          onExplore: () => _openExplore(
            context,
            'Binge-Worthy TV Series',
            app.seriesFeed,
            'series',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 9. Spine-Chilling Horror Shelf
      if (app.horrorFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Spine-Chilling Horror',
          icon: Icons.theater_comedy_rounded,
          items: app.horrorFeed,
          shelfPrefix: 'horror',
          onExplore: () => _openExplore(
            context,
            'Spine-Chilling Horror',
            app.horrorFeed,
            'horror',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 10. Compelling Documentaries Shelf
      if (app.documentaryFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Compelling Documentaries',
          icon: Icons.menu_book_rounded,
          items: app.documentaryFeed,
          shelfPrefix: 'documentaries',
          onExplore: () => _openExplore(
            context,
            'Compelling Documentaries',
            app.documentaryFeed,
            'documentary',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 11. Action & Adventure Shelf
      if (app.actionFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Action & Adventure',
          icon: Icons.sports_mma_rounded,
          items: app.actionFeed,
          shelfPrefix: 'action',
          onExplore: () => _openExplore(
            context,
            'Action & Adventure',
            app.actionFeed,
            'action',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 12. Laugh-Out-Loud Comedy Shelf
      if (app.comedyFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Laugh-Out-Loud Comedy',
          icon: Icons.sentiment_very_satisfied_rounded,
          items: app.comedyFeed,
          shelfPrefix: 'comedy',
          onExplore: () => _openExplore(
            context,
            'Laugh-Out-Loud Comedy',
            app.comedyFeed,
            'comedy',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 13. Sci-Fi & Fantasy Shelf
      if (app.sciFiFeed.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Sci-Fi & Fantasy Universes',
          icon: Icons.rocket_launch_rounded,
          items: app.sciFiFeed,
          shelfPrefix: 'scifi',
          onExplore: () => _openExplore(
            context,
            'Sci-Fi & Fantasy Universes',
            app.sciFiFeed,
            'sci-fi',
          ),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await app.loadHomeFeeds();
        await library.init();
      },
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: isDesktopOrLandscape ? 24 : 96),
        cacheExtent: app.isTvMode ? 350.0 : 400.0,
        itemCount: sections.length,
        itemBuilder: (context, index) => sections[index](context),
      ),
    );
  }
}
