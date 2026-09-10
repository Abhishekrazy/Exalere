import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/media_item.dart';
import '../../providers/app_provider.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final double height;
  final String? customBadge;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    this.width = 140,
    this.height = 205,
    this.customBadge,
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
    final is4K = widget.item.provider == ProviderType.fourKHdHub ||
        widget.item.title.contains('4K') ||
        (widget.item.year?.contains('4K') ?? false);

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    final cardWidth = isTv ? 115.0 : widget.width;
    final cardHeight = isTv ? 168.0 : widget.height;

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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: cardWidth,
              margin: EdgeInsets.symmetric(horizontal: isTv ? 4 : 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster Image Container
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? theme.colorScheme.primary
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                        blurRadius: isActive ? 14 : 6,
                        spreadRadius: isActive ? 1 : 0,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          width: cardWidth,
                          height: cardHeight,
                          color: theme.colorScheme.surface,
                          child: widget.item.posterUrl != null && widget.item.posterUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.item.posterUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 320,
                                  memCacheHeight: 460,
                                  maxWidthDiskCache: 500,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => const Center(
                                    child: Icon(Icons.movie_outlined, size: 36, color: Colors.white38),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.movie_outlined, size: 36, color: Colors.white38),
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
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                widget.customBadge!,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else if (widget.item.isSeries)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D2FF).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'SERIES',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                        // 4K / HD Quality Pill (Bottom Left)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              is4K ? '4K UHD' : 'HD',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),

                        // Rating Badge (Top Right)
                        if (widget.item.rating != null && widget.item.rating! > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
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
                const SizedBox(height: 6),

                // Media Title
                Text(
                  widget.item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTv ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                // Subtitle: Year • Genre
                if (widget.item.year != null || widget.item.genre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [widget.item.year, widget.item.genre]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isTv ? 9 : 10,
                        color: Colors.white54,
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
