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
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String? trailerYoutubeKey;
  final VoidCallback? onOpenTrailer;

  /// Called when D-Pad Down is pressed from any action button.
  /// Return true to consume the event (prevents spatial nav fallback).
  final bool Function()? onDownFocus;

  const TvDetailsActionBar({
    super.key,
    required this.playButtonFocusNode,
    required this.playButtonLabel,
    required this.onPlay,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.trailerYoutubeKey,
    this.onOpenTrailer,
    this.onDownFocus,
  });

  /// Builds a key-event handler that intercepts D-Pad Down to call [onDownFocus]
  /// before falling back to [TvSpatialNavigation] for all other directions.
  FocusOnKeyEventCallback _keyHandler() {
    return (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      // Intercept D-Pad Down — let the parent explicitly move focus.
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          onDownFocus != null) {
        final handled = onDownFocus!();
        if (handled) return KeyEventResult.handled;
      }

      // All other directional keys: spatial navigation handles them.
      return TvSpatialNavigation.handleKeyEvent(node, event);
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final handler = _keyHandler();

    return Row(
      children: [
        // 1. Primary Play / Resume Button (Autofocused!)
        TvFocusable(
          focusNode: playButtonFocusNode,
          autofocus: true,
          focusedBorderColor: tokens.textPrimary,
          focusedShadowColor: tokens.textPrimary.withValues(alpha: 0.65),
          scaleFactor: 1.08,
          borderRadius: tokens.borderRadiusSm,
          onTap: onPlay,
          onKeyEvent: handler,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: tokens.primaryAccent,
              borderRadius: tokens.borderRadiusSm,
              boxShadow: [
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

        const SizedBox(width: 10),

        // 2. Add / Remove from My List
        TvFocusable(
          scaleFactor: 1.08,
          borderRadius: tokens.borderRadiusSm,
          onTap: onToggleFavorite,
          onKeyEvent: handler,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.55),
              borderRadius: tokens.borderRadiusSm,
              border: Border.all(color: tokens.borderSubtle, width: 0.8),
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
        if (trailerYoutubeKey != null && trailerYoutubeKey!.isNotEmpty) ...[
          const SizedBox(width: 10),
          TvFocusable(
            scaleFactor: 1.08,
            borderRadius: tokens.borderRadiusSm,
            onTap: onOpenTrailer,
            onKeyEvent: handler,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated.withValues(alpha: 0.55),
                borderRadius: tokens.borderRadiusSm,
                border: Border.all(color: tokens.borderSubtle, width: 0.8),
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
