import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';
import 'player_playback_helper.dart';

/// Floating bottom-right countdown card that offers a seamless binge experience
/// when approaching the end of an episode in a TV series.
class PlayerNextEpisodeCountdownCard extends StatelessWidget {
  final Episode nextEpisode;
  final int countdownSeconds;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;
  final bool isTv;
  final bool isControlsVisible;

  const PlayerNextEpisodeCountdownCard({
    super.key,
    required this.nextEpisode,
    required this.countdownSeconds,
    required this.onPlayNow,
    required this.onCancel,
    this.isTv = false,
    this.isControlsVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    final cardWidth = isTv ? 380.0 : 340.0;
    final thumbUrl = EpisodeHelper.highResThumbnailUrl(nextEpisode.thumbnail);

    return ClipRRect(
      borderRadius: tokens.borderRadiusMd,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(14),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated.withValues(alpha: 0.94),
            radius: tokens.cardRadius * 1.5,
            side: BorderSide(
              color: tokens.borderFocus.withValues(alpha: 0.6),
              width: 1.2,
            ),
            shadows: [
              BoxShadow(
                color: tokens.shadowColor.withValues(alpha: 0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Up Next Badge + Countdown Indicator + Dismiss Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      borderRadius: tokens.borderRadiusXs,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.skip_next_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'UP NEXT IN ${countdownSeconds}s',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TvFocusable(
                    scaleFactor: 1.1,
                    shape: tokens.shapePill,
                    borderRadius: tokens.borderRadiusPill,
                    onTap: onCancel,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Episode Info Row: Thumbnail + Title / Season info
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (thumbUrl != null && thumbUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: tokens.borderRadiusSm,
                      child: Container(
                        width: 76,
                        height: 44,
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Center(
                            child: Icon(
                              Icons.movie_outlined,
                              size: 20,
                              color: tokens.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Season ${nextEpisode.season} • Episode ${nextEpisode.episode}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextEpisode.title.isNotEmpty
                              ? nextEpisode.title
                              : 'Episode ${nextEpisode.episode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Buttons Row: [Play Now (Xs)] + [Cancel]
              Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      autofocus: isTv && !isControlsVisible,
                      scaleFactor: 1.03,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: onPlayNow,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: tokens.getShapeDecoration(
                          color: theme.colorScheme.primary,
                          radius: tokens.cardRadius,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Play Now (${countdownSeconds}s)',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    scaleFactor: 1.03,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: onCancel,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceCard.withValues(alpha: 0.6),
                        radius: tokens.cardRadius,
                        side: BorderSide(color: tokens.borderSubtle, width: 1),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
