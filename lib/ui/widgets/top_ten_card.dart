import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dpad/dpad.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../theme/app_tokens.dart';

class TopTenCard extends StatefulWidget {
  final MediaItem item;
  final int rank;
  final VoidCallback onTap;
  final double width;
  final double height;

  const TopTenCard({
    super.key,
    required this.item,
    required this.rank,
    required this.onTap,
    this.width = 140,
    this.height = 200,
    this.heroTag,
    this.isLastCard = false,
  });

  final String? heroTag;
  final bool isLastCard;

  @override
  State<TopTenCard> createState() => _TopTenCardState();
}

class _TopTenCardState extends State<TopTenCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberString = '${widget.rank}';
    final isActive = _isHovered || _isFocused;

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    final isTwoDigit = widget.rank >= 10;
    final cardWidth = isTv ? 115.0 : widget.width;
    final cardHeight = isTv ? 168.0 : widget.height;
    final numFontSize = isTv ? 78.0 : 104.0;
    final offsetLeft = isTv
        ? (isTwoDigit ? 56.0 : 34.0)
        : (isTwoDigit ? 70.0 : 42.0);
    final numLetterSpacing = isTv
        ? (isTwoDigit ? -9.0 : -4.0)
        : (isTwoDigit ? -12.0 : -6.0);

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
          final isCardActive = isFocused || _isHovered;
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
          child: Container(
            width: cardWidth + offsetLeft,
            height: cardHeight,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                // Giant Stylized 3D Rank Number
                Positioned(
                  left: 0,
                  bottom: 4,
                  child: Stack(
                    children: [
                      // Outer Glow / Stroke
                      Text(
                        numberString,
                        style: TextStyle(
                          fontSize: numFontSize,
                          fontWeight: FontWeight.w900,
                          height: 0.9,
                          letterSpacing: numLetterSpacing,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = isTv ? 3.5 : 5
                            ..color = tokens.textPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      // Dark 3D Drop Shadow
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Text(
                          numberString,
                          style: TextStyle(
                            fontSize: numFontSize,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                            letterSpacing: numLetterSpacing,
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                      // Foreground Number with subtle gradient fill
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            tokens.textPrimary.withValues(alpha: 0.95),
                            tokens.textMuted,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          numberString,
                          style: TextStyle(
                            fontSize: numFontSize,
                            fontWeight: FontWeight.w900,
                            height: 0.9,
                            letterSpacing: numLetterSpacing,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Poster Card (Overlaps the right half of the number)
                Container(
                  width: cardWidth,
                  height: cardHeight,
                  margin: EdgeInsets.only(left: offsetLeft),
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
                                alpha: 0.45,
                              ),
                              blurRadius: 16,
                              offset: const Offset(4, 4),
                            ),
                          ]
                        : tokens.getCardShadows(),
                  ),
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
                                            fit: BoxFit.cover,
                                            memCacheWidth: isTv ? 180 : 320,
                                            memCacheHeight: isTv ? 260 : 460,
                                            maxWidthDiskCache: isTv ? 300 : 500,
                                            fadeInDuration: Duration.zero,
                                            fadeOutDuration: Duration.zero,
                                            placeholder: (context, url) => Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
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
                                        fit: BoxFit.cover,
                                        memCacheWidth: isTv ? 180 : 320,
                                        memCacheHeight: isTv ? 260 : 460,
                                        maxWidthDiskCache: isTv ? 300 : 500,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholder: (context, url) => Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.colorScheme.primary,
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

                        // Top 10 micro badge in card corner
                        Positioned(
                          top: 6,
                          right: 6,
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
                              'TOP 10',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),

                        // Rating if available
                        if (widget.item.rating != null &&
                            widget.item.rating! > 0)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                color: tokens.surfaceElevated.withValues(
                                  alpha: 0.85,
                                ),
                                shape: tokens.getShapeBorder(radius: 4),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
