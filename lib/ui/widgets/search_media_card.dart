import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../services/image_cache_manager.dart';
import '../../services/video_cache_service.dart';
import '../theme/app_tokens.dart';
import 'dpad/dpad.dart';
import 'skeleton_shimmer.dart';

/// TV and mobile responsive media card for search results and category grids.
///
/// Matches the visual language, poster elevation, badge hierarchy, and typography
/// of the Home screen [MediaCard] while adapting smoothly to grid cells.
class SearchMediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final String? heroTag;
  final FocusNode? focusNode;
  final bool isTopRow;
  final bool isFirstCol;
  final bool isLastCol;

  /// Called when D-Pad Up is pressed on the top row; return true to consume.
  final bool Function()? onUp;

  const SearchMediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.heroTag,
    this.focusNode,
    this.isTopRow = false,
    this.isFirstCol = false,
    this.isLastCol = false,
    this.onUp,
  });

  @override
  State<SearchMediaCard> createState() => _SearchMediaCardState();
}

class _SearchMediaCardState extends State<SearchMediaCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isTv = context.read<AppProvider>().isTvMode;
    final isActive = _isHovered || _isFocused;

    final cardRadius = tokens.cornerStyle == CornerStyle.sharp
        ? 0.0
        : tokens.cardRadius;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(
        color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
        width: isActive ? 2.5 : 1.0,
      ),
    );

    final yearStr = widget.item.year;
    final genreStr = widget.item.genre;
    final langStr = widget.item.effectiveLanguageTag;
    final subtitleParts = <String>[];
    if (yearStr != null && yearStr.isNotEmpty) subtitleParts.add(yearStr);
    if (genreStr != null && genreStr.isNotEmpty) subtitleParts.add(genreStr);
    if (langStr != null && langStr.isNotEmpty) {
      subtitleParts.add(langStr.toUpperCase());
    }
    final subtitle = subtitleParts.join(' • ');

    final is32Bit = VideoCacheService.instance.is32BitOrLowRam;
    final memWidth = is32Bit ? (isTv ? 110 : 160) : (isTv ? 180 : 320);
    final memHeight = is32Bit ? (isTv ? 160 : 230) : (isTv ? 260 : 460);
    final diskWidth = is32Bit ? (isTv ? 200 : 300) : (isTv ? 300 : 500);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DpadFocusable(
        focusNode: widget.focusNode,
        onSelect: widget.onTap,
        onDirection: isTv
            ? (direction) {
                if (direction == TraversalDirection.up &&
                    widget.isTopRow &&
                    widget.onUp != null) {
                  return widget.onUp!();
                }
                if (direction == TraversalDirection.left && widget.isFirstCol) {
                  return true; // clamp – avoid jumping out accidentally
                }
                if (direction == TraversalDirection.right && widget.isLastCol) {
                  return true; // clamp at right edge
                }
                return false;
              }
            : null,
        onFocusChange: (focused) {
          if (!mounted) return;
          setState(() => _isFocused = focused);
        },
        builder: (context, state, child) {
          final isDpadFocused = state.focused;
          final isCardActive = isDpadFocused || _isHovered;
          return AnimatedScale(
            scale: state.pressed ? 0.98 : (isCardActive ? 1.06 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: tokens.borderRadiusSm,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster Image Container honoring CornerStyle & Morphism
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: tokens.getShapeDecoration(
                    color: theme.colorScheme.surface,
                    radius: cardRadius,
                    side: BorderSide.none,
                    shadows: isActive
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 14,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : tokens.getCardShadows(),
                  ),
                  foregroundDecoration: ShapeDecoration(shape: shapeBorder),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(shape: shapeBorder),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: theme.colorScheme.surface,
                          child:
                              widget.item.posterUrl != null &&
                                  widget.item.posterUrl!.isNotEmpty
                              ? (widget.heroTag != null
                                    ? Hero(
                                        tag: widget.heroTag!,
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: CachedNetworkImage(
                                            imageUrl: widget.item.posterUrl!,
                                            cacheManager:
                                                ExalereImageCacheManager
                                                    .instance,
                                            fit: BoxFit.cover,
                                            memCacheWidth: memWidth,
                                            memCacheHeight: memHeight,
                                            maxWidthDiskCache: diskWidth,
                                            fadeInDuration: Duration.zero,
                                            fadeOutDuration: Duration.zero,
                                            placeholder: (context, url) =>
                                                const PosterSkeleton(),
                                            errorWidget:
                                                (context, url, error) => Center(
                                                  child: Icon(
                                                    Icons.movie_outlined,
                                                    size: 36,
                                                    color: tokens.textMuted,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: widget.item.posterUrl!,
                                        cacheManager:
                                            ExalereImageCacheManager.instance,
                                        fit: BoxFit.cover,
                                        memCacheWidth: memWidth,
                                        memCacheHeight: memHeight,
                                        maxWidthDiskCache: diskWidth,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholder: (context, url) =>
                                            const PosterSkeleton(),
                                        errorWidget: (context, url, error) =>
                                            Center(
                                              child: Icon(
                                                Icons.movie_outlined,
                                                size: 36,
                                                color: tokens.textMuted,
                                              ),
                                            ),
                                      ))
                              : Center(
                                  child: Icon(
                                    Icons.movie_outlined,
                                    size: 36,
                                    color: tokens.textMuted,
                                  ),
                                ),
                        ),

                        // Series badge (Top Left)
                        if (widget.item.isSeries)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                color: tokens.secondaryAccent.withValues(
                                  alpha: 0.85,
                                ),
                                shape: tokens.getShapeBorder(radius: 4),
                              ),
                              child: Text(
                                'SERIES',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: theme.colorScheme.onSecondary,
                                ),
                              ),
                            ),
                          ),

                        // 4K / HD Quality & Language Pill (Bottom Left)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.item.isCam)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: tokens.vipColor.withValues(
                                      alpha: 0.18,
                                    ),
                                    shape: tokens.getShapeBorder(
                                      radius: 4,
                                      side: BorderSide(
                                        color: tokens.vipColor.withValues(
                                          alpha: 0.75,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    widget.item.qualityTag ?? 'CAM',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.vipColor,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              if (widget.item.effectiveLanguageTag != null &&
                                  widget
                                      .item
                                      .effectiveLanguageTag!
                                      .isNotEmpty) ...[
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: tokens.surfaceElevated.withValues(
                                      alpha: 0.85,
                                    ),
                                    shape: tokens.getShapeBorder(
                                      radius: 4,
                                      side: BorderSide(
                                        color: tokens.primaryAccent.withValues(
                                          alpha: 0.6,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    widget.item.effectiveLanguageTag!
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.primaryAccent,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Rating Badge (Top Right)
                        if (widget.item.rating != null &&
                            widget.item.rating! > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                color: tokens.surfaceElevated.withValues(
                                  alpha: 0.85,
                                ),
                                shape: tokens.getShapeBorder(
                                  radius: 4,
                                  side: BorderSide(
                                    color: tokens.vipColor.withValues(
                                      alpha: 0.6,
                                    ),
                                    width: 0.6,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: tokens.vipColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.item.rating!.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: isTv ? 4 : 6),

              // Media Title
              Text(
                widget.item.cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isTv ? 10.5 : 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),

              // Subtitle: Year • Genre • Language
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTv ? 9.5 : 11,
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
