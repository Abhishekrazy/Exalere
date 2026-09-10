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

  const ExploreScreen({super.key, required this.title, required this.items});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _searchQuery = '';

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

    final filtered = widget.items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final titleMatches = item.title.toLowerCase().contains(query);
      final genreMatches = item.genre?.toLowerCase().contains(query) ?? false;
      return titleMatches || genreMatches;
    }).toList();

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

    if (!isTv && filtered.length <= 10 && crossAxisCount > 4) {
      crossAxisCount = 4;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.tokens.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                '${filtered.length} Titles',
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
              // Filter / Search in Section Bar
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTv ? 24 : 16,
                  isTv ? 2 : 4,
                  isTv ? 24 : 16,
                  isTv ? 8 : 12,
                ),
                child: Container(
                  height: isTv ? 40 : 46,
                  decoration: BoxDecoration(
                    color: context.tokens.surfaceElevated,
                    borderRadius: context.tokens.borderRadiusMd,
                    border: Border.all(color: context.tokens.borderSubtle),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontSize: isTv ? 13 : 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter in ${widget.title}...',
                      hintStyle: TextStyle(
                        color: context.tokens.textMuted,
                        fontSize: isTv ? 13 : 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.tokens.textSecondary,
                        size: isTv ? 18 : 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: context.tokens.textSecondary,
                                size: isTv ? 18 : 20,
                              ),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: isTv ? 8 : 12,
                      ),
                    ),
                  ),
                ),
              ),

              // Large, Responsive Cinematic Poster Grid
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 54,
                              color: context.tokens.textMuted,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No titles found matching "$_searchQuery"',
                              style: TextStyle(
                                color: context.tokens.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTv ? 24 : 16,
                          vertical: 8,
                        ),
                        // ignore: deprecated_member_use
                        cacheExtent: 2000,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: isTv ? 12 : 16,
                          mainAxisSpacing: isTv ? 14 : 20,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final heroTag = 'explore_${item.id}_$index';
                          return _ExploreCard(
                            item: item,
                            heroTag: heroTag,
                            onTap: () => _openDetails(context, item, heroTag),
                          );
                        },
                      ),
              ),
            ],
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

  const _ExploreCard({required this.item, required this.onTap, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = context.read<AppProvider>().isTvMode;

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
              color: context.tokens.shadowColor.withValues(alpha: 0.45),
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
              // High-Res Poster Image
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
              else if (item.isCam)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: context.tokens.vipColor.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: context.tokens.borderRadiusXs,
                      border: Border.all(
                        color: context.tokens.vipColor.withValues(alpha: 0.8),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      item.qualityTag ?? 'CAM',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.vipColor,
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
                      color: context.tokens.canvasBackground.withValues(
                        alpha: 0.8,
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
