import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/cast_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/cast_dialog.dart';

/// Top Bar for Desktop and Mobile player layouts
class PlayerTopBar extends StatelessWidget {
  final MediaItem mediaItem;
  final int? currentSeason;
  final int? currentEpisode;
  final StreamSource activeSource;
  final int sourcesCount;
  final int currentSourceIndex;
  final Player player;
  final List<SubtitleOption> externalSubtitles;
  final VoidCallback onBack;
  final VoidCallback onSelectServer;
  final Widget moreOptionsMenu;
  final VoidCallback onUserActivity;

  const PlayerTopBar({
    super.key,
    required this.mediaItem,
    this.currentSeason,
    this.currentEpisode,
    required this.activeSource,
    required this.sourcesCount,
    required this.currentSourceIndex,
    required this.player,
    required this.externalSubtitles,
    required this.onBack,
    required this.onSelectServer,
    required this.moreOptionsMenu,
    required this.onUserActivity,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isTv = context.watch<AppProvider>().isTvMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: tokens.borderRadiusPill,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: tokens.getShapeDecoration(
                color: tokens.surfaceElevated.withValues(alpha: 0.6),
                radius: tokens.cardRadius * 2,
                side: BorderSide(color: tokens.borderSubtle, width: 1),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: tokens.textPrimary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                if (currentSeason != null && currentEpisode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Season $currentSeason • Episode $currentEpisode',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Cast Action Button (Hide on TV)
          if (!isTv)
            Consumer<CastProvider>(
              builder: (context, cast, _) {
                final isCastingThis = cast.isConnected;
                return Tooltip(
                  message: isCastingThis
                      ? 'Casting to ${cast.connectedDevice?.name}'
                      : 'Cast to TV / Device',
                  child: InkWell(
                    onTap: () {
                      onUserActivity();
                      CastDialog.show(
                        context,
                        mediaItem: mediaItem,
                        streamSource: activeSource,
                        startPosition: player.state.position,
                        subtitles: externalSubtitles,
                      );
                    },
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: tokens.getShapeDecoration(
                        color: isCastingThis
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : tokens.surfaceElevated.withValues(alpha: 0.6),
                        radius: tokens.cardRadius * 2,
                        side: BorderSide(
                          color: isCastingThis
                              ? theme.colorScheme.primary
                              : tokens.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isCastingThis
                            ? Icons.cast_connected_rounded
                            : Icons.cast_rounded,
                        color: isCastingThis
                            ? theme.colorScheme.primary
                            : tokens.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Server Selection Button
          if (sourcesCount > 1)
            Tooltip(
              message: 'Quality & Servers (${activeSource.quality})',
              child: InkWell(
                onTap: () {
                  onUserActivity();
                  onSelectServer();
                },
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.6),
                    radius: tokens.cardRadius * 2,
                    side: BorderSide(color: tokens.borderSubtle, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        color: tokens.textPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Server ${currentSourceIndex + 1}',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          moreOptionsMenu,
        ],
      ),
    );
  }
}

/// Bottom Controls for Mobile and Desktop player
class PlayerBottomControls extends StatelessWidget {
  final Player player;
  final bool isControlsLocked;
  final BoxFit videoFit;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback onEnterPip;
  final VoidCallback onCancelHideTimer;
  final VoidCallback onStartHideTimer;
  final void Function(bool) onInteractingWithUi;
  final String Function(Duration) formatDuration;

  const PlayerBottomControls({
    super.key,
    required this.player,
    required this.isControlsLocked,
    required this.videoFit,
    required this.onToggleAspectRatio,
    required this.onEnterPip,
    required this.onCancelHideTimer,
    required this.onStartHideTimer,
    required this.onInteractingWithUi,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (isControlsLocked) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: StreamBuilder<Duration>(
        stream: player.stream.position,
        builder: (context, snapshot) {
          final position = snapshot.data ?? player.state.position;
          final duration = player.state.duration;
          final maxMs = duration.inMilliseconds.toDouble();
          final curMs = position.inMilliseconds.toDouble().clamp(
            0.0,
            maxMs > 0 ? maxMs : 1.0,
          );

          return Row(
            children: [
              // 1. Play / Pause Button
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, playingSnap) {
                  final isPlaying = playingSnap.data ?? player.state.playing;
                  return InkWell(
                    onTap: () {
                      player.playOrPause();
                      onStartHideTimer();
                    },
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: tokens.getShapeDecoration(
                        color: theme.colorScheme.primary,
                        radius: tokens.cardRadius * 2,
                        shadows: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // 2. Played Time
              Text(
                formatDuration(position),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),

              // 3. Slider Seekbar
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: tokens.borderSubtle.withValues(
                      alpha: 0.5,
                    ),
                    thumbColor: theme.colorScheme.primary,
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                  ),
                  child: Slider(
                    value: curMs,
                    max: maxMs > 0 ? maxMs : 1.0,
                    onChangeStart: (val) {
                      onInteractingWithUi(true);
                      onCancelHideTimer();
                    },
                    onChangeEnd: (val) {
                      onInteractingWithUi(false);
                      onStartHideTimer();
                    },
                    onChanged: (val) {
                      player.seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 4. Total Duration
              Text(
                duration > Duration.zero ? formatDuration(duration) : '00:00',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 6),

              // 5. Fit Screen (Aspect Ratio) Button
              Tooltip(
                message: videoFit == BoxFit.contain
                    ? 'Fit to Screen'
                    : 'Contain',
                child: InkWell(
                  onTap: onToggleAspectRatio,
                  borderRadius: tokens.borderRadiusPill,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceElevated.withValues(alpha: 0.6),
                      radius: tokens.cardRadius * 2,
                      side: BorderSide(color: tokens.borderSubtle, width: 1),
                    ),
                    child: Icon(
                      videoFit == BoxFit.contain
                          ? Icons.aspect_ratio_rounded
                          : Icons.fit_screen_rounded,
                      color: tokens.textSecondary,
                      size: 17,
                    ),
                  ),
                ),
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(width: 6),
                // 6. Picture-in-Picture Button
                Tooltip(
                  message: 'Picture-in-Picture (PiP)',
                  child: InkWell(
                    onTap: onEnterPip,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceElevated.withValues(alpha: 0.6),
                        radius: tokens.cardRadius * 2,
                        side: BorderSide(color: tokens.borderSubtle, width: 1),
                      ),
                      child: Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: tokens.textSecondary,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// More Options Menu Popup
class PlayerMoreOptionsMenu extends StatelessWidget {
  final bool isSeries;
  final bool hasNextEpisode;
  final String activeQuality;
  final double playbackSpeed;
  final bool isFullscreen;
  final VoidCallback onPlayNextEpisode;
  final VoidCallback onSelectServer;
  final VoidCallback onSelectAudio;
  final VoidCallback onSelectSpeed;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback onOpenExternal;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onUserActivity;

  const PlayerMoreOptionsMenu({
    super.key,
    required this.isSeries,
    required this.hasNextEpisode,
    required this.activeQuality,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.onPlayNextEpisode,
    required this.onSelectServer,
    required this.onSelectAudio,
    required this.onSelectSpeed,
    required this.onToggleAspectRatio,
    required this.onOpenExternal,
    required this.onEnterPip,
    required this.onToggleFullscreen,
    required this.onUserActivity,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: 'Playback Options',
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.6),
          radius: tokens.cardRadius * 2,
          side: BorderSide(color: tokens.borderSubtle, width: 1),
        ),
        child: Icon(
          Icons.more_vert_rounded,
          color: tokens.textPrimary,
          size: 20,
        ),
      ),
      color: tokens.surfaceElevated,
      shape: tokens.shapeMd,
      onSelected: (value) {
        onUserActivity();
        switch (value) {
          case 'next_episode':
            onPlayNextEpisode();
            break;
          case 'server':
            onSelectServer();
            break;
          case 'audio':
            onSelectAudio();
            break;
          case 'speed':
            onSelectSpeed();
            break;
          case 'aspect':
            onToggleAspectRatio();
            break;
          case 'external':
            onOpenExternal();
            break;
          case 'pip':
            onEnterPip();
            break;
          case 'fullscreen':
            onToggleFullscreen();
            break;
        }
      },
      itemBuilder: (context) => [
        if (Platform.isAndroid)
          PopupMenuItem(
            value: 'pip',
            child: Row(
              children: [
                Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: tokens.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Picture-in-Picture (PiP)',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (isSeries && hasNextEpisode)
          PopupMenuItem(
            value: 'next_episode',
            child: Row(
              children: [
                Icon(
                  Icons.skip_next_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Next Episode',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'server',
          child: Row(
            children: [
              Icon(
                Icons.dns_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quality & Servers ($activeQuality)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'audio',
          child: Row(
            children: [
              Icon(
                Icons.subtitles_rounded,
                color: tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Audio & Subtitles',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'speed',
          child: Row(
            children: [
              Icon(Icons.speed_rounded, color: tokens.textSecondary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Playback Speed (${playbackSpeed}x)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'external',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open in External Player (VLC / MPV)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          PopupMenuItem(
            value: 'fullscreen',
            child: Row(
              children: [
                Icon(
                  isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: tokens.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Floating action buttons on right middle edge (Screen Rotate and Touch Lock)
class PlayerSideControls extends StatelessWidget {
  final bool isOrientationLocked;
  final VoidCallback onToggleScreenOrientation;
  final VoidCallback onToggleLockOrientation;
  final VoidCallback onLockControls;

  const PlayerSideControls({
    super.key,
    required this.isOrientationLocked,
    required this.onToggleScreenOrientation,
    required this.onToggleLockOrientation,
    required this.onLockControls,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Screen Rotate Button
            Tooltip(
              message: isOrientationLocked
                  ? 'Orientation Locked (Hold to auto-rotate)'
                  : 'Rotate Screen (Hold to lock)',
              child: InkWell(
                onTap: onToggleScreenOrientation,
                onLongPress: onToggleLockOrientation,
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: tokens.getShapeDecoration(
                    color: isOrientationLocked
                        ? theme.colorScheme.primary.withValues(alpha: 0.25)
                        : tokens.surfaceElevated.withValues(alpha: 0.75),
                    radius: tokens.cardRadius * 2,
                    side: BorderSide(
                      color: isOrientationLocked
                          ? theme.colorScheme.primary
                          : tokens.borderSubtle,
                      width: 1,
                    ),
                    shadows: [
                      BoxShadow(
                        color: tokens.shadowColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isOrientationLocked
                        ? Icons.screen_lock_rotation_rounded
                        : Icons.screen_rotation_rounded,
                    color: isOrientationLocked
                        ? theme.colorScheme.primary
                        : tokens.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 2. Screen Lock Button (Below Rotate Button)
            Tooltip(
              message: 'Lock Screen Controls',
              child: InkWell(
                onTap: onLockControls,
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.75),
                    radius: tokens.cardRadius * 2,
                    side: BorderSide(color: tokens.borderSubtle, width: 1),
                    shadows: [
                      BoxShadow(
                        color: tokens.shadowColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: tokens.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating Casting Active Overlay Dialog Card when streaming remotely to TV/DLNA
class PlayerCastingOverlay extends StatelessWidget {
  final MediaItem mediaItem;
  final StreamSource activeSource;
  final Player player;
  final List<SubtitleOption> externalSubtitles;

  const PlayerCastingOverlay({
    super.key,
    required this.mediaItem,
    required this.activeSource,
    required this.player,
    required this.externalSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final cast = context.watch<CastProvider>();

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.92),
          radius: tokens.cardRadius * 1.4,
          side: BorderSide(
            color: tokens.borderFocus.withValues(alpha: 0.5),
            width: 1.5,
          ),
          shadows: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: 0.7),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cast_connected_rounded,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Playing on ${cast.connectedDevice?.name ?? "Cast Device"}',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cast.isPlaying
                  ? 'Streaming smoothly'
                  : (cast.isPaused ? 'Paused on TV' : 'Connecting to TV...'),
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    CastDialog.show(
                      context,
                      mediaItem: mediaItem,
                      streamSource: activeSource,
                      startPosition: player.state.position,
                      subtitles: externalSubtitles,
                    );
                  },
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Cast Controls'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: tokens.shapeSm,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await cast.disconnect();
                    player.play();
                  },
                  icon: Icon(
                    Icons.phone_android_rounded,
                    size: 18,
                    color: tokens.textPrimary,
                  ),
                  label: Text(
                    'Play Here',
                    style: TextStyle(color: tokens.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tokens.borderSubtle),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: tokens.shapeSm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
