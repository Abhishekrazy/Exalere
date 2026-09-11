import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// TV Context Menu Dialog for Series Episodes.
/// Triggered by holding the OK / Select button on a TV episode card.
/// Provides options to Resume playback, Play from start, or Mark as Watched/Unwatched.
class TvEpisodeOptionsDialog extends StatefulWidget {
  final Episode episode;
  final String title;
  final int resumePositionSeconds;
  final bool isWatched;
  final VoidCallback? onResume;
  final VoidCallback onPlayFromStart;
  final VoidCallback onToggleWatched;

  const TvEpisodeOptionsDialog({
    super.key,
    required this.episode,
    required this.title,
    required this.resumePositionSeconds,
    required this.isWatched,
    this.onResume,
    required this.onPlayFromStart,
    required this.onToggleWatched,
  });

  static Future<void> show(
    BuildContext context, {
    required Episode episode,
    required String title,
    required int resumePositionSeconds,
    required bool isWatched,
    VoidCallback? onResume,
    required VoidCallback onPlayFromStart,
    required VoidCallback onToggleWatched,
  }) {
    return showDialog(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.65),
      builder: (_) => TvEpisodeOptionsDialog(
        episode: episode,
        title: title,
        resumePositionSeconds: resumePositionSeconds,
        isWatched: isWatched,
        onResume: onResume,
        onPlayFromStart: onPlayFromStart,
        onToggleWatched: onToggleWatched,
      ),
    );
  }

  @override
  State<TvEpisodeOptionsDialog> createState() => _TvEpisodeOptionsDialogState();
}

class _TvEpisodeOptionsDialogState extends State<TvEpisodeOptionsDialog> {
  final FocusNode _resumeFocusNode = FocusNode(debugLabel: 'TvEpResumeBtn');
  final FocusNode _playStartFocusNode = FocusNode(
    debugLabel: 'TvEpPlayStartBtn',
  );
  final FocusNode _watchedFocusNode = FocusNode(debugLabel: 'TvEpWatchedBtn');

  late final DateTime _openedAt;
  bool _keyReleased = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  @override
  void dispose() {
    _resumeFocusNode.dispose();
    _playStartFocusNode.dispose();
    _watchedFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final hasResume =
        widget.resumePositionSeconds > 15 && widget.onResume != null;

    final resumeMin = (widget.resumePositionSeconds / 60).floor();
    final resumeSec = widget.resumePositionSeconds % 60;
    final resumeLabel = 'Resume (${resumeMin}m ${resumeSec}s)';

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius,
            side: BorderSide(color: tokens.borderSubtle, width: 1.5),
            shadows: tokens.getCardShadows(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Season / Episode & Episode Title
              Text(
                'Season ${widget.episode.season}, Episode ${widget.episode.episode}',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Container(
                height: 1,
                color: tokens.borderSubtle,
                margin: const EdgeInsets.only(bottom: 14),
              ),

              // 1. Resume Option (if in progress)
              if (hasResume) ...[
                _buildActionTile(
                  context,
                  focusNode: _resumeFocusNode,
                  autofocus: true,
                  icon: Icons.play_arrow_rounded,
                  label: resumeLabel,
                  isAccent: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onResume!();
                  },
                ),
                const SizedBox(height: 8),
              ],

              // 2. Play from Start
              _buildActionTile(
                context,
                focusNode: _playStartFocusNode,
                autofocus: !hasResume,
                icon: Icons.replay_rounded,
                label: 'Play from Start',
                isAccent: !hasResume,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onPlayFromStart();
                },
              ),

              const SizedBox(height: 8),

              // 3. Mark as Watched / Unwatched
              _buildActionTile(
                context,
                focusNode: _watchedFocusNode,
                icon: widget.isWatched
                    ? Icons.remove_done_rounded
                    : Icons.done_all_rounded,
                label: widget.isWatched
                    ? 'Mark as Unwatched'
                    : 'Mark as Watched',
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onToggleWatched();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool autofocus = false,
    bool isAccent = false,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final focusedColor = isAccent
        ? theme.colorScheme.primary
        : tokens.textPrimary;

    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      scaleFactor: 1.03,
      shape: tokens.shapeSm,
      borderRadius: tokens.borderRadiusSm,
      focusedBorderColor: focusedColor,
      onKeyEvent: (node, event) {
        final isSelectKey =
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;

        if (isSelectKey) {
          final elapsed = DateTime.now().difference(_openedAt);
          if (!_keyReleased) {
            if (event is KeyUpEvent ||
                elapsed > const Duration(milliseconds: 400)) {
              _keyReleased = true;
            }
            return KeyEventResult.handled;
          }
          if (elapsed < const Duration(milliseconds: 300)) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceCard,
          radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isAccent
                  ? theme.colorScheme.primary
                  : tokens.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
