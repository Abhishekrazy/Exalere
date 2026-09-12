import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/cast_provider.dart';
import '../../theme/app_tokens.dart';
import 'player_controls_overlay.dart';
import 'player_gesture_hud.dart';
import 'player_playback_helper.dart';
import 'player_tv_controls.dart';

/// Full interactive video surface with gestures, controls overlays, HUD, and TV navigation.
class PlayerVideoView extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final BoxFit videoFit;
  final FocusNode focusNode;
  final MediaItem mediaItem;
  final StreamSource activeSource;
  final int sourcesCount;
  final int currentSourceIndex;
  final int? currentSeason;
  final int? currentEpisode;
  final List<SubtitleOption> externalSubtitles;
  final bool showControls;
  final bool isControlsLocked;
  final bool showUnlockButton;
  final bool isLoadingVideo;
  final bool isBuffering;
  final bool isPlayerReady;
  final String? errorMessage;
  final String? toastMessage;
  final bool isOrientationLocked;
  final double brightness;
  final bool showBrightnessIndicator;
  final double volume;
  final bool showVolumeIndicator;
  final int? doubleTapSeekDirection;
  final SkipInterval? activeSkip;
  final bool showResumeBanner;
  final int resumedFromSeconds;
  final double playbackSpeed;
  final bool isFullscreen;
  final bool hasNextEpisode;
  final FocusNode tvBackBtnFocusNode;
  final FocusNode seekbarTvFocusNode;
  final FocusNode playPauseTvFocusNode;

  final KeyEventResult Function(KeyEvent) onKeyEvent;
  final VoidCallback onPop;
  final VoidCallback onToggleControls;
  final void Function(int) onDoubleTapSeek;
  final void Function(double) onBrightnessDragUpdate;
  final void Function(double) onVolumeDragUpdate;
  final VoidCallback onUserActivity;
  final VoidCallback onStartHideTimer;
  final VoidCallback onCancelHideTimer;
  final void Function(bool) onInteractingWithUi;
  final VoidCallback onBack;
  final VoidCallback onSelectServer;
  final VoidCallback onOpenAudioAndSubtitles;
  final VoidCallback onSelectSpeed;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback onOpenExternal;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onPlayNextEpisode;
  final VoidCallback onToggleScreenOrientation;
  final VoidCallback onToggleLockOrientation;
  final VoidCallback onLockControls;
  final VoidCallback onUnlockControls;
  final VoidCallback onShowUnlockButton;
  final VoidCallback onTriggerSkip;
  final VoidCallback onRestartPlayback;
  final VoidCallback onDismissResumeBanner;
  final String Function(Duration) formatDuration;

  const PlayerVideoView({
    super.key,
    required this.player,
    required this.controller,
    required this.videoFit,
    required this.focusNode,
    required this.mediaItem,
    required this.activeSource,
    required this.sourcesCount,
    required this.currentSourceIndex,
    this.currentSeason,
    this.currentEpisode,
    required this.externalSubtitles,
    required this.showControls,
    required this.isControlsLocked,
    required this.showUnlockButton,
    required this.isLoadingVideo,
    required this.isBuffering,
    required this.isPlayerReady,
    this.errorMessage,
    this.toastMessage,
    required this.isOrientationLocked,
    required this.brightness,
    required this.showBrightnessIndicator,
    required this.volume,
    required this.showVolumeIndicator,
    this.doubleTapSeekDirection,
    this.activeSkip,
    required this.showResumeBanner,
    required this.resumedFromSeconds,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.hasNextEpisode,
    required this.tvBackBtnFocusNode,
    required this.seekbarTvFocusNode,
    required this.playPauseTvFocusNode,
    required this.onKeyEvent,
    required this.onPop,
    required this.onToggleControls,
    required this.onDoubleTapSeek,
    required this.onBrightnessDragUpdate,
    required this.onVolumeDragUpdate,
    required this.onUserActivity,
    required this.onStartHideTimer,
    required this.onCancelHideTimer,
    required this.onInteractingWithUi,
    required this.onBack,
    required this.onSelectServer,
    required this.onOpenAudioAndSubtitles,
    required this.onSelectSpeed,
    required this.onToggleAspectRatio,
    required this.onOpenExternal,
    required this.onEnterPip,
    required this.onToggleFullscreen,
    required this.onPlayNextEpisode,
    required this.onToggleScreenOrientation,
    required this.onToggleLockOrientation,
    required this.onLockControls,
    required this.onUnlockControls,
    required this.onShowUnlockButton,
    required this.onTriggerSkip,
    required this.onRestartPlayback,
    required this.onDismissResumeBanner,
    required this.formatDuration,
  });

  @override
  State<PlayerVideoView> createState() => _PlayerVideoViewState();
}

