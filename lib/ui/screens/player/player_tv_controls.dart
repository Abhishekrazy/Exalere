import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Full TV Leanback Controls for Android TV / D-Pad driven navigation.
class PlayerTvControls extends StatefulWidget {
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
  final SkipInterval? activeSkip;
  final VoidCallback? onTriggerSkip;
  final VoidCallback onBack;
  final VoidCallback onSelectServer;
  final VoidCallback onOpenAudioAndSubtitles;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback? onRestartPlayback;
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
    this.activeSkip,
    this.onTriggerSkip,
    required this.onBack,
    required this.onSelectServer,
    required this.onOpenAudioAndSubtitles,
    required this.onToggleAspectRatio,
    this.onRestartPlayback,
    required this.onStartHideTimer,
    required this.formatDuration,
  });

  @override
  State<PlayerTvControls> createState() => _PlayerTvControlsState();
}

class _PlayerTvControlsState extends State<PlayerTvControls> {
  late final FocusNode _restartTvFocusNode;
  Duration? _previewSeekPosition;
  DateTime? _lastSeekDispatchTime;
  Timer? _continuousSeekDebounceTimer;

  @override
  void initState() {
    super.initState();
    _restartTvFocusNode = FocusNode(debugLabel: 'tvRestartBtn');
  }

  @override
  void dispose() {
    _continuousSeekDebounceTimer?.cancel();
    _restartTvFocusNode.dispose();
    super.dispose();
  }

  Duration _clampDuration(Duration val, Duration min, Duration max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
  }

