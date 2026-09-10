import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../providers/cast_provider.dart';

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

class _CastDialogState extends State<CastDialog> with SingleTickerProviderStateMixin {
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
        maxWidth: 600,
      ),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cast.isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cast.isConnected ? 'Casting Active' : 'Cast to Device',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          cast.isConnected
                              ? (cast.connectedDevice?.name ?? 'Connected')
                              : (cast.isDiscovering ? 'Scanning local Wi-Fi...' : 'Select a device'),
                          style: TextStyle(
                            fontSize: 12,
                            color: cast.isConnected ? Colors.greenAccent : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (cast.isDiscovering)
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
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
                            const Text(
                              'Scanning',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                      tooltip: 'Refresh devices',
                      onPressed: () => cast.startDiscovery(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Error Notice Banner (if any)
            if (cast.errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.red.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cast.errorMessage!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(
                                    Icons.cast_connected_rounded,
                                    color: Colors.greenAccent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cast.connectedDevice!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cast.currentMediaItem?.title ?? 'Ready to stream',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
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
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: theme.colorScheme.primary,
                                  inactiveTrackColor: Colors.white24,
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
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(cast.position),
                                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                                    ),
                                    Text(
                                      _formatDuration(cast.duration),
                                      style: const TextStyle(fontSize: 11, color: Colors.white60),
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
                                  icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                                  onPressed: () {
                                    final cur = cast.position;
                                    cast.seek(cur - const Duration(seconds: 10));
                                  },
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => cast.playOrPause(),
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      cast.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                                  onPressed: () {
                                    final cur = cast.position;
                                    cast.seek(cur + const Duration(seconds: 10));
                                  },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.stop_rounded, color: Colors.white70),
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
                        const Text(
                          'Available Devices',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: Colors.white54,
                          ),
                        ),
                        const Spacer(),
                        if (cast.discoveredDevices.isNotEmpty)
                          Text(
                            '${cast.discoveredDevices.length} found',
                            style: const TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (cast.discoveredDevices.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              cast.isDiscovering ? Icons.radar_rounded : Icons.tv_off_rounded,
                              size: 44,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              cast.isDiscovering
                                  ? 'Searching for Chromecast, DLNA & AirPlay devices...'
                                  : 'No cast devices found',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ensure your TV, Chromecast, or streaming box is powered on and connected to the same Wi-Fi network.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                                height: 1.4,
                              ),
                            ),
                            if (!cast.isDiscovering) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => cast.startDiscovery(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
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
                          final isTargetConnected = cast.connectedDevice?.id == device.id;
                          final isConnectingThis = _connectingDevice?.id == device.id && cast.isConnecting;

                          return Container(
                            decoration: BoxDecoration(
                              color: isTargetConnected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isTargetConnected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.08),
                                width: isTargetConnected ? 1.5 : 1.0,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getDeviceIcon(device.protocol),
                                  color: isTargetConnected ? theme.colorScheme.primary : Colors.white70,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                device.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isTargetConnected ? theme.colorScheme.primary : Colors.white,
                                ),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getProtocolLabel(device.protocol),
                                      style: const TextStyle(fontSize: 9, color: Colors.white60),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    device.address.address,
                                    style: const TextStyle(fontSize: 11, color: Colors.white30),
                                  ),
                                ],
                              ),
                              trailing: isConnectingThis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : isTargetConnected
                                      ? const Icon(Icons.check_circle_rounded, color: Colors.greenAccent)
                                      : const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                              onTap: isConnectingThis
                                  ? null
                                  : () async {
                                      if (widget.mediaItem != null && widget.streamSource != null) {
                                        setState(() => _connectingDevice = device);
                                        final messenger = ScaffoldMessenger.of(context);
                                        final ok = await cast.connectAndCast(
                                          device: device,
                                          item: widget.mediaItem!,
                                          source: widget.streamSource!,
                                          startPosition: widget.startPosition,
                                          subtitles: widget.subtitles,
                                        );
                                        if (mounted) {
                                          setState(() => _connectingDevice = null);
                                          if (ok) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text('Casting to ${device.name}'),
                                                backgroundColor: Colors.green.shade800,
                                              ),
                                            );
                                          }
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Select a title or video to start casting'),
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
