import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/cast_provider.dart';
import '../theme/app_tokens.dart';

class CastDialog extends StatefulWidget {
  final MediaItem? mediaItem;
  final StreamSource? streamSource;
  final Duration? startPosition;
  final List<SubtitleOption>? subtitles;

  const CastDialog({
    super.key,
    this.mediaItem,
    this.streamSource,
    this.startPosition,
    this.subtitles,
  });

  static Future<void> show(
    BuildContext context, {
    MediaItem? mediaItem,
    StreamSource? streamSource,
    Duration? startPosition,
    List<SubtitleOption>? subtitles,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CastDialog(
        mediaItem: mediaItem,
        streamSource: streamSource,
        startPosition: startPosition,
        subtitles: subtitles,
      ),
    );
  }

  @override
  State<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends State<CastDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  CastDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cast = context.read<CastProvider>();
      if (!cast.isConnected && !cast.isDiscovering) {
        cast.startDiscovery();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  IconData _getDeviceIcon(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.chromecast:
        return Icons.cast_rounded;
      case CastProtocol.airplay:
        return Icons.airplay_rounded;
      case CastProtocol.dlna:
        return Icons.tv_rounded;
    }
  }

  String _getProtocolLabel(CastProtocol protocol) {
    switch (protocol) {
      case CastProtocol.chromecast:
        return 'Chromecast';
      case CastProtocol.airplay:
        return 'AirPlay';
      case CastProtocol.dlna:
        return 'DLNA / Smart TV';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cast = context.watch<CastProvider>();
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
        maxWidth: 600,
      ),
      margin: const EdgeInsets.all(12),
      decoration: tokens.getShapeDecoration(
        color: tokens.surfaceElevated,
        radius: tokens.cardRadius * 1.35,
        side: BorderSide(color: tokens.borderSubtle),
        shadows: [
          BoxShadow(
            color: tokens.shadowColor.withValues(alpha: 0.7),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: tokens.clipShape(
        radius: tokens.cardRadius * 1.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: tokens.surfaceElevated.withValues(alpha: 0.5),
                border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cast_connected_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cast to Device',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chromecast • DLNA • AirPlay',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cast.isDiscovering)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: context.tokens.borderRadiusSm,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Scanning',
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: tokens.textSecondary,
                      ),
                      tooltip: 'Refresh devices',
                      onPressed: () => cast.startDiscovery(),
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: tokens.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Error Notice Banner (if any)
            if (cast.errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: tokens.errorColor.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: tokens.errorColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cast.errorMessage!,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ACTIVE SESSION CONTROLLER (If already connected)
                    if (cast.isConnected && cast.connectedDevice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: tokens.shadowColor.withValues(alpha: 0.5),
                          borderRadius: tokens.borderRadiusMd,
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.cast_connected_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cast.connectedDevice!.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: tokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cast.currentMediaItem?.title ??
                                            'Ready to stream',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: tokens.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.link_off_rounded,
                                    color: tokens.errorColor,
                                  ),
                                  tooltip: 'Disconnect',
                                  onPressed: () async {
                                    await cast.disconnect();
                                  },
                                ),
                              ],
                            ),

                            // Playback Progress & Scrubbing (if duration > 0)
                            if (cast.duration > Duration.zero) ...[
                              const SizedBox(height: 14),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: tokens.borderSubtle,
                                  thumbColor: theme.colorScheme.primary,
                                ),
                                child: Slider(
                                  value: cast.position.inSeconds
                                      .clamp(0, cast.duration.inSeconds)
                                      .toDouble(),
                                  max: cast.duration.inSeconds.toDouble(),
                                  onChanged: (val) {
                                    cast.seek(Duration(seconds: val.round()));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(cast.position),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(cast.duration),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Transport Control Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.replay_10_rounded,
                                    color: tokens.textPrimary,
                                  ),
                                  onPressed: () {
                                    final cur = cast.position;
                                    cast.seek(
                                      cur - const Duration(seconds: 10),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => cast.playOrPause(),
                                  borderRadius: tokens.borderRadiusPill,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      cast.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: theme.colorScheme.onPrimary,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(
                                    Icons.forward_10_rounded,
                                    color: tokens.textPrimary,
                                  ),
                                  onPressed: () {
                                    final cur = cast.position;
                                    cast.seek(
                                      cur + const Duration(seconds: 10),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: Icon(
                                    Icons.stop_rounded,
                                    color: tokens.textSecondary,
                                  ),
                                  onPressed: () => cast.stop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // DEVICE LIST SECTION
                    Row(
                      children: [
                        Text(
                          'Available Devices',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: tokens.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (cast.discoveredDevices.isNotEmpty)
                          Text(
                            '${cast.discoveredDevices.length} found',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (cast.discoveredDevices.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard.withValues(alpha: 0.35),
                          borderRadius: tokens.borderRadiusMd,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              cast.isDiscovering
                                  ? Icons.radar_rounded
                                  : Icons.tv_off_rounded,
                              size: 44,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              cast.isDiscovering
                                  ? 'Searching for Chromecast, DLNA & AirPlay devices...'
                                  : 'No cast devices found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: tokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Ensure your TV, Chromecast, or streaming box is powered on and connected to the same Wi-Fi network.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: tokens.textMuted,
                                height: 1.4,
                              ),
                            ),
                            if (!cast.isDiscovering) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => cast.startDiscovery(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: tokens.borderRadiusSm,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                ),
                                label: const Text('Scan Again'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cast.discoveredDevices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final device = cast.discoveredDevices[idx];
                          final isTargetConnected =
                              cast.connectedDevice?.id == device.id;
                          final isConnectingThis =
                              _connectingDevice?.id == device.id &&
                              cast.isConnecting;

                          return Container(
                            decoration: BoxDecoration(
                              color: isTargetConnected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    )
                                  : tokens.surfaceCard.withValues(alpha: 0.4),
                              borderRadius: tokens.borderRadiusSm,
                              border: Border.all(
                                color: isTargetConnected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.5,
                                      )
                                    : tokens.borderSubtle,
                                width: isTargetConnected ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tokens.surfaceElevated,
                                  borderRadius: tokens.borderRadiusSm,
                                ),
                                child: Icon(
                                  _getDeviceIcon(device.protocol),
                                  color: isTargetConnected
                                      ? theme.colorScheme.primary
                                      : tokens.textSecondary,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                device.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isTargetConnected
                                      ? theme.colorScheme.primary
                                      : tokens.textPrimary,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceElevated,
                                      borderRadius: tokens.borderRadiusXs,
                                    ),
                                    child: Text(
                                      _getProtocolLabel(device.protocol),
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: tokens.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    device.address.address,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isConnectingThis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : isTargetConnected
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: theme.colorScheme.primary,
                                    )
                                  : Icon(
                                      Icons.chevron_right_rounded,
                                      color: tokens.textMuted,
                                    ),
                              onTap: isConnectingThis
                                  ? null
                                  : () async {
                                      if (widget.mediaItem != null &&
                                          widget.streamSource != null) {
                                        setState(
                                          () => _connectingDevice = device,
                                        );
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        final ok = await cast.connectAndCast(
                                          device: device,
                                          item: widget.mediaItem!,
                                          source: widget.streamSource!,
                                          startPosition: widget.startPosition,
                                          subtitles: widget.subtitles,
                                        );
                                        if (mounted) {
                                          setState(
                                            () => _connectingDevice = null,
                                          );
                                          if (ok) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Casting to ${device.name}',
                                                ),
                                                backgroundColor:
                                                    theme.colorScheme.primary,
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Select a title or video to start casting',
                                                ),
                                              ),
                                            );
                                      }
                                    },
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
