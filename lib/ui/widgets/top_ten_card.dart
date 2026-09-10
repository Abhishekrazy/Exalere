import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';

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
  });

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

    final cardWidth = isTv ? 115.0 : widget.width;
    final cardHeight = isTv ? 168.0 : widget.height;
    final numFontSize = isTv ? 78.0 : 104.0;
    final offsetLeft = isTv ? 34.0 : 42.0;

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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: cardWidth + offsetLeft,
              height: cardHeight,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Stack(
                alignment: Alignment.bottomRight,
                clipBehavior: Clip.none,
                children: [
                  // Giant Stylized 3D Rank Number (Netflix Style)
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
                            letterSpacing: isTv ? -4 : -6,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = isTv ? 3.5 : 5
                              ..color = Colors.white.withValues(alpha: 0.4),
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
                              letterSpacing: isTv ? -4 : -6,
                              color: Colors.black.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        // Foreground Number with subtle gradient fill
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.grey.shade600,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            numberString,
                            style: TextStyle(
                              fontSize: numFontSize,
                              fontWeight: FontWeight.w900,
                              height: 0.9,
                              letterSpacing: isTv ? -4 : -6,
                              color: Colors.white,
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                        width: isActive ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.45,
                                )
                              : Colors.black.withValues(alpha: 0.5),
                          blurRadius: isActive ? 16 : 10,
                          offset: const Offset(4, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            color: theme.colorScheme.surface,
                            child:
                                widget.item.posterUrl != null &&
                                    widget.item.posterUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.item.posterUrl!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 320,
                                    memCacheHeight: 460,
                                    maxWidthDiskCache: 500,
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
                                        const Center(
                                          child: Icon(
                                            Icons.movie_outlined,
                                            size: 36,
                                            color: Colors.white38,
                                          ),
                                        ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.movie_outlined,
                                      size: 36,
                                      color: Colors.white38,
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
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'TOP 10',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
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
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.item.rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
      ),
    );
  }
}
