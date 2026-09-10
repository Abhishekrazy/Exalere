import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/continue_watching_card.dart';
import '../widgets/media_card.dart';
import '../widgets/top_ten_card.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'explore_screen.dart';
import 'tv_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _handleItemSelect(BuildContext context, MediaItem item, bool isTv) {
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      _openDetails(context, item);
    }
  }

  void _openDetails(BuildContext context, MediaItem item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DetailsScreen(mediaItem: item)));
  }

  void _openExplore(BuildContext context, String title, List<MediaItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreScreen(title: title, items: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);

    if (app.isLoadingHome && app.featuredFeed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Curating movies & series for you...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Prepare Top 10 items
    final topTenItems =
        (app.moviesFeed.isNotEmpty ? app.moviesFeed : app.featuredFeed)
            .take(10)
            .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await app.loadHomeFeeds();
        await library.init();
      },
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          // 1. Hero Billboard Carousel
          if (app.featuredFeed.isNotEmpty)
            BannerCarousel(
              items: app.featuredFeed.take(8).toList(),
              onSelect: (item) =>
                  _handleItemSelect(context, item, app.isTvMode),
              onPlayDirect: (item) => TvPlayHelper.playItem(context, item),
            ),

          const SizedBox(height: 12),

          // 2. Continue Watching Shelf (16:9 Landscape with pinned red progress bar)
          if (library.history.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              title: 'Continue Watching',
              icon: Icons.play_circle_outline_rounded,
            ),
            SizedBox(
              height: app.isTvMode ? 144 : 156,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 500.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                itemCount: library.history.length,
                itemBuilder: (context, index) {
                  final h = library.history[index];
                  return ContinueWatchingCard(
                    historyItem: h,
                    onTap: () =>
                        _handleItemSelect(context, h.item, app.isTvMode),
                    onRemove: () => library.removeFromHistory(
                      h.item.id,
                      season: h.season,
                      episode: h.episode,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: app.isTvMode ? 14 : 24),
          ],

          // 3. The Signature "Top 10 in Movies Today" Numbered Shelf (Netflix Style)
          if (topTenItems.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              title: 'Top 10 Movies Today',
              icon: Icons.trending_up_rounded,
            ),
            SizedBox(
              height: app.isTvMode ? 190 : 216,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 500.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                itemCount: topTenItems.length,
                itemBuilder: (context, index) {
                  final item = topTenItems[index];
                  return TopTenCard(
                    item: item,
                    rank: index + 1,
                    onTap: () => _handleItemSelect(context, item, app.isTvMode),
                  );
                },
              ),
            ),
            SizedBox(height: app.isTvMode ? 14 : 24),
          ],

          // 4. Blockbuster Movies Shelf
          if (app.moviesFeed.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              title: 'Blockbuster Movies',
              icon: Icons.movie_outlined,
              onExplore: () =>
                  _openExplore(context, 'Blockbuster Movies', app.moviesFeed),
            ),
            SizedBox(
              height: app.isTvMode ? 236 : 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 500.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                itemCount: app.moviesFeed.length,
                itemBuilder: (context, index) {
                  final item = app.moviesFeed[index];
                  return MediaCard(
                    item: item,
                    onTap: () => _handleItemSelect(context, item, app.isTvMode),
                  );
                },
              ),
            ),
            SizedBox(height: app.isTvMode ? 14 : 24),
          ],

          // 5. Binge-Worthy TV Series Shelf
          if (app.seriesFeed.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              title: 'Binge-Worthy TV Series',
              icon: Icons.tv_rounded,
              onExplore: () => _openExplore(
                context,
                'Binge-Worthy TV Series',
                app.seriesFeed,
              ),
            ),
            SizedBox(
              height: app.isTvMode ? 236 : 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 500.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                itemCount: app.seriesFeed.length,
                itemBuilder: (context, index) {
                  final item = app.seriesFeed[index];
                  return MediaCard(
                    item: item,
                    onTap: () => _handleItemSelect(context, item, app.isTvMode),
                  );
                },
              ),
            ),
            SizedBox(height: app.isTvMode ? 14 : 24),
          ],

          // 6. Trending & Recommended Shelf
          if (app.featuredFeed.length > 8) ...[
            _buildSectionHeader(
              context,
              title: 'Trending & Popular',
              icon: Icons.local_fire_department_rounded,
              onExplore: () =>
                  _openExplore(context, 'Trending & Popular', app.featuredFeed),
            ),
            SizedBox(
              height: app.isTvMode ? 236 : 260,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 500.0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                itemCount: app.featuredFeed.skip(8).length,
                itemBuilder: (context, index) {
                  final item = app.featuredFeed.skip(8).toList()[index];
                  return MediaCard(
                    item: item,
                    onTap: () => _handleItemSelect(context, item, app.isTvMode),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    VoidCallback? onExplore,
  }) {
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isTv ? 6 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: isTv ? 15 : 18,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: context.tokens.primaryAccent,
                  borderRadius: context.tokens.borderRadiusXs,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: isTv ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  color: context.tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          if (onExplore != null)
            InkWell(
              onTap: onExplore,
              borderRadius: context.tokens.borderRadiusSm,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Explore All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
