import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../models/stream_source.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

enum PlayerServerSheetSection { all, servers, quality }

class _ProviderGroup {
  final String providerName;
  final String providerId;
  final List<({int originalIndex, StreamSource source})> items;

  _ProviderGroup({
    required this.providerName,
    required this.providerId,
    required this.items,
  });

  bool hasActiveSource(int currentIdx) =>
      items.any((i) => i.originalIndex == currentIdx);

  String summaryLabel() {
    final count = items.length;
    final qualities = items
        .map(
          (i) => i.source.resolution.isNotEmpty
              ? i.source.resolution
              : i.source.quality,
        )
        .where((q) => q.isNotEmpty)
        .toSet()
        .take(3)
        .join(', ');
    final streamWord = count == 1 ? 'stream' : 'streams';
    if (qualities.isNotEmpty) {
      return '$count $streamWord • $qualities';
    }
    return '$count $streamWord available';
  }
}

/// Centered modal popup dialog for selecting streaming servers.
/// Step 1: Choose provider (e.g. 4K HD Hub, MovieBox, Dramachi, CircleFTP).
/// Step 2: Choose stream if multiple streams are available for that provider.
class PlayerServerDialog extends StatefulWidget {
  final List<StreamSource> sources;
  final int currentSourceIndex;
  final ValueChanged<int> onSourceSelected;

  const PlayerServerDialog({
    super.key,
    required this.sources,
    required this.currentSourceIndex,
    required this.onSourceSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required int currentSourceIndex,
    required ValueChanged<int> onSourceSelected,
  }) {
    final tokens = context.tokens;
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: tokens.shadowColor.withValues(alpha: 0.7),
      builder: (ctx) => PlayerServerDialog(
        sources: sources,
        currentSourceIndex: currentSourceIndex,
        onSourceSelected: onSourceSelected,
      ),
    );
  }

  @override
  State<PlayerServerDialog> createState() => _PlayerServerDialogState();
}

class _PlayerServerDialogState extends State<PlayerServerDialog> {
  String? _selectedProvider;

