import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'SearchScreenInput',
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          final moved = node.focusInDirection(TraversalDirection.down);
          if (moved) return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            _controller.selection.baseOffset <= 0) {
          final moved = node.focusInDirection(TraversalDirection.left);
          if (moved) return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );
  bool _isSearchFocused = false;

  final List<String> _trendingGenres = [
    'Action',
    'Sci-Fi',
    'Anime',
    'Marvel',
    'Bollywood',
    'Thriller',
    'Comedy',
    'Horror',
    'Romance',
    'Documentary',
  ];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _controller.text = app.searchQuery;
    _searchFocusNode.addListener(_onSearchFocusChanged);
    if (app.trendingTitles.isEmpty && !app.isLoadingHome) {
      Future.microtask(() => app.loadHomeFeeds());
    }
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleItemSelect(MediaItem item, [String? heroTag]) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailsScreen(mediaItem: item, heroTag: heroTag),
        ),
      );
    }
  }

  void _searchGenre(String genre) {
    _controller.text = genre;
    context.read<AppProvider>().searchCategory(genre);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    final isTv = app.isTvMode;
    final uiScale = app.uiScale;

    // Responsive grid columns: smoothly scales for mobile, tablet, desktop, and TV
    int crossAxisCount;
    if (isTv) {
      if (width < 900) {
        crossAxisCount = 5;
      } else if (width < 1200) {
        crossAxisCount = 6;
      } else if (width < 1600) {
        crossAxisCount = 7;
      } else {
        crossAxisCount = 8;
      }
    } else {
      if (width < 450) {
        crossAxisCount = 2;
      } else if (width < 700) {
        crossAxisCount = 3;
      } else if (width < 950) {
        crossAxisCount = 4;
      } else if (width < 1250) {
        crossAxisCount = 5;
      } else if (width < 1600) {
        crossAxisCount = 6;
      } else {
        crossAxisCount = 7;
      }
    }

    if (uiScale < 0.92) {
      crossAxisCount = (crossAxisCount + 1).clamp(2, 9);
    }

    final isDesktop = width >= 800 || isTv;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        left: !isDesktop && !isTv,
        right: !isDesktop && !isTv,
        top: !isDesktop && !isTv,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Search Input Row with Separated Search Button on the Right
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isTv ? 24 : 16,
                  isTv ? 6 : 12,
                  isTv ? 24 : 16,
                  isTv ? 4 : 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: context.tokens.surfaceElevated,
                          borderRadius: context.tokens.borderRadiusMd,
                          border: Border.all(
                            color: _isSearchFocused
                                ? context.tokens.borderFocus
                                : context.tokens.borderSubtle,
                            width: _isSearchFocused ? 1.8 : 1.0,
                          ),
                          boxShadow: [
                            if (_isSearchFocused)
                              BoxShadow(
                                color: context.tokens.primaryAccent.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              )
                            else
                              BoxShadow(
                                color: context.tokens.shadowColor.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: TextField(
                          focusNode: _searchFocusNode,
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (query) {
                            app.search(query);
                            _searchFocusNode.unfocus();
                          },
                          style: TextStyle(
                            color: context.tokens.textPrimary,
                            fontSize: isTv ? 14 : 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search movies, TV shows, anime across all providers...',
                            hintStyle: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: isTv ? 13 : 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: context.tokens.textSecondary,
                              size: isTv ? 18 : 20,
                            ),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: context.tokens.textSecondary,
                                      size: isTv ? 18 : 20,
                                    ),
                                    onPressed: () {
                                      _controller.clear();
                                      app.clearSearch();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isTv ? 10 : 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Separated Search Action Button
                    TvFocusable(
                      scaleFactor: 1.05,
                      borderRadius: context.tokens.borderRadiusMd,
                      onTap: () {
                        app.search(_controller.text.trim());
                        _searchFocusNode.unfocus();
                      },
                      child: Container(
                        height: isTv ? 44 : 50,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTv ? 16 : 20,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: context.tokens.borderRadiusMd,
                          boxShadow: [
                            BoxShadow(
                              color: context.tokens.primaryAccent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.onPrimary,
                              size: isTv ? 18 : 20,
                            ),
                            if (width >= 500) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Search',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTv ? 13 : 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Trending Searches & Quick Genre Chips with TvFocusable (scrolls with page)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _trendingGenres.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final genre = _trendingGenres[index];
                      final isCurrent =
                          app.searchQuery.toLowerCase() == genre.toLowerCase();
                      return TvFocusable(
                        scaleFactor: 1.08,
                        borderRadius: context.tokens.borderRadiusPill,
                        onTap: () => _searchGenre(genre),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? context.tokens.primaryAccent.withValues(
                                    alpha: 0.25,
                                  )
                                : context.tokens.surfaceElevated.withValues(
                                    alpha: 0.7,
                                  ),
                            borderRadius: context.tokens.borderRadiusPill,
                            border: Border.all(
                              color: isCurrent
                                  ? context.tokens.primaryAccent
                                  : context.tokens.borderSubtle,
                              width: isCurrent ? 1.4 : 1.0,
                            ),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : context.tokens.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Results / Trending / Loading / Empty state
            if (app.isSearching)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Scanning catalogue across all providers...',
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (app.searchResults.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 24 : 16,
                  vertical: 8,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: isTv ? 12 : 16,
                    mainAxisSpacing: isTv ? 14 : 18,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = app.searchResults[index];
                    final heroTag = 'search_${item.id}_$index';
                    return _SearchMediaCard(
                      item: item,
                      heroTag: heroTag,
                      onTap: () => _handleItemSelect(item, heroTag),
                    );
                  }, childCount: app.searchResults.length),
                ),
              )
            else if (app.searchQuery.isEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isTv ? 24 : 16,
                    8,
                    isTv ? 24 : 16,
                    8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: context.tokens.primaryAccent,
                        size: isTv ? 18 : 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trending & Popular Now',
                        style: TextStyle(
                          color: context.tokens.textPrimary,
                          fontSize: isTv ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (app.trendingTitles.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTv ? 24 : 16,
                    vertical: 8,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: isTv ? 12 : 16,
                      mainAxisSpacing: isTv ? 14 : 18,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = app.trendingTitles[index];
                      final heroTag = 'trending_${item.id}_$index';
                      return _SearchMediaCard(
                        item: item,
                        heroTag: heroTag,
                        onTap: () => _handleItemSelect(item, heroTag),
                      );
                    }, childCount: app.trendingTitles.length),
                  ),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (app.isLoadingHome) ...[
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Loading trending titles...',
                            style: TextStyle(
                              color: context.tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            Icons.movie_filter_rounded,
                            size: 64,
                            color: context.tokens.borderSubtle,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Discover movies & series across MovieBox & 4KHDHub',
                            style: TextStyle(
                              color: context.tokens.textSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ] else
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.movie_filter_rounded,
                        size: 64,
                        color: context.tokens.borderSubtle,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No safe results found for "${app.searchQuery}"',
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Try another title or pick a category above',
                          style: TextStyle(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchMediaCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final String? heroTag;

  const _SearchMediaCard({
    required this.item,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;
    final is4K =
        item.provider == ProviderType.fourKHdHub ||
        item.title.contains('4K') ||
        (item.year?.contains('4K') ?? false);

    return TvFocusable(
      scaleFactor: 1.06,
      borderRadius: context.tokens.borderRadiusMd,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.surfaceCard,
          borderRadius: context.tokens.borderRadiusMd,
          border: Border.all(color: context.tokens.borderSubtle, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: context.tokens.shadowColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: context.tokens.borderRadiusMd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // High-Res Poster
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                (heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: Material(
                          type: MaterialType.transparency,
                          child: ClipRRect(
                            borderRadius: context.tokens.borderRadiusMd,
                            child: CachedNetworkImage(
                              imageUrl: item.posterUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 320,
                              memCacheHeight: 460,
                              maxWidthDiskCache: 500,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, _) => Container(
                                color: theme.colorScheme.surface,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: context.tokens.surfaceElevated,
                                child: Icon(
                                  Icons.movie_rounded,
                                  size: 48,
                                  color: context.tokens.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 320,
                        memCacheHeight: 460,
                        maxWidthDiskCache: 500,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, _) => Container(
                          color: theme.colorScheme.surface,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: context.tokens.surfaceElevated,
                          child: Icon(
                            Icons.movie_rounded,
                            size: 48,
                            color: context.tokens.textMuted,
                          ),
                        ),
                      ))
              else
                Container(
                  color: context.tokens.surfaceElevated,
                  child: Icon(
                    Icons.movie_rounded,
                    size: 48,
                    color: context.tokens.textMuted,
                  ),
                ),

              // Bottom Gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 110,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        context.tokens.surfaceElevated.withValues(alpha: 0.65),
                        context.tokens.surfaceElevated.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              // Series / Format Pill (Top Left)
              if (item.isSeries)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.secondaryAccent,
                      borderRadius: context.tokens.borderRadiusXs,
                      boxShadow: [
                        BoxShadow(
                          color: context.tokens.shadowColor.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      'SERIES',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: theme.colorScheme.onSecondary,
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: item.isCam
                          ? context.tokens.vipColor.withValues(alpha: 0.18)
                          : context.tokens.surfaceElevated.withValues(
                              alpha: 0.85,
                            ),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: item.isCam
                            ? context.tokens.vipColor.withValues(alpha: 0.8)
                            : context.tokens.borderSubtle,
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      item.isCam
                          ? (item.qualityTag ?? 'CAM')
                          : (is4K ? '4K UHD' : 'HD'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: item.isCam
                            ? context.tokens.vipColor
                            : context.tokens.textSecondary,
                      ),
                    ),
                  ),
                ),

              // Rating Badge (Top Right)
              if (item.rating != null && item.rating! > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.surfaceElevated.withValues(
                        alpha: 0.85,
                      ),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: context.tokens.vipColor.withValues(alpha: 0.7),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: context.tokens.vipColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          item.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: context.tokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Title & Metadata Overlay
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.cleanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTv ? 11.5 : 13,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (item.year != null) ...[
                          Text(
                            item.year!,
                            style: TextStyle(
                              fontSize: isTv ? 10 : 11,
                              color: context.tokens.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(
                              color: context.tokens.textMuted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (item.genre != null)
                          Expanded(
                            child: Text(
                              item.genre!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isTv ? 10 : 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