class _PlayerVideoViewState extends State<PlayerVideoView> {
  TapDownDetails? _doubleTapDetails;
  bool _isDraggingBrightness = false;
  bool _isDraggingVolume = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isTv = context.watch<AppProvider>().isTvMode;
    final cast = context.watch<CastProvider>();

    if (cast.isCasting && widget.player.state.playing) {
      widget.player.pause();
    }

    final showLoadingSpinner =
        (widget.isLoadingVideo ||
            widget.isBuffering ||
            !widget.isPlayerReady) &&
        widget.errorMessage == null &&
        !cast.isCasting;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      canRequestFocus: true,
      onKeyEvent: (node, event) => widget.onKeyEvent(event),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          widget.onPop();
        },
        child: Scaffold(
          backgroundColor: tokens.canvasBackground,
          body: MouseRegion(
            cursor: widget.showControls
                ? SystemMouseCursors.basic
                : SystemMouseCursors.none,
            onHover: (_) => widget.onUserActivity(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.isControlsLocked) {
                  widget.onShowUnlockButton();
                } else {
                  widget.onToggleControls();
                }
              },
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: () {
                if (widget.isControlsLocked) return;
                final screenWidth = MediaQuery.of(context).size.width;
                final tapX =
                    _doubleTapDetails?.localPosition.dx ?? (screenWidth / 2);
                widget.onDoubleTapSeek(tapX < screenWidth * 0.5 ? -10 : 10);
              },
              onVerticalDragStart: (details) {
                if (isTv || widget.isControlsLocked) return;
                final screenWidth = MediaQuery.of(context).size.width;
                if (details.localPosition.dx < screenWidth * 0.45) {
                  _isDraggingBrightness = true;
                  _isDraggingVolume = false;
                } else if (details.localPosition.dx > screenWidth * 0.55) {
                  _isDraggingVolume = true;
                  _isDraggingBrightness = false;
                }
              },
              onVerticalDragUpdate: (details) {
                if (_isDraggingBrightness) {
                  widget.onBrightnessDragUpdate(details.primaryDelta ?? 0);
                } else if (_isDraggingVolume) {
                  widget.onVolumeDragUpdate(details.primaryDelta ?? 0);
                }
              },
              onVerticalDragEnd: (_) {
                _isDraggingBrightness = false;
                _isDraggingVolume = false;
              },
              child: Stack(
                children: [
                  // Video Surface
                  Center(
                    child: Video(
                      controller: widget.controller,
                      controls: NoVideoControls,
                      fit: widget.videoFit,
                      pauseUponEnteringBackgroundMode: false,
                      resumeUponEnteringForegroundMode: false,
                    ),
                  ),

                  // Casting Overlay Banner
                  if (cast.isCasting && !isTv)
                    PlayerCastingOverlay(
                      mediaItem: widget.mediaItem,
                      activeSource: widget.activeSource,
                      player: widget.player,
                      externalSubtitles: widget.externalSubtitles,
                    ),

                  // Loading / Buffering Indicator
                  if (showLoadingSpinner)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.isLoadingVideo
                                ? 'Loading "${widget.mediaItem.cleanTitle}"…'
                                : 'Buffering…',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Toast Notification Overlay
                  if (widget.toastMessage != null)
                    Positioned(
                      top: 64,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.canvasBackground.withValues(
                              alpha: 0.8,
                            ),
                            radius: tokens.cardRadius * 2,
                            side: BorderSide(color: tokens.borderSubtle),
                          ),
                          child: Text(
                            widget.toastMessage!,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Controls Overlay
                  if (!widget.isControlsLocked)
                    AnimatedOpacity(
                      opacity: widget.showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: IgnorePointer(
                        ignoring: !_isControlsActive,
                        child: ExcludeFocus(
                          excluding: !_isControlsActive,
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (_) {
                              widget.onInteractingWithUi(true);
                              widget.onCancelHideTimer();
                            },
                            onPointerUp: (_) {
                              widget.onInteractingWithUi(false);
                              widget.onStartHideTimer();
                            },
                            onPointerCancel: (_) {
                              widget.onInteractingWithUi(false);
                              widget.onStartHideTimer();
                            },
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        tokens.canvasBackground.withValues(
                                          alpha: 0.8,
                                        ),
                                        Colors.transparent,
                                        Colors.transparent,
                                        tokens.canvasBackground.withValues(
                                          alpha: 0.9,
                                        ),
                                      ],
                                      stops: const [0.0, 0.25, 0.7, 1.0],
                                    ),
                                  ),
                                  child: SafeArea(
                                    child: isTv
                                        ? PlayerTvControls(
                                            player: widget.player,
                                            mediaItem: widget.mediaItem,
                                            currentSeason: widget.currentSeason,
                                            currentEpisode:
                                                widget.currentEpisode,
                                            activeSource: widget.activeSource,
                                            sourcesCount: widget.sourcesCount,
                                            currentSourceIndex:
                                                widget.currentSourceIndex,
                                            videoFit: widget.videoFit,
                                            tvBackBtnFocusNode:
                                                widget.tvBackBtnFocusNode,
                                            seekbarTvFocusNode:
                                                widget.seekbarTvFocusNode,
                                            playPauseTvFocusNode:
                                                widget.playPauseTvFocusNode,
                                            onBack: widget.onBack,
                                            onSelectServer:
                                                widget.onSelectServer,
                                            onOpenAudioAndSubtitles:
                                                widget.onOpenAudioAndSubtitles,
                                            onToggleAspectRatio:
                                                widget.onToggleAspectRatio,
                                            onStartHideTimer:
                                                widget.onStartHideTimer,
                                            formatDuration:
                                                PlayerTimeHelper.formatDuration,
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              PlayerTopBar(
                                                mediaItem: widget.mediaItem,
                                                currentSeason:
                                                    widget.currentSeason,
                                                currentEpisode:
                                                    widget.currentEpisode,
                                                activeSource:
                                                    widget.activeSource,
                                                sourcesCount:
                                                    widget.sourcesCount,
                                                currentSourceIndex:
                                                    widget.currentSourceIndex,
                                                player: widget.player,
                                                externalSubtitles:
                                                    widget.externalSubtitles,
                                                onBack: widget.onBack,
                                                onSelectServer:
                                                    widget.onSelectServer,
                                                moreOptionsMenu:
                                                    PlayerMoreOptionsMenu(
                                                      isSeries: widget
                                                          .mediaItem
                                                          .isSeries,
                                                      hasNextEpisode:
                                                          widget.hasNextEpisode,
                                                      activeQuality: widget
                                                          .activeSource
                                                          .quality,
                                                      playbackSpeed:
                                                          widget.playbackSpeed,
                                                      isFullscreen:
                                                          widget.isFullscreen,
                                                      onUserActivity:
                                                          widget.onUserActivity,
                                                      onPlayNextEpisode: widget
                                                          .onPlayNextEpisode,
                                                      onSelectServer:
                                                          widget.onSelectServer,
                                                      onSelectAudio: widget
                                                          .onOpenAudioAndSubtitles,
                                                      onSelectSpeed:
                                                          widget.onSelectSpeed,
                                                      onToggleAspectRatio: widget
                                                          .onToggleAspectRatio,
                                                      onOpenExternal:
                                                          widget.onOpenExternal,
                                                      onEnterPip:
                                                          widget.onEnterPip,
                                                      onToggleFullscreen: widget
                                                          .onToggleFullscreen,
                                                    ),
                                                onUserActivity:
                                                    widget.onUserActivity,
                                              ),
                                              const SizedBox.shrink(),
                                              PlayerBottomControls(
                                                player: widget.player,
                                                isControlsLocked:
                                                    widget.isControlsLocked,
                                                videoFit: widget.videoFit,
                                                onToggleAspectRatio:
                                                    widget.onToggleAspectRatio,
                                                onEnterPip: widget.onEnterPip,
                                                onCancelHideTimer:
                                                    widget.onCancelHideTimer,
                                                onStartHideTimer:
                                                    widget.onStartHideTimer,
                                                onInteractingWithUi:
                                                    widget.onInteractingWithUi,
                                                formatDuration: PlayerTimeHelper
                                                    .formatDuration,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                // Side Controls (Screen Rotate & Screen Lock) (Non-TV only)
                                if (!isTv)
                                  PlayerSideControls(
                                    isOrientationLocked:
                                        widget.isOrientationLocked,
                                    onToggleScreenOrientation:
                                        widget.onToggleScreenOrientation,
                                    onToggleLockOrientation:
                                        widget.onToggleLockOrientation,
                                    onLockControls: widget.onLockControls,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Floating Gesture HUD
                  PlayerGestureHud(
                    isTv: isTv,
                    isControlsLocked: widget.isControlsLocked,
                    showBrightnessIndicator: widget.showBrightnessIndicator,
                    brightness: widget.brightness,
                    showVolumeIndicator: widget.showVolumeIndicator,
                    volume: widget.volume,
                    doubleTapSeekDirection: widget.doubleTapSeekDirection,
                    showControls: widget.showControls,
                    activeSkip: widget.activeSkip,
                    onTriggerSkip: widget.onTriggerSkip,
                    showResumeBanner: widget.showResumeBanner,
                    resumedFromSeconds: widget.resumedFromSeconds,
                    onRestartPlayback: widget.onRestartPlayback,
                    onDismissResumeBanner: widget.onDismissResumeBanner,
                    formatDuration: PlayerTimeHelper.formatDuration,
                    showUnlockButton: widget.showUnlockButton,
                    onUnlockControls: widget.onUnlockControls,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isControlsActive => widget.showControls;
}
