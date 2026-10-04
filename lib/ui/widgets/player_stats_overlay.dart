import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../theme/app_tokens.dart';
import 'tv_focusable.dart';

/// Real-time "Stats for Nerds" semi-transparent diagnostic overlay.
class PlayerStatsOverlay extends StatefulWidget {
  final Player player;
  final MediaItem mediaItem;
  final StreamSource streamSource;
  final bool isNightMode;
  final double playbackSpeed;
  final VoidCallback onClose;

  const PlayerStatsOverlay({
    super.key,
    required this.player,
    required this.mediaItem,
    required this.streamSource,
    this.isNightMode = false,
    this.playbackSpeed = 1.0,
    required this.onClose,
  });

  @override
  State<PlayerStatsOverlay> createState() => _PlayerStatsOverlayState();
}

class _PlayerStatsOverlayState extends State<PlayerStatsOverlay> {
  Timer? _refreshTimer;
  Map<String, String> _mpvStats = {};

  @override
  void initState() {
    super.initState();
    _fetchMpvStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _fetchMpvStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMpvStats() async {
    if (widget.player.platform is NativePlayer) {
      try {
        final native = widget.player.platform as NativePlayer;
        final codec = await native.getProperty('video-format');
        final audioCodec = await native.getProperty('audio-codec-name');
        final fps = await native.getProperty('estimated-vf-fps');
        final dropped = await native.getProperty('frame-drop-count');
        final hwdec = await native.getProperty('hwdec-current');
        final bitrate = await native.getProperty('video-bitrate');

        if (mounted) {
          setState(() {
            _mpvStats = {
              if (codec.isNotEmpty) 'codec': codec,
              if (audioCodec.isNotEmpty) 'audioCodec': audioCodec,
              if (fps.isNotEmpty) 'fps': fps,
              if (dropped.isNotEmpty) 'dropped': dropped,
              if (hwdec.isNotEmpty) 'hwdec': hwdec,
              if (bitrate.isNotEmpty) 'bitrate': bitrate,
            };
          });
        }
      } catch (_) {}
    }
  }

  String _formatBitrate(String? raw) {
    if (raw == null) return 'N/A';
    final bps = double.tryParse(raw);
    if (bps == null || bps <= 0) return 'N/A';
    final mbps = bps / (1000 * 1000);
    return '${mbps.toStringAsFixed(2)} Mbps';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final state = widget.player.state;
    final width = state.width ?? 0;
    final height = state.height ?? 0;
    final bufferSec = state.buffer.inSeconds;
    final posSec = state.position.inSeconds;
    final aheadSec = (bufferSec - posSec).clamp(0, 9999);

    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 320,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: tokens.getShapeDecoration(
          color: tokens.canvasBackground.withValues(alpha: 0.88),
          radius: tokens.cardRadius,
          side: BorderSide(
            color: tokens.borderSubtle.withValues(alpha: 0.8),
            width: 1.2,
          ),
          shadows: [
            BoxShadow(
              color: tokens.shadowColor.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: tokens.primaryAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'STATS FOR NERDS',
                  style: TextStyle(
                    color: tokens.primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                TvFocusable(
                  onTap: widget.onClose,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.surfaceElevated,
                        radius: tokens.cardRadius,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: tokens.textSecondary,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Rows
            _buildStatRow('Media ID', widget.mediaItem.id),
            _buildStatRow(
              'Stream Format',
              widget.streamSource.format.toUpperCase(),
            ),
            _buildStatRow(
              'Resolution',
              width > 0 && height > 0 ? '${width}x$height' : 'Dynamic / Auto',
            ),
            _buildStatRow(
              'FPS',
              _mpvStats['fps'] != null
                  ? '${double.tryParse(_mpvStats['fps']!)?.toStringAsFixed(2) ?? _mpvStats['fps']} fps'
                  : 'Native',
            ),
            _buildStatRow(
              'Video Codec',
              _mpvStats['codec']?.toUpperCase() ?? 'Auto Detected',
            ),
            _buildStatRow(
              'Audio Codec',
              _mpvStats['audioCodec']?.toUpperCase() ?? 'Stereo / Passthrough',
            ),
            _buildStatRow('Bitrate', _formatBitrate(_mpvStats['bitrate'])),
            _buildStatRow(
              'Hardware Decoder',
              _mpvStats['hwdec'] ?? 'Active GPU',
            ),
            _buildStatRow('Dropped Frames', _mpvStats['dropped'] ?? '0'),
            _buildStatRow('Ahead Buffer', '${aheadSec}s ($bufferSec total)'),
            _buildStatRow('Playback Speed', '${widget.playbackSpeed}x'),
            _buildStatRow(
              'Night Mode (DRC)',
              widget.isNightMode ? 'Enabled' : 'Disabled',
            ),
            _buildStatRow('Volume', '${state.volume.toInt()}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
