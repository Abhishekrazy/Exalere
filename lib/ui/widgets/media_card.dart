import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  });

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
    final is4K =
        widget.item.provider == ProviderType.fourKHdHub ||
        widget.item.title.contains('4K') ||
        (widget.item.year?.contains('4K') ?? false);

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
    final cardWidth = (isTv ? 115.0 : widget.width) * scaleMultiplier;
    final cardHeight = (isTv ? 168.0 : widget.height) * scaleMultiplier;

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
      child: AnimatedScale(
        scale: isActive ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Focus(
          canRequestFocus: true,
          onFocusChange: (focused) {
            setState(() => _isFocused = focused);
            if (focused) {
              Scrollable.ensureVisible(
                context,
                alignment: 0.5,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonA) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            canRequestFocus: false,
            onTap: widget.onTap,
            borderRadius: tokens.borderRadiusSm,
            child: Container(
              width: cardWidth,
              margin: EdgeInsets.symmetric(
                horizontal: isTv ? 4 : 6,
                vertical: 4,
              ),
              child: Column(
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
                                            child: ClipRRect(
                                              borderRadius:
                                                  tokens.borderRadiusSm,
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    widget.item.posterUrl!,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 320,
                                                memCacheHeight: 460,
                                                maxWidthDiskCache: 500,
                                                fadeInDuration: Duration.zero,
                                                fadeOutDuration: Duration.zero,
                                                placeholder: (context, url) =>
                                                    Center(
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
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Center(
                                                      child: Icon(
                                                        Icons.movie_outlined,
                                                        size: 36,
                                                        color: tokens.textMuted,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: widget.item.posterUrl!,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 320,
                                          memCacheHeight: 460,
                                          maxWidthDiskCache: 500,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1.5,
                                  ),
                                  decoration: ShapeDecoration(
                                    color: widget.item.isCam
                                        ? tokens.vipColor.withValues(
                                            alpha: 0.18,
                                          )
                                        : tokens.surfaceElevated.withValues(
                                            alpha: 0.85,
                                          ),
                                    shape: tokens.getShapeBorder(
                                      radius: 4,
                                      side: BorderSide(
                                        color: widget.item.isCam
                                            ? tokens.vipColor.withValues(
                                                alpha: 0.75,
                                              )
                                            : tokens.borderSubtle,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    widget.item.isCam
                                        ? (widget.item.qualityTag ?? 'CAM')
                                        : (is4K ? '4K UHD' : 'HD'),
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: widget.item.isCam
                                          ? tokens.vipColor
                                          : tokens.textSecondary,
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
                  const SizedBox(height: 6),

                  // Media Title
                  Text(
                    widget.item.cleanTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isTv ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),

                  // Subtitle: Year • Genre • Language
                  if (widget.item.year != null ||
                      widget.item.genre != null ||
                      widget.item.effectiveLanguageTag != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
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
