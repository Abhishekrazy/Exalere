import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_themes.dart';
import 'tv_focusable.dart';

/// TV and mobile responsive media card for search results and category grids.
class SearchMediaCard extends StatelessWidget {
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
      focusNode: focusNode,
      scaleFactor: 1.06,
      shape: shapeBorder,
      borderRadius: tokens.borderRadiusMd,
      onTap: onTap,
      onDirection: isTv
          ? (direction) {
              if (direction == TraversalDirection.up &&
                  isTopRow &&
                  onUp != null) {
                return onUp!();
              }
              if (direction == TraversalDirection.left && isFirstCol) {
                return true; // clamp – avoid jumping out accidentally
              }
              if (direction == TraversalDirection.right && isLastCol) {
                return true; // clamp at right edge
              }
              return false;
            }
          : null,
      child: Container(
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceCard,
          radius: cardRadius,
          side: BorderSide(color: tokens.borderSubtle, width: 1.0),
          shadows: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: 0.4),
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
              // High-Res Poster
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
                                child: Icon(
                                  Icons.movie_rounded,
                                  size: 32,
                                  color: tokens.textMuted.withValues(
                                    alpha: 0.3,
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
                            child: Icon(
                              Icons.movie_rounded,
                              size: 32,
                              color: tokens.textMuted.withValues(alpha: 0.3),
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

              // Bottom Gradient Scrim
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
                        tokens.canvasBackground.withValues(alpha: 0.0),
                        tokens.surfaceElevated.withValues(alpha: 0.65),
                        tokens.surfaceElevated.withValues(alpha: 0.95),
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
                      color: tokens.surfaceElevated.withValues(alpha: 0.85),
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
