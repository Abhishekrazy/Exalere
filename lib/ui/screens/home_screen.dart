import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../services/shelf_planner.dart';
import '../../providers/library_provider.dart';
import '../../providers/plugin_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/home/home_continue_watching_shelf.dart';
import '../widgets/home/home_media_shelf.dart';
import '../widgets/home/home_top_ten_shelf.dart';
import '../widgets/provider_selection_dialog.dart';
import '../widgets/skeleton_shimmer.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_play_helper.dart';
import 'details_screen.dart';
import 'explore_screen.dart';
import 'tv_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenProviderSetup});

  /// Invoked when the user taps "Add a Provider"; the shell switches to the
  /// Settings tab where the provider store lives.
  final VoidCallback? onOpenProviderSetup;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FocusNode _bannerWatchFocusNode = FocusNode(
    debugLabel: 'HomeBannerWatch',
  );
  final FocusNode _firstShelfCardFocusNode = FocusNode(
    debugLabel: 'HomeFirstShelfCard',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProviderPrompt();
    });
  }

  void _checkProviderPrompt() {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final pluginProvider = context.read<PluginProvider?>();
    final installedPlugins = pluginProvider?.plugins ?? [];

    if (!app.hasPromptedProviderSelection && installedPlugins.isNotEmpty) {
      ProviderSelectionDialog.show(context);
    }
  }

  @override
  void dispose() {
    _bannerWatchFocusNode.dispose();
    _firstShelfCardFocusNode.dispose();
    super.dispose();
  }

  void _safeFocus(FocusNode node) {
    if (node.canRequestFocus) {
      node.requestFocus();
      if (node.context != null) {
        Scrollable.ensureVisible(
          node.context!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

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

  /// Empty-catalogue view. Distinguishes the three reasons the shelf list can
  /// be empty, because the fix is different for each: nothing installed, nothing
  /// playable among what was found, or a network/feed failure.
  Widget _buildEmptyState(BuildContext context, AppProvider app) {
    final tokens = context.tokens;

    final IconData icon;
    final String title;
    final String message;
    final List<Widget> actions;

    if (app.needsProviderSetup) {
      icon = Icons.extension_off_rounded;
      title = 'No streaming provider installed';
      message =
          'Add at least one provider so Exalere can find playable streams. '
          'Only titles your providers can actually play will be shown.';
      actions = [
        _EmptyStateAction(
          icon: Icons.add_circle_outline_rounded,
          label: 'Add a Provider',
          autofocus: true,
          onTap: () => widget.onOpenProviderSetup?.call(),
        ),
      ];
    } else if (app.isCatalogueAvailabilityFiltered) {
      icon = Icons.filter_alt_off_rounded;
      title = 'No playable titles found';
      message =
          'Every title in the current catalog is unavailable on your installed '
          'providers. Browse a provider catalog directly, or turn off '
          '"Only Show Available Content" to browse the full metadata catalog.';
      actions = [
        _EmptyStateAction(
          icon: Icons.hub_rounded,
          label: 'Choose Catalog',
          autofocus: true,
          onTap: () =>
              ProviderSelectionDialog.show(context, isFromSettings: true),
        ),
        _EmptyStateAction(
          icon: Icons.visibility_rounded,
          label: 'Show All Titles',
          onTap: () => app.setOnlyShowAvailableOnProviders(false),
        ),
      ];
    } else {
      icon = Icons.wifi_off_rounded;
      title = 'Unable to load catalog';
      message =
          'Please check your internet connection or active catalog provider.';
      actions = [
        _EmptyStateAction(
          icon: Icons.refresh_rounded,
          label: 'Retry',
          autofocus: true,
          onTap: () => app.loadHomeFeeds(),
        ),
      ];
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: tokens.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: tokens.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = Theme.of(context);
    debugPrint(
      'HOME_SCREEN: build start, isLoadingHome=${app.isLoadingHome}, featured=${app.featuredFeed.length}, movies=${app.moviesFeed.length}',
    );

    if (app.isLoadingHome) {
      return const SkeletonHomeScreen();
    }

    if (app.featuredFeed.isEmpty &&
        app.moviesFeed.isEmpty &&
        app.seriesFeed.isEmpty) {
      return _buildEmptyState(context, app);
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

    final hasContinueWatching = library.continueWatching.isNotEmpty;
    final hasTopTen = topTenItems.isNotEmpty;
    final hasRec = recommendation.items.isNotEmpty;

    // The genre and editorial feeds overlap heavily, so the same film used to
    // appear in several consecutive rows. Planning them in display order lets
    // the topmost row claim a title; a row left with nothing is dropped rather
    // than rendered nearly empty. The hero and the library rows are not part of
    // this: they are different concepts, not catalogue duplicates.
    final shelfPlanner = ShelfPlanner();
    final trendingItems = shelfPlanner.next(app.trendingFeed);
    final popularItems = shelfPlanner.next(app.popularFeed);
    final movieShelfItems = shelfPlanner.next(app.moviesFeed);
    final seriesShelfItems = shelfPlanner.next(app.seriesFeed);
    final horrorItems = shelfPlanner.next(app.horrorFeed);
    final documentaryItems = shelfPlanner.next(app.documentaryFeed);
    final actionItems = shelfPlanner.next(app.actionFeed);
    final comedyItems = shelfPlanner.next(app.comedyFeed);
    final sciFiItems = shelfPlanner.next(app.sciFiFeed);

    final sections = <WidgetBuilder>[
      // 0. Browse-only notice: a metadata catalogue is showing, so playback is
      //    disabled until the user installs a provider that can resolve streams.
      if (app.needsProviderSetup)
        (context) =>
            _BrowseOnlyNotice(onAddProvider: widget.onOpenProviderSetup),

      // 1. Hero Billboard Carousel (Row 0)
      if (app.featuredFeed.isNotEmpty)
        (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BannerCarousel(
              items: app.featuredFeed.take(app.isTvMode ? 5 : 8).toList(),
              watchFocusNode: _bannerWatchFocusNode,
              onDownFocus: () {
                _safeFocus(_firstShelfCardFocusNode);
                return true;
              },
              onSelect: (item) => TvPlayHelper.playItem(context, item),
              onPlayDirect: (item) => TvPlayHelper.playItem(context, item),
              onInfo: (item) => _handleItemSelect(context, item, app.isTvMode),
            ),
            const SizedBox(height: 12),
          ],
        ),

      // 2. Continue Watching Shelf (Row 1 if present)
      if (hasContinueWatching)
        (context) => HomeContinueWatchingShelf(
          firstCardFocusNode: _firstShelfCardFocusNode,
          onUpFocus: () {
            _safeFocus(_bannerWatchFocusNode);
            return true;
          },
          onItemSelect: (item) =>
              _handleItemSelect(context, item, app.isTvMode),
        ),

      // 3. Top 10 Movies Today (Row 1 or Row 2)
      if (hasTopTen)
        (context) => HomeTopTenShelf(
          items: topTenItems,
          firstCardFocusNode: !hasContinueWatching
              ? _firstShelfCardFocusNode
              : null,
          onUpFocus: !hasContinueWatching
              ? () {
                  _safeFocus(_bannerWatchFocusNode);
                  return true;
                }
              : null,
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 4. Personalized Recommendations
      if (hasRec)
        (context) => HomeMediaShelf(
          title: recommendation.title,
          icon: Icons.auto_awesome_rounded,
          items: recommendation.items,
          shelfPrefix: 'recommended',
          firstCardFocusNode: (!hasContinueWatching && !hasTopTen)
              ? _firstShelfCardFocusNode
              : null,
          onUpFocus: (!hasContinueWatching && !hasTopTen)
              ? () {
                  _safeFocus(_bannerWatchFocusNode);
                  return true;
                }
              : null,
          onExplore: () =>
              _openExplore(context, recommendation.title, recommendation.items),
          onItemSelect: (item, heroTag) =>
              _handleItemSelect(context, item, app.isTvMode, heroTag),
        ),

      // 5. Trending Now Shelf
      if (trendingItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: "What's Trending",
          icon: Icons.local_fire_department_rounded,
          items: trendingItems,
          shelfPrefix: 'trending',
          firstCardFocusNode: (!hasContinueWatching && !hasTopTen && !hasRec)
              ? _firstShelfCardFocusNode
              : null,
          onUpFocus: (!hasContinueWatching && !hasTopTen && !hasRec)
              ? () {
                  _safeFocus(_bannerWatchFocusNode);
                  return true;
                }
              : null,
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
      if (popularItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: "What's Popular",
          icon: Icons.star_rounded,
          items: popularItems,
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
      if (movieShelfItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Blockbuster Movies',
          icon: Icons.movie_outlined,
          items: movieShelfItems,
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
      if (seriesShelfItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Binge-Worthy TV Series',
          icon: Icons.tv_rounded,
          items: seriesShelfItems,
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
      if (horrorItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Spine-Chilling Horror',
          icon: Icons.theater_comedy_rounded,
          items: horrorItems,
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
      if (documentaryItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Compelling Documentaries',
          icon: Icons.menu_book_rounded,
          items: documentaryItems,
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
      if (actionItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Action & Adventure',
          icon: Icons.sports_mma_rounded,
          items: actionItems,
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
      if (comedyItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Laugh-Out-Loud Comedy',
          icon: Icons.sentiment_very_satisfied_rounded,
          items: comedyItems,
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
      if (sciFiItems.isNotEmpty)
        (context) => HomeMediaShelf(
          title: 'Sci-Fi & Fantasy Universes',
          icon: Icons.rocket_launch_rounded,
          items: sciFiItems,
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
        clipBehavior: Clip.none,
        padding: EdgeInsets.only(bottom: isDesktopOrLandscape ? 24 : 96),
        cacheExtent: app.isTvMode ? 350.0 : 400.0,
        itemCount: sections.length,
        itemBuilder: (context, index) => sections[index](context),
      ),
    );
  }
}

/// Shown at the top of Home while a metadata-only catalogue is displayed.
///
/// Playback is unavailable until a provider that can resolve streams is
/// installed, so this states that plainly instead of leaving the user to
/// discover it by tapping Play.
class _BrowseOnlyNotice extends StatelessWidget {
  const _BrowseOnlyNotice({this.onAddProvider});

  final VoidCallback? onAddProvider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceCard,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: tokens.secondaryAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browsing only',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No streaming provider is installed, so playback is '
                    'disabled. Add a provider to start watching.',
                    style: TextStyle(fontSize: 12, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TvFocusable(
              onTap: onAddProvider ?? () {},
              borderRadius: tokens.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: tokens.borderRadiusSm,
                  border: Border.all(color: tokens.borderFocus),
                ),
                child: Text(
                  'Add Provider',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary action button used by the empty-catalogue views. Wrapped in
/// [TvFocusable] so every action stays reachable with a D-Pad.
class _EmptyStateAction extends StatelessWidget {
  const _EmptyStateAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return TvFocusable(
      autofocus: autofocus,
      onTap: onTap,
      borderRadius: tokens.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tokens.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