  void _handleRelativeSeek(int seconds) {
    widget.onStartHideTimer();
    final duration = widget.player.state.duration;
    final currentPos = _previewSeekPosition ?? widget.player.state.position;
    final target = _clampDuration(
      currentPos + Duration(seconds: seconds),
      Duration.zero,
      duration,
    );

    setState(() {
      _previewSeekPosition = target;
    });

    final now = DateTime.now();
    final shouldThrottleDispatch =
        _lastSeekDispatchTime == null ||
        now.difference(_lastSeekDispatchTime!) >
            const Duration(milliseconds: 250);

    if (shouldThrottleDispatch) {
      _lastSeekDispatchTime = now;
      widget.player.seek(target);
    }

    _continuousSeekDebounceTimer?.cancel();
    _continuousSeekDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _previewSeekPosition != null) {
        widget.player.seek(_previewSeekPosition!);
        setState(() {
          _previewSeekPosition = null;
          _lastSeekDispatchTime = null;
        });
      }
    });
  }

  void _finalizeSeek() {
    _continuousSeekDebounceTimer?.cancel();
    if (_previewSeekPosition != null) {
      widget.player.seek(_previewSeekPosition!);
      setState(() {
        _previewSeekPosition = null;
        _lastSeekDispatchTime = null;
      });
    }
    widget.onStartHideTimer();
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

          // 2. Bottom Controls: Restart above seekbar + Focusable TV Seekbar + TV Action Buttons Row
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onRestartPlayback != null) ...[
                _buildTvAboveSeekbarActions(context, theme, tokens),
                const SizedBox(height: 10),
              ],
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
          focusNode: widget.tvBackBtnFocusNode,
          scaleFactor: 1.1,
          shape: tokens.shapePill,
          borderRadius: tokens.borderRadiusPill,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (widget.onRestartPlayback != null) {
                _restartTvFocusNode.requestFocus();
              } else {
                widget.seekbarTvFocusNode.requestFocus();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: widget.onBack,
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
                widget.mediaItem.cleanTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.currentSeason != null && widget.currentEpisode != null)
                Text(
                  'Season ${widget.currentSeason} • Episode ${widget.currentEpisode}',
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
            widget.activeSource.quality.toUpperCase(),
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

  Widget _buildTvAboveSeekbarActions(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
  ) {
    return Row(
      children: [
        TvFocusable(
          focusNode: _restartTvFocusNode,
          scaleFactor: 1.1,
          shape: tokens.shapePill,
          borderRadius: tokens.borderRadiusPill,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              widget.tvBackBtnFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              widget.seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            widget.onStartHideTimer();
            widget.onRestartPlayback?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated.withValues(alpha: 0.6),
              radius: tokens.cardRadius * 1.5,
              side: BorderSide(color: tokens.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay_rounded, color: tokens.textPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Restart',
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
      ],
    );
  }

  Widget _buildTvSeekbar(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
  ) {
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, snapshot) {
        final actualPosition = snapshot.data ?? widget.player.state.position;
        final position = _previewSeekPosition ?? actualPosition;
        final duration = widget.player.state.duration;
        final maxMs = duration.inMilliseconds.toDouble();
        final curMs = position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs > 0 ? maxMs : 1.0,
        );

        return Focus(
          focusNode: widget.seekbarTvFocusNode,
          onKeyEvent: (node, event) {
            // Key release: finalize seek immediately
            if (event is KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _finalizeSeek();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA) {
                widget.player.playOrPause();
                widget.onStartHideTimer();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }

            // Key press or repeat (continuous seeking)
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _handleRelativeSeek(-10);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _handleRelativeSeek(30);
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                widget.playPauseTvFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (widget.onRestartPlayback != null) {
                  _restartTvFocusNode.requestFocus();
                } else {
                  widget.tvBackBtnFocusNode.requestFocus();
                }
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedBuilder(
            animation: widget.seekbarTvFocusNode,
            builder: (context, _) {
              final isFocused = widget.seekbarTvFocusNode.hasFocus;
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
                      widget.formatDuration(position),
                      style: TextStyle(
                        color: _previewSeekPosition != null
                            ? theme.colorScheme.primary
                            : (isFocused
                                  ? theme.colorScheme.primary
                                  : tokens.textPrimary),
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
                            widget.player.seek(
                              Duration(milliseconds: val.toInt()),
                            );
                            widget.onStartHideTimer();
                          },
                        ),
                      ),
                    ),
                    Text(
                      duration > Duration.zero
                          ? widget.formatDuration(duration)
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
    final activeSkip = widget.activeSkip;
    final mediaItem = widget.mediaItem;
    final sourcesCount = widget.sourcesCount;
    final currentSourceIndex = widget.currentSourceIndex;
    final videoFit = widget.videoFit;

    return Row(
      children: [
        // 1. Skip Intro/Outro Button OR Episodes Button
        if (activeSkip != null) ...[
          TvFocusable(
            focusNode: widget.playPauseTvFocusNode,
            scaleFactor: 1.12,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.seekbarTvFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: () {
              widget.onStartHideTimer();
              widget.onTriggerSkip?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: tokens.getShapeDecoration(
                color: theme.colorScheme.primary,
                radius: tokens.cardRadius * 0.7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fast_forward_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeSkip.label,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ] else if (mediaItem.isSeries) ...[
          TvFocusable(
            focusNode: widget.playPauseTvFocusNode,
            scaleFactor: 1.12,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.seekbarTvFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: () {
              widget.onStartHideTimer();
              Scaffold.of(context).openEndDrawer();
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

        // 2. Audio & Dubs
        TvFocusable(
          focusNode: (activeSkip == null && !mediaItem.isSeries)
              ? widget.playPauseTvFocusNode
              : null,
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              widget.seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            widget.onStartHideTimer();
            widget.onOpenAudioAndSubtitles();
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

        // 3. Subtitles
        TvFocusable(
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              widget.seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            widget.onStartHideTimer();
            widget.onOpenAudioAndSubtitles();
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

        // 4. Server Switcher
        if (sourcesCount > 1) ...[
          TvFocusable(
            scaleFactor: 1.12,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                widget.seekbarTvFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            onTap: () {
              widget.onStartHideTimer();
              widget.onSelectServer();
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

        // 5. Fit / Cover toggle
        TvFocusable(
          scaleFactor: 1.12,
          shape: tokens.shapeSm,
          borderRadius: tokens.borderRadiusSm,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              widget.seekbarTvFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onTap: () {
            widget.onToggleAspectRatio();
            widget.onStartHideTimer();
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
