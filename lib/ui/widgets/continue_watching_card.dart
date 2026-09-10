import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';
import '../theme/app_tokens.dart';

class ContinueWatchingCard extends StatefulWidget {
  final WatchHistoryItem historyItem;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final double width;
  final double height;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    required this.onTap,
    this.onRemove,
    this.width = 220,
    this.height = 140,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.historyItem.item;
    final imageUrl = item.backdropUrl ?? item.posterUrl;
    final isActive = _isHovered || _isFocused;

    bool isTv = false;
    try {
      isTv = context.watch<AppProvider>().isTvMode;
    } catch (_) {}

    final cardWidth = isTv ? 190.0 : widget.width;
    final cardHeight = isTv ? 122.0 : widget.height;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: isActive ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          margin: EdgeInsets.only(right: isTv ? 10 : 12, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: context.tokens.borderRadiusSm,
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
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: isActive ? 14 : 6,
                spreadRadius: isActive ? 1 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: context.tokens.borderRadiusSm,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 16:9 Thumbnail with Overlay & Play Icon
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 400,
                              memCacheHeight: 250,
                              maxWidthDiskCache: 600,
                              placeholder: (_, _) => Container(
                                color: Colors.white10,
                                child: const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: Colors.white10,
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.white24,
                                  size: 36,
                                ),
                              ),
                            )
                          else
                            Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.movie,
                                color: Colors.white24,
                                size: 36,
                              ),
                            ),

                          // Dark Vignette Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),

                          // Center Play Button Circle (Netflix Style)
                          Center(
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.65),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // Top Right Close/Remove button (if provided)
                          if (widget.onRemove != null)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Tooltip(
                                message: 'Remove from Continue Watching',
                                child: InkWell(
                                  onTap: widget.onRemove,
                                  borderRadius: context.tokens.borderRadiusPill,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black.withValues(
                                        alpha: 0.75,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Season / Episode Micro Badge
                          if (widget.historyItem.season != null &&
                              widget.historyItem.episode != null)
                            Positioned(
                              bottom: 6,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: context.tokens.borderRadiusXs,
                                ),
                                child: Text(
                                  'S${widget.historyItem.season} E${widget.historyItem.episode}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Title and Info Bottom Bar
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTv ? 8 : 10,
                        isTv ? 4 : 8,
                        isTv ? 8 : 10,
                        isTv ? 3 : 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isTv ? 11 : 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  item.genre ??
                                      (item.isSeries ? 'Series' : 'Movie'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isTv ? 9 : 10,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.info_outline_rounded,
                            size: isTv ? 14 : 16,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),

                    // Pinned Crimson / Accent Progress Bar at the absolute bottom
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(context.tokens.cardRadius - 2),
                      ),
                      child: LinearProgressIndicator(
                        value: widget.historyItem.progress,
                        minHeight: isTv ? 2.5 : 3,
                        backgroundColor: Colors.white12,
                        color: context.tokens.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
