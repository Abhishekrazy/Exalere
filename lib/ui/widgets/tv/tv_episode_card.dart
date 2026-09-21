import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// 16:9 Landscape episode card for Android TV shelves.
/// Displays episode number badge, thumbnail, progress bar, title, and synopsis.
/// Supports both short tap and long-press / hold OK on TV remote to open episode options menu.
class TvEpisodeCard extends StatefulWidget {
  final Episode episode;
  final String? thumbnailUrl;
  final String title;
  final String overview;
  final int resumePositionSeconds;
  final bool isWatched;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final FocusNode? focusNode;

  /// If true, D-Pad Right is consumed (no-op) so focus cannot leave the
  /// episode shelf at the right edge and jump to an unrelated section.
  /// Edge guards: prevent D-Pad from escaping horizontally
  final bool isLastCard;
  final bool isFirstCard;

  /// Called when D-Pad Up is pressed from this episode card.
  final bool Function()? onUp;

  /// Called when D-Pad Down is pressed from this episode card.
  final bool Function()? onDown;

  const TvEpisodeCard({
    super.key,
    required this.episode,
    required this.thumbnailUrl,
    required this.title,
    required this.overview,
    required this.resumePositionSeconds,
    this.isWatched = false,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.focusNode,
    this.isLastCard = false,
    this.isFirstCard = false,
    this.onUp,
    this.onDown,
  });

  @override
  State<TvEpisodeCard> createState() => _TvEpisodeCardState();
}

class _TvEpisodeCardState extends State<TvEpisodeCard> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cardRadius = tokens.cornerStyle == CornerStyle.sharp
        ? 0.0
        : tokens.cardRadius;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
    );

    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      scaleFactor: 1.06,
      shape: shapeBorder,
      borderRadius: tokens.borderRadiusSm,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
              widget.onUp != null) {
            final handled = widget.onUp!();
            if (handled) return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
              widget.onDown != null) {
            final handled = widget.onDown!();
            if (handled) return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onDirection: (direction) {
        if (widget.isLastCard && direction == TraversalDirection.right) {
          return true;
        }
        if (widget.isFirstCard && direction == TraversalDirection.left) {
          return true;
        }
        if (direction == TraversalDirection.up && widget.onUp != null) {
          return widget.onUp!();
        }
        if (direction == TraversalDirection.down && widget.onDown != null) {
          return widget.onDown!();
        }
        return false;
      },
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        child: Container(
          width: 180,
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceCard,
            radius: cardRadius,
            side: BorderSide(color: tokens.borderSubtle, width: 0.8),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shapeBorder),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact 16:9 Thumbnail Still
                SizedBox(
                  height: 75,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.thumbnailUrl != null &&
                          widget.thumbnailUrl!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.thumbnailUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 260,
                          memCacheHeight: 150,
                          maxWidthDiskCache: 350,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, _) => Container(
                            color: tokens.surfaceElevated,
                            child: Icon(
                              Icons.movie_rounded,
                              size: 24,
                              color: tokens.textMuted.withValues(alpha: 0.3),
                            ),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: tokens.surfaceElevated,
                            child: Icon(
                              Icons.movie_rounded,
                              size: 24,
                              color: tokens.textMuted,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: tokens.surfaceElevated,
                          child: Icon(
                            Icons.movie_rounded,
                            size: 24,
                            color: tokens.textMuted,
                          ),
                        ),

                      // Episode Number Badge
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceElevated.withValues(
                              alpha: 0.85,
                            ),
                            radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                            side: BorderSide(
                              color: tokens.borderSubtle,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            'E${widget.episode.episode}',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 8.0,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      // Watched badge (if watched)
                      if (widget.isWatched)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: tokens.surfaceElevated.withValues(
                                alpha: 0.85,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tokens.primaryAccent,
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 9,
                              color: tokens.primaryAccent,
                            ),
                          ),
                        ),

                      // Play Center Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.65,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.borderSubtle,
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: tokens.textPrimary,
                            size: 15,
                          ),
                        ),
                      ),

                      // Resume progress bar (if watched)
                      if (widget.resumePositionSeconds > 15)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: 0.5,
                            minHeight: 2.0,
                            backgroundColor: tokens.surfaceElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tokens.primaryAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Title & Synopsis Snippet
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.episode.episode}. ${widget.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.0,
                        ),
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        widget.overview.isNotEmpty
                            ? widget.overview
                            : 'Episode ${widget.episode.episode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 8.5,
                          height: 1.15,
                        ),
                      ),
                    ],
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
