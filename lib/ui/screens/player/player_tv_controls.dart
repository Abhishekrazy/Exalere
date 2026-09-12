import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Full TV Leanback Controls for Android TV / D-Pad driven navigation.
class PlayerTvControls extends StatelessWidget {
  final Player player;
  final MediaItem mediaItem;
  final int? currentSeason;
  final int? currentEpisode;
  final StreamSource activeSource;
  final int sourcesCount;
  final int currentSourceIndex;
  final BoxFit videoFit;
  final FocusNode tvBackBtnFocusNode;
  final FocusNode seekbarTvFocusNode;
  final FocusNode playPauseTvFocusNode;
  final VoidCallback onBack;
  final VoidCallback onSelectServer;
  final VoidCallback onOpenAudioAndSubtitles;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback onStartHideTimer;
  final String Function(Duration) formatDuration;

  const PlayerTvControls({
    super.key,
    required this.player,
    required this.mediaItem,
    this.currentSeason,
    this.currentEpisode,
    required this.activeSource,
    required this.sourcesCount,
    required this.currentSourceIndex,
    required this.videoFit,
    required this.tvBackBtnFocusNode,
    required this.seekbarTvFocusNode,
    required this.playPauseTvFocusNode,
    required this.onBack,
    required this.onSelectServer,
    required this.onOpenAudioAndSubtitles,
    required this.onToggleAspectRatio,
    required this.onStartHideTimer,
    required this.formatDuration,
  });

  Duration _clampDuration(Duration val, Duration min, Duration max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Top Bar: Back, Title, Season/Episode, Quality Badge
          _buildTvTopBar(context, theme, tokens),

          // 2. Bottom Controls: Focusable TV Seekbar + TV Action Buttons Row
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTvSeekbar(context, theme, tokens),
              const SizedBox(height: 16),
              _buildTvActionButtons(context, theme, tokens),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTvTopBar(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
  ) {
    return Row(
      children: [
        TvFocusable(
          focusNode: tvBackBtnFocusNode,
          scaleFactor: 1.1,
          shape: tokens.shapePill,
          borderRadius: tokens.borderRadiusPill,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.6),
              radius: tokens.cardRadius * 2,
              side: BorderSide(color: tokens.borderSubtle),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: tokens.textPrimary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mediaItem.cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (currentSeason != null && currentEpisode != null)
                Text(
                  'Season $currentSeason • Episode $currentEpisode',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: tokens.getShapeDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            radius: tokens.cardRadius * 0.5,
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Text(
            activeSource.quality.toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTvSeekbar(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
  ) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? player.state.position;
        final duration = player.state.duration;
        final maxMs = duration.inMilliseconds.toDouble();
        final curMs = position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs > 0 ? maxMs : 1.0,
        );

        return Focus(
          focusNode: seekbarTvFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              final cur = player.state.position;
              final target = _clampDuration(
                cur - const Duration(seconds: 10),
                Duration.zero,
                player.state.duration,
              );
              player.seek(target);
              onStartHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              final cur = player.state.position;
              final target = _clampDuration(
                cur + const Duration(seconds: 10),
                Duration.zero,
                player.state.duration,
              );
              player.seek(target);
              onStartHideTimer();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              playPauseTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              tvBackBtnFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              player.playOrPause();
              onStartHideTimer();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedBuilder(
            animation: seekbarTvFocusNode,
            builder: (context, _) {
              final isFocused = seekbarTvFocusNode.hasFocus;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: tokens.getShapeDecoration(
                  radius: tokens.cardRadius * 0.7,
                  side: BorderSide(
                    color: isFocused
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                  shadows: isFocused
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      formatDuration(position),
                      style: TextStyle(
                        color: isFocused
                            ? theme.colorScheme.primary
                            : tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: isFocused ? 6 : 4,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: isFocused ? 9 : 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: tokens.borderSubtle.withValues(
                            alpha: 0.5,
                          ),
                          thumbColor: isFocused
                              ? tokens.textPrimary
                              : theme.colorScheme.primary,
                        ),
                        child: Slider(
                          value: curMs,
                          min: 0.0,
                          max: maxMs > 0 ? maxMs : 1.0,
                          onChanged: (val) {
                            player.seek(Duration(milliseconds: val.toInt()));
                            onStartHideTimer();
                          },
                        ),
                      ),
                    ),
                    Text(
                      duration > Duration.zero
                          ? formatDuration(duration)
                          : '00:00',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTvActionButtons(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 1. Play / Pause
        TvFocusable(
          focusNode: playPauseTvFocusNode,
          autofocus: true,
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            player.playOrPause();
            onStartHideTimer();
          },
          child: StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? player.state.playing;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceCard.withValues(alpha: 0.5),
                  radius: tokens.cardRadius * 0.7,
                  side: BorderSide(color: tokens.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: tokens.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPlaying ? 'Pause' : 'Play',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 14),

        // 2. Episodes (TV Series only)
        if (mediaItem.isSeries) ...[
          TvFocusable(
            scaleFactor: 1.12,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceCard.withValues(alpha: 0.5),
                radius: tokens.cardRadius * 0.7,
                side: BorderSide(color: tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_library_rounded,
                    color: tokens.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Episodes',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // 3. Audio & Dubs
        TvFocusable(
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: () {
            onStartHideTimer();
            onOpenAudioAndSubtitles();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius * 0.7,
              side: BorderSide(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.audiotrack_rounded,
                  color: tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Audio',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 4. Subtitles
        TvFocusable(
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: () {
            onStartHideTimer();
            onOpenAudioAndSubtitles();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius * 0.7,
              side: BorderSide(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.subtitles_rounded,
                  color: tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Subs',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // 5. Server Switcher
        if (sourcesCount > 1) ...[
          TvFocusable(
            scaleFactor: 1.12,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              onStartHideTimer();
              onSelectServer();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceCard.withValues(alpha: 0.5),
                radius: tokens.cardRadius * 0.7,
                side: BorderSide(color: tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dns_rounded, color: tokens.textPrimary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Server ${currentSourceIndex + 1}',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],

        // 6. Fit / Cover toggle
        TvFocusable(
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onTap: () {
            onToggleAspectRatio();
            onStartHideTimer();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: tokens.getShapeDecoration(
              color: videoFit == BoxFit.cover
                  ? theme.colorScheme.tertiary.withValues(alpha: 0.2)
                  : tokens.surfaceCard.withValues(alpha: 0.5),
              radius: tokens.cardRadius * 0.7,
              side: BorderSide(
                color: videoFit == BoxFit.cover
                    ? theme.colorScheme.tertiary.withValues(alpha: 0.7)
                    : tokens.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  videoFit == BoxFit.cover
                      ? Icons.fit_screen_rounded
                      : Icons.aspect_ratio_rounded,
                  color: videoFit == BoxFit.cover
                      ? theme.colorScheme.tertiary
                      : tokens.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  videoFit == BoxFit.cover ? 'Cover' : 'Fit',
                  style: TextStyle(
                    color: videoFit == BoxFit.cover
                        ? theme.colorScheme.tertiary
                        : tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
