import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

enum PlayerServerSheetSection { all, servers, quality }

/// Modal bottom sheet for switching streaming servers and video quality tiers.
class PlayerServerSheet extends StatelessWidget {
  final List<StreamSource> sources;
  final int currentSourceIndex;
  final ValueChanged<int> onSourceSelected;
  final List<VideoTrack> videoTracks;
  final VideoTrack? activeVideoTrack;
  final ValueChanged<VideoTrack>? onVideoTrackSelected;
  final PlayerServerSheetSection initialSection;

  const PlayerServerSheet({
    super.key,
    required this.sources,
    required this.currentSourceIndex,
    required this.onSourceSelected,
    this.videoTracks = const [],
    this.activeVideoTrack,
    this.onVideoTrackSelected,
    this.initialSection = PlayerServerSheetSection.all,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required int currentSourceIndex,
    required ValueChanged<int> onSourceSelected,
    List<VideoTrack> videoTracks = const [],
    VideoTrack? activeVideoTrack,
    ValueChanged<VideoTrack>? onVideoTrackSelected,
    PlayerServerSheetSection initialSection = PlayerServerSheetSection.all,
  }) {
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isLandscape = screenWidth > screenHeight;
    final modalHeight = isLandscape
        ? (screenHeight * 0.90).clamp(280.0, 480.0)
        : (screenHeight * 0.65).clamp(280.0, 560.0);

    return showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(radius: tokens.cardRadius + 8),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: modalHeight,
          child: PlayerServerSheet(
            sources: sources,
            currentSourceIndex: currentSourceIndex,
            onSourceSelected: onSourceSelected,
            videoTracks: videoTracks,
            activeVideoTrack: activeVideoTrack,
            onVideoTrackSelected: onVideoTrackSelected,
            initialSection: initialSection,
          ),
        );
      },
    );
  }

  static String formatTrackLabel(
    VideoTrack track, {
    List<String> fallbackQualities = const [],
  }) {
    if (track.id == 'auto') return 'Auto (Adaptive)';
    if (track.h != null && track.h! > 0) {
      final res = '${track.h}p';
      if (track.w != null && track.w! > 0) {
        return '$res (${track.w}×${track.h})';
      }
      return res;
    }
    if (track.title != null && track.title!.isNotEmpty) {
      return track.title!;
    }
    final idNum = int.tryParse(track.id);
    if (idNum != null && idNum > 0 && idNum <= fallbackQualities.length) {
      return fallbackQualities[idNum - 1];
    }
    return 'Quality Tier ${track.id}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenHeight < 550 || screenWidth < 500;

    final selectableVideoTracks = videoTracks.where((t) {
      final l = (t.title ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no' && t.id != 'auto';
    }).toList();

    final currentSource =
        sources.isNotEmpty &&
            currentSourceIndex >= 0 &&
            currentSourceIndex < sources.length
        ? sources[currentSourceIndex]
        : null;

    final hasMultipleTracks = selectableVideoTracks.length > 1;
    final fallbackQualities = currentSource?.availableQualities ?? const [];
    final hasFallbackQualities = fallbackQualities.length > 1;

    final String sheetTitle;
    final IconData sheetIcon;
    if (initialSection == PlayerServerSheetSection.quality) {
      sheetTitle = 'Video Quality';
      sheetIcon = Icons.high_quality_rounded;
    } else if (initialSection == PlayerServerSheetSection.servers) {
      sheetTitle = 'Streaming Servers';
      sheetIcon = Icons.dns_rounded;
    } else {
      sheetTitle = 'Servers & Streaming Quality';
      sheetIcon = Icons.tune_rounded;
    }

    final serversSection = [
      if (sources.length > 1) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            'STREAMING SERVERS',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        for (int idx = 0; idx < sources.length; idx++) ...[
          _buildServerTile(context, theme, tokens, idx, isCompact),
          SizedBox(height: isCompact ? 6 : 8),
        ],
        const SizedBox(height: 10),
      ],
    ];

    final qualitiesSection = [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          'VIDEO QUALITY',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      if (hasMultipleTracks) ...[
        _buildQualityTile(
          context: context,
          theme: theme,
          tokens: tokens,
          isCompact: isCompact,
          label: 'Auto (Adaptive Bitrate)',
          subtitle: 'Best network-responsive playback',
          badge: 'Recommended',
          isSelected:
              activeVideoTrack == null || activeVideoTrack?.id == 'auto',
          autofocus:
              (initialSection == PlayerServerSheetSection.quality ||
                  sources.length <= 1) &&
              (activeVideoTrack == null || activeVideoTrack?.id == 'auto'),
          onTap: () {
            Navigator.of(context).pop();
            onVideoTrackSelected?.call(VideoTrack.auto());
          },
        ),
        SizedBox(height: isCompact ? 6 : 8),
        for (final track in selectableVideoTracks) ...[
          _buildQualityTile(
            context: context,
            theme: theme,
            tokens: tokens,
            isCompact: isCompact,
            label: formatTrackLabel(
              track,
              fallbackQualities: fallbackQualities,
            ),
            subtitle: track.bitrate != null && track.bitrate! > 0
                ? '${(track.bitrate! / 1000000).toStringAsFixed(1)} Mbps'
                : (track.h != null && track.h! >= 1080
                      ? 'Full HD (Higher bandwidth)'
                      : (track.h != null && track.h! >= 720
                            ? 'Smooth playback (Recommended)'
                            : (track.h != null && track.h! > 0
                                  ? 'Data saver / Lower bandwidth'
                                  : null))),
            badge: track.h != null && track.h! >= 1080
                ? 'FHD'
                : (track.h != null && track.h! >= 720
                      ? 'HD'
                      : (track.h != null && track.h! > 0 ? 'SD' : null)),
            isSelected: activeVideoTrack?.id == track.id,
            autofocus:
                (initialSection == PlayerServerSheetSection.quality ||
                    sources.length <= 1) &&
                activeVideoTrack?.id == track.id,
            onTap: () {
              Navigator.of(context).pop();
              onVideoTrackSelected?.call(track);
            },
          ),
          SizedBox(height: isCompact ? 6 : 8),
        ],
      ] else if (hasFallbackQualities) ...[
        _buildQualityTile(
          context: context,
          theme: theme,
          tokens: tokens,
          isCompact: isCompact,
          label: 'Auto (Adaptive Bitrate)',
          subtitle: 'Best network-responsive playback',
          badge: 'Recommended',
          isSelected:
              activeVideoTrack == null ||
              activeVideoTrack?.id == 'auto' ||
              (currentSource?.quality.toLowerCase().contains('auto') == true),
          autofocus:
              (initialSection == PlayerServerSheetSection.quality ||
                  sources.length <= 1) &&
              (activeVideoTrack == null ||
                  activeVideoTrack?.id == 'auto' ||
                  (currentSource?.quality.toLowerCase().contains('auto') ==
                      true)),
          onTap: () {
            Navigator.of(context).pop();
            onVideoTrackSelected?.call(VideoTrack.auto());
          },
        ),
        SizedBox(height: isCompact ? 6 : 8),
        for (int qIdx = 0; qIdx < fallbackQualities.length; qIdx++) ...[
          () {
            final q = fallbackQualities[qIdx];
            final h = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final trackId = (qIdx + 1).toString();
            final matchingTrack = selectableVideoTracks
                .where((t) => t.h == h || t.id == trackId)
                .firstOrNull;
            final targetTrack =
                matchingTrack ??
                VideoTrack(trackId, q, null, h: h > 0 ? h : null);
            final isSelected =
                activeVideoTrack != null && activeVideoTrack!.id != 'auto'
                ? (activeVideoTrack!.id == trackId ||
                      (h > 0 && activeVideoTrack!.h == h))
                : (currentSource?.quality.toLowerCase().contains(
                            h.toString(),
                          ) ==
                          true &&
                      currentSource?.quality.toLowerCase().contains('auto') !=
                          true);
            final badge = h >= 1080
                ? 'FHD'
                : (h >= 720 ? 'HD' : (h > 0 ? 'SD' : null));
            final subtitle = h >= 1080
                ? 'Full HD (Higher bandwidth)'
                : (h >= 720
                      ? 'Smooth playback (Recommended)'
                      : (h > 0 ? 'Data saver / Lower bandwidth' : null));

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQualityTile(
                  context: context,
                  theme: theme,
                  tokens: tokens,
                  isCompact: isCompact,
                  label: q,
                  subtitle: subtitle,
                  badge: badge,
                  isSelected: isSelected,
                  autofocus:
                      (initialSection == PlayerServerSheetSection.quality ||
                          sources.length <= 1) &&
                      isSelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    onVideoTrackSelected?.call(targetTrack);
                  },
                ),
                SizedBox(height: isCompact ? 6 : 8),
              ],
            );
          }(),
        ],
      ] else ...[
        _buildQualityTile(
          context: context,
          theme: theme,
          tokens: tokens,
          isCompact: isCompact,
          label: currentSource?.quality ?? 'Auto (Adaptive)',
          subtitle: currentSource?.resolution.isNotEmpty == true
              ? currentSource!.resolution
              : 'Hardware-accelerated optimal stream',
          badge: currentSource?.format ?? 'DIRECT',
          isSelected: true,
          autofocus:
              sources.length <= 1 ||
              initialSection == PlayerServerSheetSection.quality,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      const SizedBox(height: 10),
    ];

    return TvPopupScope(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 20,
            vertical: isCompact ? 10 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        sheetIcon,
                        color: theme.colorScheme.primary,
                        size: isCompact ? 18 : 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sheetTitle,
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: tokens.textSecondary,
                      size: isCompact ? 20 : 24,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 8 : 12),

              // Content List
              Expanded(
                child: ListView(
                  clipBehavior: Clip.none,
                  cacheExtent: 350.0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  children: [
                    if (initialSection == PlayerServerSheetSection.quality) ...[
                      ...qualitiesSection,
                      ...serversSection,
                    ] else ...[
                      ...serversSection,
                      ...qualitiesSection,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerTile(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
    int idx,
    bool isCompact,
  ) {
    final src = sources[idx];
    final isSelected = idx == currentSourceIndex;
    final detailsList = [
      if (src.formattedSize.isNotEmpty) src.formattedSize,
      if (src.codec != null && src.codec!.isNotEmpty) src.codec!,
      if (src.resolution.isNotEmpty) src.resolution,
    ];

    return TvFocusable(
      autofocus: isSelected,
      scaleFactor: 1.04,
      shape: tokens.shapeSm,
      borderRadius: tokens.borderRadiusSm,
      onTap: () {
        Navigator.of(context).pop();
        if (idx != currentSourceIndex) {
          onSourceSelected(idx);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 8 : 12,
        ),
        decoration: tokens.getShapeDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : tokens.surfaceCard.withValues(alpha: 0.5),
          radius: tokens.cardRadius * 0.7,
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : tokens.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? theme.colorScheme.primary : tokens.textMuted,
              size: isCompact ? 18 : 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        src.server != null && src.server!.isNotEmpty
                            ? src.server!
                            : 'Server ${idx + 1}',
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 13 : 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          radius: tokens.cardRadius * 0.4,
                        ),
                        child: Text(
                          src.quality,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: isCompact ? 10 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (src.format.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: tokens.cardRadius * 0.4,
                          ),
                          child: Text(
                            src.format,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isCompact ? 9 : 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (detailsList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        detailsList.join(' • '),
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: isCompact ? 11 : 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityTile({
    required BuildContext context,
    required ThemeData theme,
    required AppDesignTokens tokens,
    required bool isCompact,
    required String label,
    String? subtitle,
    String? badge,
    required bool isSelected,
    required bool autofocus,
    required VoidCallback onTap,
  }) {
    return TvFocusable(
      autofocus: autofocus,
      scaleFactor: 1.04,
      shape: tokens.shapeSm,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 14,
          vertical: isCompact ? 8 : 12,
        ),
        decoration: tokens.getShapeDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : tokens.surfaceCard.withValues(alpha: 0.5),
          radius: tokens.cardRadius * 0.7,
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : tokens.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? theme.colorScheme.primary : tokens.textMuted,
              size: isCompact ? 18 : 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 13 : 14,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                            radius: tokens.cardRadius * 0.4,
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: isCompact ? 10 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: isCompact ? 11 : 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