  Map<String, _ProviderGroup> _buildGroups() {
    final Map<String, _ProviderGroup> groups = {};
    for (int i = 0; i < widget.sources.length; i++) {
      final src = widget.sources[i];
      final pName = src.effectiveProviderName;
      final pId = src.effectiveProviderId;
      groups.putIfAbsent(
        pName,
        () => _ProviderGroup(providerName: pName, providerId: pId, items: []),
      );
      groups[pName]!.items.add((originalIndex: i, source: src));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenHeight < 550 || screenWidth < 500;
    final dialogWidth = (screenWidth * 0.90).clamp(320.0, 520.0);
    final dialogMaxHeight = (screenHeight * 0.85).clamp(240.0, 540.0);

    final groups = _buildGroups();
    final selectedGroup = _selectedProvider != null
        ? groups[_selectedProvider]
        : null;

    return PopScope(
      canPop: _selectedProvider == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedProvider != null) {
          setState(() {
            _selectedProvider = null;
          });
        }
      },
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogMaxHeight),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius + 8,
              side: BorderSide(color: tokens.borderSubtle, width: 1),
            ),
            child: TvPopupScope(
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 20,
                    vertical: isCompact ? 12 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (_selectedProvider != null) ...[
                                  TvFocusable(
                                    borderRadius: tokens.borderRadiusPill,
                                    onTap: () {
                                      setState(() {
                                        _selectedProvider = null;
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        isCompact ? 4 : 6,
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: tokens.textPrimary,
                                        size: isCompact ? 20 : 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ] else ...[
                                  Icon(
                                    Icons.dns_rounded,
                                    color: theme.colorScheme.primary,
                                    size: isCompact ? 18 : 22,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedProvider != null
                                            ? _selectedProvider!
                                            : 'Select Provider',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 15 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _selectedProvider != null
                                            ? 'Choose a stream from this provider'
                                            : '${groups.length} ${groups.length == 1 ? 'server' : 'servers'} available',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: isCompact ? 11 : 12,
                                          color: tokens.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TvFocusable(
                            borderRadius: tokens.borderRadiusPill,
                            onTap: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isCompact ? 4 : 6),
                              child: Icon(
                                Icons.close_rounded,
                                color: tokens.textSecondary,
                                size: isCompact ? 20 : 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 10 : 14),

                      // List: Step 1 (Providers) or Step 2 (Streams)
                      Flexible(
                        child: widget.sources.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No streaming servers available',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : (selectedGroup != null
                                  ? _buildStreamsList(
                                      context,
                                      theme,
                                      tokens,
                                      selectedGroup,
                                      isCompact,
                                    )
                                  : _buildProvidersList(
                                      context,
                                      theme,
                                      tokens,
                                      groups.values.toList(),
                                      isCompact,
                                    )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProvidersList(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
    List<_ProviderGroup> groups,
    bool isCompact,
  ) {
    final hasActiveGroup = groups.any(
      (g) => g.hasActiveSource(widget.currentSourceIndex),
    );

    return ListView.builder(
      key: const ValueKey('player_servers_providers_list'),
      clipBehavior: Clip.none,
      cacheExtent: 350.0,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      itemCount: groups.length,
      itemBuilder: (ctx, idx) {
        final group = groups[idx];
        final isActive = group.hasActiveSource(widget.currentSourceIndex);
        final count = group.items.length;

        return Padding(
          padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
          child: TvFocusable(
            autofocus: hasActiveGroup ? isActive : (idx == 0),
            scaleFactor: 1.04,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              if (count == 1) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                widget.onSourceSelected(group.items.first.originalIndex);
              } else {
                setState(() {
                  _selectedProvider = group.providerName;
                });
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 14,
                vertical: isCompact ? 10 : 14,
              ),
              decoration: tokens.getShapeDecoration(
                color: isActive
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : tokens.surfaceCard.withValues(alpha: 0.5),
                radius: tokens.cardRadius * 0.7,
                side: BorderSide(
                  color: isActive
                      ? theme.colorScheme.primary
                      : tokens.borderSubtle,
                  width: isActive ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.cloud_outlined,
                    color: isActive
                        ? theme.colorScheme.primary
                        : tokens.textMuted,
                    size: isCompact ? 18 : 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.providerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 13 : 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: tokens.surfaceElevated,
                                radius: tokens.cardRadius * 0.4,
                              ),
                              child: Text(
                                'Server ${idx + 1}',
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: isCompact ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: tokens.getShapeDecoration(
                                color: isActive
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.2,
                                      )
                                    : tokens.surfaceElevated,
                                radius: tokens.cardRadius * 0.4,
                              ),
                              child: Text(
                                '$count ${count == 1 ? 'stream' : 'streams'}',
                                style: TextStyle(
                                  color: isActive
                                      ? theme.colorScheme.primary
                                      : tokens.textSecondary,
                                  fontSize: isCompact ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),
                        Text(
                          group.summaryLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: isCompact ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tokens.textSecondary,
                    size: isCompact ? 18 : 22,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreamsList(
    BuildContext context,
    ThemeData theme,
    AppDesignTokens tokens,
    _ProviderGroup group,
    bool isCompact,
  ) {
    final hasSelectedInGroup = group.items.any(
      (it) => it.originalIndex == widget.currentSourceIndex,
    );

    return ListView.builder(
      key: ValueKey(
        'player_servers_streams_${group.providerId}_${group.providerName}',
      ),
      clipBehavior: Clip.none,
      cacheExtent: 350.0,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      itemCount: group.items.length,
      itemBuilder: (ctx, idx) {
        final item = group.items[idx];
        final src = item.source;
        final isSelected = item.originalIndex == widget.currentSourceIndex;
        final detailsList = [
          if (src.formattedSize.isNotEmpty) src.formattedSize,
          if (src.codec != null && src.codec!.isNotEmpty) src.codec!,
          if (src.resolution.isNotEmpty) src.resolution,
        ];

        return Padding(
          padding: EdgeInsets.only(bottom: isCompact ? 6 : 8),
          child: TvFocusable(
            autofocus: hasSelectedInGroup ? isSelected : (idx == 0),
            scaleFactor: 1.04,
            shape: tokens.shapeSm,
            borderRadius: tokens.borderRadiusSm,
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
              if (item.originalIndex != widget.currentSourceIndex) {
                widget.onSourceSelected(item.originalIndex);
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
                  color: isSelected
                      ? theme.colorScheme.primary
                      : tokens.borderSubtle,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : tokens.textMuted,
                    size: isCompact ? 18 : 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                src.server != null && src.server!.isNotEmpty
                                    ? src.server!
                                    : 'Stream ${idx + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : tokens.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isCompact ? 13 : 14,
                                ),
                              ),
                            ),
                            if (src.quality.isNotEmpty) ...[
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
                            ],
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
          ),
        );
      },
    );
  }
}

/// Centered modal popup dialog for selecting video quality tiers.
class PlayerQualityDialog extends StatelessWidget {
  final List<VideoTrack> videoTracks;
  final VideoTrack? activeVideoTrack;
  final List<String> fallbackQualities;
  final String currentQuality;
  final ValueChanged<VideoTrack> onVideoTrackSelected;

  const PlayerQualityDialog({
    super.key,
    this.videoTracks = const [],
    this.activeVideoTrack,
    this.fallbackQualities = const [],
    this.currentQuality = '',
    required this.onVideoTrackSelected,
  });

  static Future<void> show(
    BuildContext context, {
    List<VideoTrack> videoTracks = const [],
    VideoTrack? activeVideoTrack,
    List<String> fallbackQualities = const [],
    String currentQuality = '',
    required ValueChanged<VideoTrack> onVideoTrackSelected,
  }) {
    final tokens = context.tokens;
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: tokens.shadowColor.withValues(alpha: 0.7),
      builder: (ctx) => PlayerQualityDialog(
        videoTracks: videoTracks,
        activeVideoTrack: activeVideoTrack,
        fallbackQualities: fallbackQualities,
        currentQuality: currentQuality,
        onVideoTrackSelected: onVideoTrackSelected,
      ),
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
    final dialogWidth = (screenWidth * 0.90).clamp(320.0, 500.0);
    final dialogMaxHeight = (screenHeight * 0.85).clamp(240.0, 520.0);

    final selectableVideoTracks = videoTracks.where((t) {
      final l = (t.title ?? t.id).toLowerCase();
      return !l.contains('(no)') && l != 'no' && t.id != 'auto';
    }).toList();

    final hasMultipleTracks = selectableVideoTracks.length > 1;
    final hasFallbackQualities = fallbackQualities.length > 1;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: dialogMaxHeight),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius + 8,
            side: BorderSide(color: tokens.borderSubtle, width: 1),
          ),
          child: TvPopupScope(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 14 : 20,
                  vertical: isCompact ? 12 : 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.high_quality_rounded,
                                color: theme.colorScheme.primary,
                                size: isCompact ? 18 : 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video Quality',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: isCompact ? 15 : 18,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TvFocusable(
                          borderRadius: tokens.borderRadiusPill,
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.all(isCompact ? 4 : 6),
                            child: Icon(
                              Icons.close_rounded,
                              color: tokens.textSecondary,
                              size: isCompact ? 20 : 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? 8 : 12),

                    // Quality choices list
                    Flexible(
                      child: ListView(
                        clipBehavior: Clip.none,
                        cacheExtent: 350.0,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        children: [
                          if (hasMultipleTracks) ...[
                            () {
                              final hasSelectedTrack = selectableVideoTracks
                                  .any((t) => activeVideoTrack?.id == t.id);
                              final isAutoActive =
                                  activeVideoTrack == null ||
                                  activeVideoTrack?.id == 'auto' ||
                                  !hasSelectedTrack;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildQualityTile(
                                    context: context,
                                    theme: theme,
                                    tokens: tokens,
                                    isCompact: isCompact,
                                    label: 'Auto (Adaptive Bitrate)',
                                    subtitle:
                                        'Best network-responsive playback',
                                    badge: 'Recommended',
                                    isSelected: isAutoActive,
                                    autofocus: isAutoActive,
                                    onTap: () {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                      onVideoTrackSelected(VideoTrack.auto());
                                    },
                                  ),
                                  SizedBox(height: isCompact ? 6 : 8),
                                  for (final track
                                      in selectableVideoTracks) ...[
                                    _buildQualityTile(
                                      context: context,
                                      theme: theme,
                                      tokens: tokens,
                                      isCompact: isCompact,
                                      label: formatTrackLabel(
                                        track,
                                        fallbackQualities: fallbackQualities,
                                      ),
                                      subtitle:
                                          track.bitrate != null &&
                                              track.bitrate! > 0
                                          ? '${(track.bitrate! / 1000000).toStringAsFixed(1)} Mbps'
                                          : (track.h != null && track.h! >= 1080
                                                ? 'Full HD (Higher bandwidth)'
                                                : (track.h != null &&
                                                          track.h! >= 720
                                                      ? 'Smooth playback (Recommended)'
                                                      : (track.h != null &&
                                                                track.h! > 0
                                                            ? 'Data saver / Lower bandwidth'
                                                            : null))),
                                      badge: track.h != null && track.h! >= 1080
                                          ? 'FHD'
                                          : (track.h != null && track.h! >= 720
                                                ? 'HD'
                                                : (track.h != null &&
                                                          track.h! > 0
                                                      ? 'SD'
                                                      : null)),
                                      isSelected:
                                          activeVideoTrack?.id == track.id,
                                      autofocus:
                                          !isAutoActive &&
                                          activeVideoTrack?.id == track.id,
                                      onTap: () {
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.of(context).pop();
                                        }
                                        onVideoTrackSelected(track);
                                      },
                                    ),
                                    SizedBox(height: isCompact ? 6 : 8),
                                  ],
                                ],
                              );
                            }(),
                          ] else if (hasFallbackQualities) ...[
                            () {
                              final matchingFallbackIndex = fallbackQualities
                                  .indexWhere((q) {
                                    final h =
                                        int.tryParse(
                                          q.replaceAll(RegExp(r'[^0-9]'), ''),
                                        ) ??
                                        0;
                                    if (activeVideoTrack != null &&
                                        activeVideoTrack!.id != 'auto') {
                                      return (h > 0 &&
                                          activeVideoTrack!.h == h);
                                    }
                                    return h > 0 &&
                                        currentQuality.toLowerCase().contains(
                                          h.toString(),
                                        ) &&
                                        !currentQuality.toLowerCase().contains(
                                          'auto',
                                        );
                                  });
                              final isAutoActive =
                                  (activeVideoTrack?.id == 'auto') ||
                                  (activeVideoTrack == null &&
                                      matchingFallbackIndex == -1) ||
                                  currentQuality.toLowerCase().contains('auto');

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildQualityTile(
                                    context: context,
                                    theme: theme,
                                    tokens: tokens,
                                    isCompact: isCompact,
                                    label: 'Auto (Adaptive Bitrate)',
                                    subtitle:
                                        'Best network-responsive playback',
                                    badge: 'Recommended',
                                    isSelected: isAutoActive,
                                    autofocus: isAutoActive,
                                    onTap: () {
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                      onVideoTrackSelected(VideoTrack.auto());
                                    },
                                  ),
                                  SizedBox(height: isCompact ? 6 : 8),
                                  for (
                                    int qIdx = 0;
                                    qIdx < fallbackQualities.length;
                                    qIdx++
                                  ) ...[
                                    () {
                                      final q = fallbackQualities[qIdx];
                                      final h =
                                          int.tryParse(
                                            q.replaceAll(RegExp(r'[^0-9]'), ''),
                                          ) ??
                                          0;
                                      final trackId = (qIdx + 1).toString();
                                      final matchingTrack =
                                          selectableVideoTracks
                                              .where(
                                                (t) =>
                                                    t.h == h || t.id == trackId,
                                              )
                                              .firstOrNull;
                                      final targetTrack =
                                          matchingTrack ??
                                          VideoTrack(
                                            trackId,
                                            q,
                                            null,
                                            h: h > 0 ? h : null,
                                          );
                                      final isSelected =
                                          qIdx == matchingFallbackIndex;
                                      final badge = h >= 1080
                                          ? 'FHD'
                                          : (h >= 720
                                                ? 'HD'
                                                : (h > 0 ? 'SD' : null));
                                      final subtitle = h >= 1080
                                          ? 'Full HD (Higher bandwidth)'
                                          : (h >= 720
                                                ? 'Smooth playback (Recommended)'
                                                : (h > 0
                                                      ? 'Data saver / Lower bandwidth'
                                                      : null));

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
                                            autofocus: isSelected,
                                            onTap: () {
                                              if (Navigator.of(context)
                                                  .canPop()) {
                                                Navigator.of(context).pop();
                                              }
                                              onVideoTrackSelected(targetTrack);
                                            },
                                          ),
                                          SizedBox(height: isCompact ? 6 : 8),
                                        ],
                                      );
                                    }(),
                                  ],
                                ],
                              );
                            }(),
                          ] else ...[
                            _buildQualityTile(
                              context: context,
                              theme: theme,
                              tokens: tokens,
                              isCompact: isCompact,
                              label: currentQuality.isNotEmpty
                                  ? currentQuality
                                  : 'Auto (Adaptive)',
                              subtitle: 'Hardware-accelerated optimal stream',
                              badge: 'DIRECT',
                              isSelected: true,
                              autofocus: true,
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 13 : 14,
                          ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

/// Backwards-compatible facade for modal server & quality selection.
class PlayerServerSheet extends StatelessWidget {
  final List<StreamSource> sources;
  final int currentSourceIndex;
  final ValueChanged<int>? onSourceSelected;
  final List<VideoTrack> videoTracks;
  final VideoTrack? activeVideoTrack;
  final ValueChanged<VideoTrack>? onVideoTrackSelected;
  final PlayerServerSheetSection initialSection;

  const PlayerServerSheet({
    super.key,
    this.sources = const [],
    this.currentSourceIndex = 0,
    this.onSourceSelected,
    this.videoTracks = const [],
    this.activeVideoTrack,
    this.onVideoTrackSelected,
    this.initialSection = PlayerServerSheetSection.servers,
  });

  static Future<void> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required int currentSourceIndex,
    required ValueChanged<int> onSourceSelected,
    List<VideoTrack> videoTracks = const [],
    VideoTrack? activeVideoTrack,
    ValueChanged<VideoTrack>? onVideoTrackSelected,
    PlayerServerSheetSection initialSection = PlayerServerSheetSection.servers,
  }) {
    if (initialSection == PlayerServerSheetSection.quality &&
        onVideoTrackSelected != null) {
      final currentSource =
          sources.isNotEmpty &&
              currentSourceIndex >= 0 &&
              currentSourceIndex < sources.length
          ? sources[currentSourceIndex]
          : null;
      return PlayerQualityDialog.show(
        context,
        videoTracks: videoTracks,
        activeVideoTrack: activeVideoTrack,
        fallbackQualities: currentSource?.availableQualities ?? const [],
        currentQuality: currentSource?.quality ?? '',
        onVideoTrackSelected: onVideoTrackSelected,
      );
    }

    return PlayerServerDialog.show(
      context,
      sources: sources,
      currentSourceIndex: currentSourceIndex,
      onSourceSelected: onSourceSelected,
    );
  }

  static String formatTrackLabel(
    VideoTrack track, {
    List<String> fallbackQualities = const [],
  }) {
    return PlayerQualityDialog.formatTrackLabel(
      track,
      fallbackQualities: fallbackQualities,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (initialSection == PlayerServerSheetSection.quality &&
        onVideoTrackSelected != null) {
      final currentSource =
          sources.isNotEmpty &&
              currentSourceIndex >= 0 &&
              currentSourceIndex < sources.length
          ? sources[currentSourceIndex]
          : null;
      return PlayerQualityDialog(
        videoTracks: videoTracks,
        activeVideoTrack: activeVideoTrack,
        fallbackQualities: currentSource?.availableQualities ?? const [],
        currentQuality: currentSource?.quality ?? '',
        onVideoTrackSelected: onVideoTrackSelected!,
      );
    }

    return PlayerServerDialog(
      sources: sources,
      currentSourceIndex: currentSourceIndex,
      onSourceSelected: onSourceSelected ?? (_) {},
    );
  }
}
