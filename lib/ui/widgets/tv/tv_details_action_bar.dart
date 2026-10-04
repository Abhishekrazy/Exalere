import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/plugin_provider.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// Primary action bar for Android TV details screen.
/// Includes the primary Play / Resume button, My List toggle, and Trailer launcher.
///
/// [onDownFocus] is called when the user presses D-Pad Down from any button in
/// this bar. The parent screen uses this to explicitly move focus to the first
/// episode card or season selector, bypassing lazy-list rendering issues.
/// Return [true] from [onDownFocus] if the focus was handled.
class TvDetailsActionBar extends StatefulWidget {
  final FocusNode playButtonFocusNode;
  final String playButtonLabel;
  final VoidCallback onPlay;
  final bool hasResume;
  final VoidCallback? onRestart;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String? trailerYoutubeKey;
  final VoidCallback? onOpenTrailer;
  final bool inContinueWatching;
  final VoidCallback? onRemoveFromContinueWatching;
  final bool isAlreadyWatched;
  final VoidCallback? onToggleAlreadyWatched;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onOpenPlugins;
  final VoidCallback? onDownload;

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
    this.inContinueWatching = false,
    this.onRemoveFromContinueWatching,
    this.isAlreadyWatched = false,
    this.onToggleAlreadyWatched,
    this.onAddToPlaylist,
    this.onOpenPlugins,
    this.onDownload,
    this.onDownFocus,
    this.onUpFocus,
  });

  @override
  State<TvDetailsActionBar> createState() => _TvDetailsActionBarState();
}

class _TvDetailsActionBarState extends State<TvDetailsActionBar> {
  final List<FocusNode> _extraNodes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _extraNodes) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getNode(int index) {
    if (index == 0) return widget.playButtonFocusNode;
    final extraIdx = index - 1;
    while (_extraNodes.length <= extraIdx) {
      _extraNodes.add(
        FocusNode(debugLabel: 'tvActionBarBtn_${_extraNodes.length + 1}'),
      );
    }
    return _extraNodes[extraIdx];
  }

  FocusOnKeyEventCallback _keyHandler(int index, int totalButtons) {
    return (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      // Intercept D-Pad Down — let the parent explicitly move focus to row below.
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          widget.onDownFocus != null) {
        final handled = widget.onDownFocus!();
        if (handled) return KeyEventResult.handled;
      }

      // Intercept D-Pad Up — let the parent explicitly move focus to row above.
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          widget.onUpFocus != null) {
        final handled = widget.onUpFocus!();
        if (handled) return KeyEventResult.handled;
      }

      // Explicit deterministic Right traversal
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (index < totalButtons - 1) {
          final nextNode = _getNode(index + 1);
          nextNode.requestFocus();
          if (nextNode.context != null && nextNode.context!.mounted) {
            Scrollable.ensureVisible(
              nextNode.context!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      // Explicit deterministic Left traversal
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (index > 0) {
          final prevNode = _getNode(index - 1);
          prevNode.requestFocus();
          if (prevNode.context != null && prevNode.context!.mounted) {
            Scrollable.ensureVisible(
              prevNode.context!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final hasTrailer =
        widget.trailerYoutubeKey != null &&
        widget.trailerYoutubeKey!.isNotEmpty;
    final hasActivePlugins = context.watch<PluginProvider>().hasActivePlugins;
    final hasRemove =
        widget.inContinueWatching &&
        widget.onRemoveFromContinueWatching != null;
    final hasWatched = widget.onToggleAlreadyWatched != null;

    final buttonBuilders = <Widget Function(int index, int total)>[];

    if (hasActivePlugins) {
      // 1. Primary Play / Resume Button
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          autofocus: true,
          focusedBorderColor: tokens.textPrimary,
          focusedShadowColor: tokens.textPrimary.withValues(alpha: 0.65),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onPlay,
          onKeyEvent: _keyHandler(index, total),
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
                  widget.playButtonLabel,
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
      );

      // 1b. Restart Button (Shown when watch progress exists)
      if (widget.hasResume && widget.onRestart != null) {
        buttonBuilders.add(
          (index, total) => TvFocusable(
            focusNode: _getNode(index),
            scaleFactor: 1.08,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: widget.onRestart,
            onKeyEvent: _keyHandler(index, total),
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
        );
      }
    } else {
      // 1. Install Plugins Button
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          autofocus: true,
          focusedBorderColor: tokens.textPrimary,
          focusedShadowColor: tokens.textPrimary.withValues(alpha: 0.65),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onOpenPlugins,
          onKeyEvent: _keyHandler(index, total),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
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
                  Icons.extension_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Install Plugins',
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
      );
    }

    // 2. Unified Playlist / My List Button
    final playlistAction = widget.onAddToPlaylist ?? widget.onToggleFavorite;
    buttonBuilders.add(
      (index, total) => TvFocusable(
        focusNode: _getNode(index),
        scaleFactor: 1.08,
        shape: tokens.shapeSm,
        borderRadius: tokens.borderRadiusSm,
        onTap: playlistAction,
        onKeyEvent: _keyHandler(index, total),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated.withValues(alpha: 0.55),
            radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
            side: BorderSide(
              color: widget.isFavorite
                  ? tokens.primaryAccent
                  : tokens.borderSubtle,
              width: widget.isFavorite ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isFavorite
                    ? Icons.playlist_add_check_rounded
                    : Icons.playlist_add_rounded,
                color: widget.isFavorite
                    ? tokens.primaryAccent
                    : tokens.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                widget.isFavorite ? 'In Playlist' : 'Playlist',
                style: TextStyle(
                  color: widget.isFavorite
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
    );

    // 3. Mark Already Watched Button
    if (hasWatched) {
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onToggleAlreadyWatched,
          onKeyEvent: _keyHandler(index, total),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: tokens.getShapeDecoration(
              color: widget.isAlreadyWatched
                  ? tokens.liveColor.withValues(alpha: 0.18)
                  : tokens.surfaceElevated.withValues(alpha: 0.55),
              radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
              side: BorderSide(
                color: widget.isAlreadyWatched
                    ? tokens.liveColor.withValues(alpha: 0.8)
                    : tokens.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isAlreadyWatched
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: widget.isAlreadyWatched
                      ? tokens.liveColor
                      : tokens.textPrimary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isAlreadyWatched ? 'Watched' : 'Mark Watched',
                  style: TextStyle(
                    color: widget.isAlreadyWatched
                        ? tokens.liveColor
                        : tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. Download Button
    if (widget.onDownload != null) {
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onDownload,
          onKeyEvent: _keyHandler(index, total),
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
                  Icons.download_rounded,
                  color: tokens.textPrimary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Download',
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
      );
    }

    // 5. Remove from Continue Watching
    if (hasRemove) {
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onRemoveFromContinueWatching,
          onKeyEvent: _keyHandler(index, total),
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
                  Icons.delete_outline_rounded,
                  color: tokens.textSecondary,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Text(
                  'Remove from Watching',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 6. Trailer Button (if available)
    if (hasTrailer) {
      buttonBuilders.add(
        (index, total) => TvFocusable(
          focusNode: _getNode(index),
          scaleFactor: 1.08,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: widget.onOpenTrailer,
          onKeyEvent: _keyHandler(index, total),
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
                Icon(Icons.movie_outlined, color: tokens.textPrimary, size: 17),
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
      );
    }

    final total = buttonBuilders.length;
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (int i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            buttonBuilders[i](i, total),
          ],
        ],
      ),
    );
  }
}
