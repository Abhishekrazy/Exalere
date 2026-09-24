import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../models/stream_source.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/cast_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/cast_dialog.dart';
import 'player_playback_helper.dart';

/// Top Bar for Desktop and Mobile player layouts
class PlayerTopBar extends StatelessWidget {
  final MediaItem mediaItem;
  final int? currentSeason;
  final int? currentEpisode;
  final Episode? currentEpisodeData;
  final StreamSource activeSource;
  final int sourcesCount;
  final int currentSourceIndex;
  final int serversCount;
  final int currentServerIndex;
  final String? currentServerName;
  final Player player;
  final List<SubtitleOption> externalSubtitles;
  final VoidCallback onBack;
  final VoidCallback onSelectServer;
  final VoidCallback? onSelectQuality;
  final VoidCallback? onOpenAudioAndSubtitles;
  final VoidCallback? onSelectSpeed;
  final double playbackSpeed;
  final Widget moreOptionsMenu;
  final VoidCallback onUserActivity;

  const PlayerTopBar({
    super.key,
    required this.mediaItem,
    this.currentSeason,
    this.currentEpisode,
    this.currentEpisodeData,
    required this.activeSource,
    required this.sourcesCount,
    required this.currentSourceIndex,
    this.serversCount = 1,
    this.currentServerIndex = 1,
    this.currentServerName,
    required this.player,
    required this.externalSubtitles,
    required this.onBack,
    required this.onSelectServer,
    this.onSelectQuality,
    this.onOpenAudioAndSubtitles,
    this.onSelectSpeed,
    this.playbackSpeed = 1.0,
    required this.moreOptionsMenu,
    required this.onUserActivity,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isTv = context.watch<AppProvider>().isTvMode;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      // Portrait layout (Mobile): keep Top Bar clean and minimal,
      // all extra options that don't fit are collapsed into moreOptionsMenu.
      final hasEpisodeInfo =
          currentEpisodeData != null &&
          currentEpisodeData!.title.isNotEmpty &&
          currentEpisodeData!.title.toLowerCase() != 'episode $currentEpisode';

      final episodeLabel = hasEpisodeInfo
          ? 'S$currentSeason:E$currentEpisode • ${currentEpisodeData!.title}'
          : (currentSeason != null && currentEpisode != null
                ? 'S$currentSeason • E$currentEpisode'
                : null);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            const SizedBox(width: 10),
            if (currentEpisodeData?.thumbnail != null &&
                currentEpisodeData!.thumbnail!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: tokens.borderRadiusSm,
                child: Container(
                  width: 80,
                  height: 45,
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(color: tokens.borderSubtle, width: 0.8),
                  ),
                  child: CachedNetworkImage(
                    imageUrl:
                        EpisodeHelper.highResThumbnailUrl(
                          currentEpisodeData!.thumbnail,
                        ) ??
                        currentEpisodeData!.thumbnail!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: tokens.surfaceCard,
                      child: Center(
                        child: Icon(
                          Icons.tv_rounded,
                          color: tokens.textMuted,
                          size: 18,
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: tokens.surfaceCard,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: tokens.textMuted,
                          size: 18,
                        ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mediaItem.cleanTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (episodeLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        episodeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            moreOptionsMenu,
          ],
        ),
      );
    }

    // Horizontal / Landscape layout: provide dedicated Quality button next to Server,
    // Play Speed button, Audio & Subtitles button, and Cast button.
    final hasEpisodeInfo =
        currentEpisodeData != null &&
        currentEpisodeData!.title.isNotEmpty &&
        currentEpisodeData!.title.toLowerCase() != 'episode $currentEpisode';

    final episodeLabel = hasEpisodeInfo
        ? 'S$currentSeason • E$currentEpisode  —  "${currentEpisodeData!.title}"'
        : (currentSeason != null && currentEpisode != null
              ? 'Season $currentSeason • Episode $currentEpisode'
              : null);

    final screenWidth = MediaQuery.of(context).size.width;
    final double thumbWidth = screenWidth >= 1000
        ? 160.0
        : (screenWidth >= 700 ? 136.0 : 108.0);
    final double thumbHeight = thumbWidth * 9 / 16;

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
          const SizedBox(width: 12),
          if (currentEpisodeData?.thumbnail != null &&
              currentEpisodeData!.thumbnail!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: tokens.borderRadiusSm,
              child: Container(
                width: thumbWidth,
                height: thumbHeight,
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: tokens.borderRadiusSm,
                  border: Border.all(color: tokens.borderSubtle, width: 0.8),
                ),
                child: CachedNetworkImage(
                  imageUrl:
                      EpisodeHelper.highResThumbnailUrl(
                        currentEpisodeData!.thumbnail,
                      ) ??
                      currentEpisodeData!.thumbnail!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: tokens.surfaceCard,
                    child: Center(
                      child: Icon(
                        Icons.tv_rounded,
                        color: tokens.textMuted,
                        size: 24,
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: tokens.surfaceCard,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: tokens.textMuted,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                if (episodeLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      episodeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (currentEpisodeData?.overview != null &&
                    currentEpisodeData!.overview!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      currentEpisodeData!.overview!.trim(),
                      maxLines: screenWidth >= 1000 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 1. Server Selection Button (when multiple servers exist or single server)
          if (serversCount > 1 || sourcesCount > 1)
            Tooltip(
              message: 'Switch Streaming Server',
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
                      const SizedBox(width: 5),
                      Text(
                        serversCount > 1
                            ? 'Server $currentServerIndex / $serversCount'
                            : (currentServerName != null &&
                                      currentServerName!.isNotEmpty
                                  ? 'Server: $currentServerName'
                                  : 'Server'),
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

          // 2. Dedicated Quality Button (placed right next to Server)
          Tooltip(
            message: 'Video Quality (${activeSource.quality})',
            child: InkWell(
              onTap: () {
                onUserActivity();
                (onSelectQuality ?? onSelectServer)();
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
                      Icons.high_quality_rounded,
                      color: tokens.textPrimary,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      activeSource.quality.isNotEmpty
                          ? activeSource.quality
                          : 'Quality',
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
          // 3. Dedicated Playback Speed Button (placed next to Quality)
          if (onSelectSpeed != null)
            Tooltip(
              message:
                  'Playback Speed (${playbackSpeed.toStringAsFixed(playbackSpeed.truncateToDouble() == playbackSpeed ? 1 : 2)}x)',
              child: InkWell(
                onTap: () {
                  onUserActivity();
                  onSelectSpeed!();
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
                        Icons.speed_rounded,
                        color: tokens.textPrimary,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${playbackSpeed.toStringAsFixed(playbackSpeed.truncateToDouble() == playbackSpeed ? 1 : 2)}x',
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
          // 4. Audio & Subtitles Shortcut Button on Horizontal Layout
          if (onOpenAudioAndSubtitles != null)
            Tooltip(
              message: 'Audio & Subtitles',
              child: InkWell(
                onTap: () {
                  onUserActivity();
                  onOpenAudioAndSubtitles!();
                },
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.6),
                    radius: tokens.cardRadius * 2,
                    side: BorderSide(color: tokens.borderSubtle, width: 1),
                  ),
                  child: Icon(
                    Icons.subtitles_rounded,
                    color: tokens.textPrimary,
                    size: 19,
                  ),
                ),
              ),
            ),
          // 5. Cast Action Button (Hide on TV)
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
  final bool isLiveTv;
  final SkipInterval? activeSkip;
  final VoidCallback? onTriggerSkip;
  final void Function(bool)? onPlayPauseTriggered;

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
    this.isLiveTv = false,
    this.activeSkip,
    this.onTriggerSkip,
    this.onPlayPauseTriggered,
  });

  @override
  Widget build(BuildContext context) {
    if (isControlsLocked) return const SizedBox.shrink();

    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

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
              // 1. Play / Pause Button (Available on all platforms)
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, playingSnap) {
                  final isPlaying = playingSnap.data ?? player.state.playing;
                  return InkWell(
                    onTap: () {
                      final nextPlaying = !isPlaying;
                      player.playOrPause();
                      onPlayPauseTriggered?.call(nextPlaying);
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
              if (isLiveTv) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceElevated.withValues(alpha: 0.6),
                    radius: tokens.cardRadius * 1.5,
                    side: BorderSide(
                      color: tokens.liveColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.liveColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tokens.liveColor.withValues(alpha: 0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: tokens.liveColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '1 Min Buffer',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ] else ...[
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
                  child: StreamBuilder<Duration>(
                    stream: player.stream.buffer,
                    builder: (context, bufSnap) {
                      final rawBuffer = bufSnap.data ?? player.state.buffer;
                      final bufferPos = rawBuffer > position
                          ? rawBuffer
                          : position;
                      final curBufferMs = maxMs > 0
                          ? bufferPos.inMilliseconds.toDouble().clamp(
                              curMs,
                              maxMs,
                            )
                          : 0.0;

                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: theme.colorScheme.primary,
                          secondaryActiveTrackColor: tokens.textPrimary
                              .withValues(alpha: 0.35),
                          inactiveTrackColor: tokens.borderSubtle.withValues(
                            alpha: 0.35,
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
                          secondaryTrackValue: curBufferMs,
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
                      );
                    },
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
              ],

              // Skip Intro / Outro Button (when active)
              if (activeSkip != null && onTriggerSkip != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onTriggerSkip,
                  borderRadius: tokens.borderRadiusPill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      radius: tokens.cardRadius * 2,
                      side: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fast_forward_rounded,
                          color: theme.colorScheme.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activeSkip!.label,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),

              // 5. Fit Screen (Aspect Ratio) & PiP (Shown on horizontal layout only to maximize seekbar width in portrait)
              if (!isPortrait) ...[
                const SizedBox(width: 6),
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
                          side: BorderSide(
                            color: tokens.borderSubtle,
                            width: 1,
                          ),
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
  final VoidCallback? onSelectQuality;
  final VoidCallback onSelectAudio;
  final VoidCallback onSelectSpeed;
  final VoidCallback onToggleAspectRatio;
  final VoidCallback onOpenExternal;
  final VoidCallback onEnterPip;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onUserActivity;
  final VoidCallback? onCast;

  const PlayerMoreOptionsMenu({
    super.key,
    required this.isSeries,
    required this.hasNextEpisode,
    required this.activeQuality,
    required this.playbackSpeed,
    required this.isFullscreen,
    required this.onPlayNextEpisode,
    required this.onSelectServer,
    this.onSelectQuality,
    required this.onSelectAudio,
    required this.onSelectSpeed,
    required this.onToggleAspectRatio,
    required this.onOpenExternal,
    required this.onEnterPip,
    required this.onToggleFullscreen,
    required this.onUserActivity,
    this.onCast,
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
          case 'quality':
            (onSelectQuality ?? onSelectServer)();
            break;
          case 'server':
            onSelectServer();
            break;
          case 'audio':
            onSelectAudio();
            break;
          case 'aspect':
            onToggleAspectRatio();
            break;
          case 'speed':
            onSelectSpeed();
            break;
          case 'cast':
            onCast?.call();
            break;
          case 'next_episode':
            onPlayNextEpisode();
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
        PopupMenuItem(
          value: 'quality',
          child: Row(
            children: [
              Icon(
                Icons.high_quality_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Video Quality ($activeQuality)',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'server',
          child: Row(
            children: [
              Icon(Icons.dns_rounded, color: tokens.textSecondary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Streaming Servers',
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
          value: 'aspect',
          child: Row(
            children: [
              Icon(
                Icons.aspect_ratio_rounded,
                color: tokens.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Fit Screen / Aspect Ratio',
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
        if (onCast != null)
          PopupMenuItem(
            value: 'cast',
            child: Row(
              children: [
                Icon(Icons.cast_rounded, color: tokens.textSecondary, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cast to TV / Device',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
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
