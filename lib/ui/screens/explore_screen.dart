import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_themes.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

class ExploreScreen extends StatefulWidget {
  final String title;
  final List<MediaItem> items;
  final String? categoryKeyword;

  const ExploreScreen({
    super.key,
    required this.title,
    required this.items,
    this.categoryKeyword,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late List<MediaItem> _items;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _items = List<MediaItem>.from(widget.items);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400 &&
        !_isLoadingMore &&
        _hasMore &&
        widget.categoryKeyword != null) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || widget.categoryKeyword == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final app = context.read<AppProvider>();
      final movieBox = app.movieBoxProvider;
      _currentPage++;

      List<MediaItem> nextBatch = [];
      final keyword = widget.categoryKeyword!;

      if (keyword == 'movies' || keyword == 'movie') {
        nextBatch = await movieBox.getHomepageFeed(
          tabId: '1',
          page: _currentPage,
        );
      } else if (keyword == 'series') {
        nextBatch = await movieBox.getHomepageFeed(
          tabId: '2',
          page: _currentPage,
        );
      } else if (keyword == 'popular' || keyword == 'trending') {
        nextBatch = await movieBox.getHomepageFeed(
          tabId: '0',
          page: _currentPage,
        );
      } else {
        // Genre search query e.g. horror, documentary, action, comedy, sci-fi
        nextBatch = await movieBox.search(keyword);
        _hasMore = false; // Search returns all results
      }

      if (mounted) {
        if (nextBatch.isEmpty) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            final existingIds = _items.map((e) => e.id).toSet();
            final uniqueNew = nextBatch
                .where((e) => !existingIds.contains(e.id))
                .toList();
            _items.addAll(uniqueNew);
            _isLoadingMore = false;
            if (uniqueNew.isEmpty) _hasMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _openDetails(BuildContext context, MediaItem item, [String? heroTag]) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final uiScale = app.uiScale;

    // Responsive spacious card columns: smoothly scales for mobile, tablet, desktop, and TV
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

    if (!isTv && _items.length <= 10 && crossAxisCount > 4) {
      crossAxisCount = 4;
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: isTv
              ? null
              : IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: context.tokens.textPrimary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          automaticallyImplyLeading: !isTv,
          titleSpacing: isTv ? 24 : null,
          title: Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: isTv ? 18 : 20,
                  color: context.tokens.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: context.tokens.primaryAccent.withValues(alpha: 0.15),
                  borderRadius: context.tokens.borderRadiusPill,
                  border: Border.all(
                    color: context.tokens.primaryAccent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${_items.length} Titles',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: Column(
              children: [
                // Large, Responsive Cinematic Poster Grid
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.movie_outlined,
                                size: 54,
                                color: context.tokens.textMuted,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No titles available in ${widget.title}',
                                style: TextStyle(
                                  color: context.tokens.textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: isTv ? 24 : 16,
                            vertical: 8,
                          ),
                          cacheExtent: isTv ? 250.0 : 600.0,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.65,
                                crossAxisSpacing: isTv ? 12 : 16,
                                mainAxisSpacing: isTv ? 14 : 20,
                              ),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final heroTag = 'explore_${item.id}_$index';
                            return _ExploreCard(
                              item: item,
                              heroTag: heroTag,
                              autofocus: index == 0 && isTv,
                              onTap: () => _openDetails(context, item, heroTag),
                            );
                          },
                        ),
                ),
                if (_isLoadingMore)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final String? heroTag;
  final bool autofocus;

  const _ExploreCard({
    required this.item,
    required this.onTap,
    this.heroTag,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;

    final tokens = context.tokens;
    final cardRadius = tokens.cardRadius;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(color: tokens.borderSubtle, width: 1.0),
    );

    return TvFocusable(
      autofocus: autofocus,
      scaleFactor: 1.06,
      shape: shapeBorder,
      borderRadius: tokens.borderRadiusMd,
      onTap: onTap,
      child: Container(
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceCard,
          radius: cardRadius,
          side: BorderSide(color: tokens.borderSubtle, width: 1.0),
          shadows: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shapeBorder),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // High-Res Poster Image
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                (heroTag != null
                    ? Hero(
                        tag: heroTag!,
                        child: Material(
                          type: MaterialType.transparency,
                          child: CachedNetworkImage(
                            imageUrl: item.posterUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: isTv ? 180 : 320,
                            memCacheHeight: isTv ? 260 : 460,
                            maxWidthDiskCache: isTv ? 300 : 500,
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
                              color: tokens.surfaceElevated,
                              child: Icon(
                                Icons.movie_rounded,
                                size: 48,
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: isTv ? 180 : 320,
                        memCacheHeight: isTv ? 260 : 460,
                        maxWidthDiskCache: isTv ? 300 : 500,
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

              // Bottom Vignette Gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: context.tokens.scrimGradient,
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
                    decoration: tokens.getShapeDecoration(
                      color: tokens.secondaryAccent,
                      radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                      shadows: [
                        BoxShadow(
                          color: tokens.shadowColor.withValues(alpha: 0.5),
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
              else if (item.isCam)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: tokens.vipColor.withValues(alpha: 0.18),
                      radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                      side: BorderSide(
                        color: tokens.vipColor.withValues(alpha: 0.8),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      item.qualityTag ?? 'CAM',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: tokens.vipColor,
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
                    decoration: tokens.getShapeDecoration(
                      color: tokens.canvasBackground.withValues(alpha: 0.8),
                      radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                      side: BorderSide(
                        color: tokens.vipColor.withValues(alpha: 0.7),
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
