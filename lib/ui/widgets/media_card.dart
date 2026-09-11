import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_tokens.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final double height;
  final String? customBadge;
  final String? heroTag;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 140,
    this.height = 196,
    this.customBadge,
    this.heroTag,
    this.isLastCard = false,
    this.isFirstCard = false,
  });

  /// Prevents D-Pad Right from escaping the shelf at the right edge.
  final bool isLastCard;

  /// Prevents D-Pad Left from escaping the shelf at the left edge.
  final bool isFirstCard;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _isHovered || _isFocused;

    bool isTv = false;
    double uiScale = 1.0;
    try {
      final app = context.watch<AppProvider>();
      isTv = app.isTvMode;
      uiScale = app.uiScale;
    } catch (_) {}

    final scaleMultiplier = uiScale < 0.92
        ? 0.92
        : (uiScale > 1.08 ? 1.08 : 1.0);
    final defaultWidth = isTv ? 115.0 : 140.0;
    final defaultHeight = isTv ? 158.0 : 196.0;
    final baseWidth = widget.width != 140.0 ? widget.width : defaultWidth;
    final baseHeight = widget.height != 196.0 ? widget.height : defaultHeight;
    final cardWidth = baseWidth * scaleMultiplier;
    final cardHeight = baseHeight * scaleMultiplier;

    final tokens = context.tokens;
    final cardRadius = tokens.borderRadiusSm.topLeft.x;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(
        color: isActive ? theme.colorScheme.primary : tokens.borderSubtle,
        width: isActive ? 2.0 : 1.0,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DpadFocusable(
        onSelect: widget.onTap,
        onDirection: (direction) {
          if (widget.isLastCard && direction == TraversalDirection.right) {
            return true;
          }
          return false;
        },
        onFocusChange: (focused) {
          if (!mounted) return;
          setState(() => _isFocused = focused);
        },
        builder: (context, state, child) {
          final isFocused = state.focused;
          final isActive = isFocused || _isHovered;
          return AnimatedScale(
            scale: state.pressed ? 0.98 : (isActive ? 1.06 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: child,
          );
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: tokens.borderRadiusSm,
          child: Container(
            width: cardWidth,
            margin: EdgeInsets.symmetric(horizontal: isTv ? 4 : 6, vertical: 4),
            child: ClipRect(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster Image Container honoring CornerStyle & Morphism
                  Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: tokens.getShapeDecoration(
                      color: theme.colorScheme.surface,
                      radius: cardRadius,
                      side: BorderSide(
                        color: isActive
                            ? theme.colorScheme.primary
                            : tokens.borderSubtle,
                        width: isActive ? 2.0 : 1.0,
                      ),
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
                    child: ClipPath(
                      clipper: ShapeBorderClipper(shape: shapeBorder),
                      child: Stack(
                        children: [
                          Container(
                            width: cardWidth,
                            height: cardHeight,
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
                                              fit: BoxFit.cover,
                                              memCacheWidth: isTv ? 180 : 320,
                                              memCacheHeight: isTv ? 260 : 460,
                                              maxWidthDiskCache: isTv
                                                  ? 300
                                                  : 500,
                                              fadeInDuration: Duration.zero,
                                              fadeOutDuration: Duration.zero,
                                              placeholder: (context, url) => Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                ),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Center(
                                                        child: Icon(
                                                          Icons.movie_outlined,
                                                          size: 36,
                                                          color:
                                                              tokens.textMuted,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: widget.item.posterUrl!,
                                          fit: BoxFit.cover,
                                          memCacheWidth: isTv ? 180 : 320,
                                          memCacheHeight: isTv ? 260 : 460,
                                          maxWidthDiskCache: isTv ? 300 : 500,
                                          fadeInDuration: Duration.zero,
                                          fadeOutDuration: Duration.zero,
                                          placeholder: (context, url) => Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
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

                          // Bottom Gradient on Poster for depth
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    tokens.canvasBackground.withValues(
                                      alpha: 0.0,
                                    ),
                                    tokens.canvasBackground.withValues(
                                      alpha: 0.7,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Custom or Series badge (Top Left)
                          if (widget.customBadge != null)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: ShapeDecoration(
                                  color: tokens.primaryAccent,
                                  shape: tokens.getShapeBorder(radius: 4),
                                ),
                                child: Text(
                                  widget.customBadge!,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            )
                          else if (widget.item.isSeries)
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
                                          color: tokens.primaryAccent
                                              .withValues(alpha: 0.6),
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
                  if (widget.item.year != null ||
                      widget.item.genre != null ||
                      widget.item.effectiveLanguageTag != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1.5),
                      child: Text(
                        [
                          widget.item.year,
                          widget.item.genre,
                          widget.item.effectiveLanguageTag,
                        ].where((s) => s != null && s.isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTv ? 9 : 10,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
