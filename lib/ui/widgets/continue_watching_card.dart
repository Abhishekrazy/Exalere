import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dpad/dpad.dart';

import '../../providers/app_provider.dart';
import '../../services/storage_service.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_continue_watching_dialog.dart';

class ContinueWatchingCard extends StatefulWidget {
  final WatchHistoryItem historyItem;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  final VoidCallback? onMarkWatched;
  final double width;
  final double height;
  final FocusNode? focusNode;
  final bool isLastCard;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    required this.onTap,
    this.onPlay,
    this.onRemove,
    this.onMarkWatched,
    this.width = 220,
    this.height = 140,
    this.focusNode,
    this.isLastCard = false,
  });

  @override
  State<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends State<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  void _triggerContextMenu(BuildContext context) {
    TvContinueWatchingDialog.show(
      context,
      historyItem: widget.historyItem,
      onTap: widget.onTap,
      onPlay: widget.onPlay,
      onRemove: widget.onRemove,
    );
  }

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
        focusNode: widget.focusNode,
        tapToSelect: false,
        onSelect: () {
          if (widget.onPlay != null) {
            widget.onPlay!();
          } else {
            widget.onTap();
          }
        },
        onLongSelect: () => _triggerContextMenu(context),
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
            scale: state.pressed ? 0.98 : (isCardActive ? 1.05 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Container(
              width: cardWidth,
              height: cardHeight,
              margin: EdgeInsets.only(right: isTv ? 10 : 12, top: 4, bottom: 4),
              decoration: tokens.getShapeDecoration(
                color: theme.colorScheme.surface,
                radius: cardRadius,
                side: BorderSide(
                  color: isCardActive
                      ? theme.colorScheme.primary
                      : tokens.borderSubtle,
                  width: isCardActive ? 2.0 : 1.0,
                ),
                shadows: isCardActive
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                          blurRadius: 14,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : tokens.getCardShadows(),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shapeBorder),
                child: child,
              ),
            ),
          );
        },
        child: InkWell(
          canRequestFocus: false,
          onTap: widget.onTap,
          onLongPress: () => _triggerContextMenu(context),
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
                          color: tokens.surfaceCard,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: tokens.surfaceCard,
                          child: Icon(
                            Icons.movie,
                            color: tokens.textMuted,
                            size: 36,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: tokens.surfaceCard,
                        child: Icon(
                          Icons.movie,
                          color: tokens.textMuted,
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
                            tokens.canvasBackground.withValues(alpha: 0.1),
                            tokens.canvasBackground.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),

                    // Center Play Button Circle (Direct Play Trigger)
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (widget.onPlay != null) {
                              widget.onPlay!();
                            } else {
                              widget.onTap();
                            }
                          },
                          borderRadius: tokens.borderRadiusPill,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tokens.canvasBackground.withValues(
                                alpha: 0.75,
                              ),
                              border: Border.all(
                                color: tokens.textPrimary.withValues(
                                  alpha: 0.85,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: tokens.shadowColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: tokens.textPrimary,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top Right Action Buttons (Mark as Watched, Close/Remove)
                    if (widget.onMarkWatched != null || widget.onRemove != null)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onMarkWatched != null) ...[
                              Tooltip(
                                message: 'Mark as Watched',
                                child: InkWell(
                                  onTap: widget.onMarkWatched,
                                  borderRadius: tokens.borderRadiusPill,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tokens.canvasBackground.withValues(
                                        alpha: 0.75,
                                      ),
                                      border: Border.all(
                                        color: tokens.textPrimary.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            if (widget.onRemove != null)
                              Tooltip(
                                message: 'Remove from Continue Watching',
                                child: InkWell(
                                  onTap: widget.onRemove,
                                  borderRadius: tokens.borderRadiusPill,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: tokens.canvasBackground.withValues(
                                        alpha: 0.75,
                                      ),
                                      border: Border.all(
                                        color: tokens.textPrimary.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: tokens.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                          decoration: ShapeDecoration(
                            color: tokens.surfaceElevated.withValues(
                              alpha: 0.85,
                            ),
                            shape: tokens.getShapeBorder(radius: 4),
                          ),
                          child: Text(
                            'S${widget.historyItem.season} E${widget.historyItem.episode}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tokens.textPrimary,
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
                            item.cleanTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTv ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            [
                                  if (item.effectiveLanguageTag != null &&
                                      item.effectiveLanguageTag!.isNotEmpty)
                                    item.effectiveLanguageTag,
                                  item.genre ??
                                      (item.isSeries ? 'Series' : 'Movie'),
                                ]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isTv ? 9 : 10,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.info_outline_rounded,
                      size: isTv ? 14 : 16,
                      color: tokens.textMuted,
                    ),
                  ],
                ),
              ),

              // Pinned Progress Bar at bottom
              LinearProgressIndicator(
                value: widget.historyItem.progress,
                minHeight: isTv ? 2.5 : 3,
                backgroundColor: tokens.borderSubtle,
                color: tokens.primaryAccent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
