import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/media_item.dart';
import '../../../services/storage_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// TV Context Menu Dialog for Continue Watching items.
/// Triggered by holding the OK / Select button on a Continue Watching card.
class TvContinueWatchingDialog extends StatefulWidget {
  final WatchHistoryItem historyItem;
  final VoidCallback? onPlay;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const TvContinueWatchingDialog({
    super.key,
    required this.historyItem,
    required this.onTap,
    this.onPlay,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required WatchHistoryItem historyItem,
    required VoidCallback onTap,
    VoidCallback? onPlay,
    VoidCallback? onRemove,
  }) {
    return showDialog(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.65),
      builder: (_) => TvContinueWatchingDialog(
        historyItem: historyItem,
        onTap: onTap,
        onPlay: onPlay,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<TvContinueWatchingDialog> createState() =>
      _TvContinueWatchingDialogState();
}

class _TvContinueWatchingDialogState extends State<TvContinueWatchingDialog> {
  final FocusNode _detailsFocusNode = FocusNode(debugLabel: 'TvCWDetailsBtn');
  final FocusNode _removeFocusNode = FocusNode(debugLabel: 'TvCWRemoveBtn');
  final FocusNode _playFocusNode = FocusNode(debugLabel: 'TvCWPlayBtn');

  late final DateTime _openedAt;
  bool _keyReleased = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
  }

  @override
  void dispose() {
    _detailsFocusNode.dispose();
    _removeFocusNode.dispose();
    _playFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final item = widget.historyItem.item;
    final isSeries = item.mediaType == MediaType.series;

    final String subtitle;
    if (isSeries && widget.historyItem.season != null) {
      subtitle =
          'Season ${widget.historyItem.season}, Episode ${widget.historyItem.episode ?? 1}';
    } else {
      subtitle = item.year ?? 'Movie';
    }

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
              // Title and Subtitle
              Text(
                item.cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Divider
              Container(
                height: 1,
                color: tokens.borderSubtle,
                margin: const EdgeInsets.only(bottom: 14),
              ),

              // 1. Play / Resume Action
              if (widget.onPlay != null)
                _buildActionTile(
                  context,
                  focusNode: _playFocusNode,
                  autofocus: true,
                  icon: Icons.play_arrow_rounded,
                  label: 'Resume Playback',
                  isAccent: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onPlay!();
                  },
                ),

              const SizedBox(height: 8),

              // 2. View Detail Page Action
              _buildActionTile(
                context,
                focusNode: _detailsFocusNode,
                autofocus: widget.onPlay == null,
                icon: Icons.info_outline_rounded,
                label: 'View Details Page',
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onTap();
                },
              ),

              const SizedBox(height: 8),

              // 3. Remove from Continue Watching Action
              if (widget.onRemove != null)
                _buildActionTile(
                  context,
                  focusNode: _removeFocusNode,
                  icon: Icons.remove_circle_outline_rounded,
                  label: 'Remove from Continue Watching',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onRemove!();
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
    bool isDestructive = false,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final focusedColor = isDestructive
        ? tokens.errorColor
        : (isAccent ? theme.colorScheme.primary : tokens.textPrimary);

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
              color: isDestructive
                  ? tokens.errorColor
                  : (isAccent
                        ? theme.colorScheme.primary
                        : tokens.textSecondary),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isDestructive ? tokens.errorColor : tokens.textPrimary,
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
