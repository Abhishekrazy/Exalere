import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';
import '../tv_spatial_navigation.dart';

/// Primary action bar for Android TV details screen.
/// Includes the primary Play / Resume button, My List toggle, and Trailer launcher.
///
/// [onDownFocus] is called when the user presses D-Pad Down from any button in
/// this bar. The parent screen uses this to explicitly move focus to the first
/// episode card or season selector, bypassing lazy-list rendering issues.
/// Return [true] from [onDownFocus] if the focus was handled.
class TvDetailsActionBar extends StatelessWidget {
  final FocusNode playButtonFocusNode;
  final String playButtonLabel;
  final VoidCallback onPlay;
  final bool hasResume;
  final VoidCallback? onRestart;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String? trailerYoutubeKey;
  final VoidCallback? onOpenTrailer;

  /// Called when D-Pad Down is pressed from any action button.
  /// Return true to consume the event (prevents spatial nav fallback).
  final bool Function()? onDownFocus;

  /// Called when D-Pad Up is pressed from any action button.
  final bool Function()? onUpFocus;

  const TvDetailsActionBar({
    super.key,
    required this.playButtonFocusNode,
    required this.playButtonLabel,
    required this.onPlay,
    this.hasResume = false,
    this.onRestart,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.trailerYoutubeKey,
    this.onOpenTrailer,
    this.onDownFocus,
    this.onUpFocus,
  });

  /// Builds a key-event handler that intercepts D-Pad Down/Up to call row callbacks
  /// before falling back to [TvSpatialNavigation] for horizontal traversal.
  FocusOnKeyEventCallback _keyHandler({
    bool isFirst = false,
    bool isLast = false,
  }) {
    return (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      // Intercept D-Pad Down — let the parent explicitly move focus to row below.
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          onDownFocus != null) {
        final handled = onDownFocus!();
        if (handled) return KeyEventResult.handled;
      }

      // Intercept D-Pad Up — let the parent explicitly move focus to row above.
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && onUpFocus != null) {
        final handled = onUpFocus!();
        if (handled) return KeyEventResult.handled;
      }

      if (isFirst && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        return KeyEventResult.handled;
      }

      if (isLast && event.logicalKey == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.handled;
      }

      // All other directional keys: spatial navigation handles them within this row.
      return TvSpatialNavigation.handleKeyEvent(node, event);
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final hasTrailer =
        trailerYoutubeKey != null && trailerYoutubeKey!.isNotEmpty;

    return Row(
      children: [
        // 1. Primary Play / Resume Button (Autofocused!)
        TvFocusable(
          focusNode: playButtonFocusNode,
          autofocus: true,
          focusedBorderColor: tokens.textPrimary,
          focusedShadowColor: tokens.textPrimary.withValues(alpha: 0.65),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: onPlay,
          onKeyEvent: _keyHandler(isFirst: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: tokens.getShapeDecoration(
              color: tokens.primaryAccent,
              radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
              shadows: [
                BoxShadow(
                  color: tokens.primaryAccent.withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  playButtonLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 1b. Restart Button (Shown when watch progress exists)
        if (hasResume && onRestart != null) ...[
          const SizedBox(width: 10),
          TvFocusable(
            scaleFactor: 1.08,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: onRestart,
            onKeyEvent: _keyHandler(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceElevated.withValues(alpha: 0.55),
                radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                side: BorderSide(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.replay_rounded,
                    color: tokens.textPrimary,
                    size: 19,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Restart',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(width: 10),

        // 2. Add / Remove from My List
        TvFocusable(
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: onToggleFavorite,
          onKeyEvent: _keyHandler(isLast: !hasTrailer),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.55),
              radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
              side: BorderSide(color: tokens.borderSubtle, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFavorite ? Icons.check_rounded : Icons.add_rounded,
                  color: isFavorite ? tokens.primaryAccent : tokens.textPrimary,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Text(
                  isFavorite ? 'In My List' : 'My List',
                  style: TextStyle(
                    color: isFavorite
                        ? tokens.primaryAccent
                        : tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Trailer Button (if available)
        if (hasTrailer) ...[
          const SizedBox(width: 10),
          TvFocusable(
            scaleFactor: 1.08,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: onOpenTrailer,
            onKeyEvent: _keyHandler(isLast: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceElevated.withValues(alpha: 0.55),
                radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                side: BorderSide(color: tokens.borderSubtle, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.movie_outlined,
                    color: tokens.textPrimary,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Trailer',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
