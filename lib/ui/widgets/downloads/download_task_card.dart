import 'package:flutter/material.dart';

import '../../../services/direct_stream_service.dart';
import '../../theme/app_tokens.dart';
import '../dpad/src/focusable.dart';
import '../tv_focusable.dart';

/// One row in the Downloads page.
///
/// Deliberately shows three different things that are easy to conflate: the
/// show/movie name, which episode or quality it is, and the actual file on disk.
/// Users troubleshooting a download need the file name — that is what identifies
/// the playable artefact and where it went.
class DownloadTaskCard extends StatelessWidget {
  const DownloadTaskCard({
    super.key,
    required this.task,
    this.onWatch,
    this.onExport,
    this.onDeleteFile,
    this.focusNode,
    this.onDirection,
  });

  final VideoDownloadTask task;

  /// Play the completed file locally. Only supplied for finished downloads.
  final VoidCallback? onWatch;

  /// Hand the finished file to another app / the share sheet.
  final VoidCallback? onExport;

  /// Delete the file from disk (completed rows only).
  final VoidCallback? onDeleteFile;

  final FocusNode? focusNode;
  final DpadDirectionCallback? onDirection;

  bool get _isActive =>
      task.status == DownloadTaskStatus.downloading ||
      task.status == DownloadTaskStatus.queued ||
      task.status == DownloadTaskStatus.paused;

  bool get _isComplete => task.status == DownloadTaskStatus.completed;

  bool get _isPaused => task.status == DownloadTaskStatus.paused;

  bool get _isFailed => task.status == DownloadTaskStatus.failed;

  String get _heading {
    final media = task.mediaTitle;
    if (media != null && media.trim().isNotEmpty) return media.trim();
    return task.title;
  }

  /// `S2E4 · 1080p · Server name`, skipping whatever is missing.
  String get _subheading {
    final parts = <String>[];
    if (task.season != null && task.episode != null) {
      parts.add('S${task.season}E${task.episode}');
    } else if (task.episode != null) {
      parts.add('Episode ${task.episode}');
    }
    if (task.quality != null && task.quality!.trim().isNotEmpty) {
      parts.add(task.quality!.trim());
    }
    if (task.serverName != null && task.serverName!.trim().isNotEmpty) {
      parts.add(task.serverName!.trim());
    }
    return parts.join(' · ');
  }

  /// Remaining time, or null when it cannot be estimated yet.
  String? get _etaLabel {
    if (task.speedBytesPerSec <= 0 || task.totalBytes <= 0) return null;
    final remaining = task.totalBytes - task.receivedBytes;
    if (remaining <= 0) return null;
    final seconds = remaining / task.speedBytesPerSec;
    if (seconds.isInfinite || seconds.isNaN) return null;
    if (seconds < 60) return '${seconds.round()}s left';
    if (seconds < 3600) return '${(seconds / 60).round()} min left';
    return '${(seconds / 3600).toStringAsFixed(1)} h left';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(
          color: _isFailed
              ? tokens.errorColor.withValues(alpha: 0.45)
              : tokens.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(tokens),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(tokens),
                  ],
                ),
                if (_subheading.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _subheading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // The actual file: the thing that is playable on disk.
                Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 12,
                      color: tokens.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        task.fileName.isEmpty
                            ? 'Preparing file…'
                            : task.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: tokens.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task.formattedSize,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (_isActive) ...[
                  const SizedBox(height: 10),
                  _buildProgress(tokens),
                ],
                if (_isFailed && task.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: tokens.errorColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildActions(tokens),
        ],
      ),
    );
  }

  Widget _buildThumbnail(AppTokens tokens) {
    final thumb = task.thumbnailUrl;
    return ClipRRect(
      borderRadius: tokens.borderRadiusXs,
      child: SizedBox(
        width: 46,
        height: 64,
        child: thumb != null && thumb.isNotEmpty
            ? Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _thumbnailFallback(tokens),
              )
            : _thumbnailFallback(tokens),
      ),
    );
  }

  Widget _thumbnailFallback(AppTokens tokens) {
    return Container(
      color: tokens.surfaceCard,
      alignment: Alignment.center,
      child: Icon(Icons.movie_outlined, size: 20, color: tokens.textMuted),
    );
  }

  Widget _buildStatusChip(AppTokens tokens) {
    final String label;
    final Color color;
    switch (task.status) {
      case DownloadTaskStatus.downloading:
        label = 'Downloading';
        color = tokens.primaryAccent;
      case DownloadTaskStatus.completed:
        label = 'Downloaded';
        color = tokens.liveColor;
      case DownloadTaskStatus.paused:
        label = 'Paused';
        color = tokens.vipColor;
      case DownloadTaskStatus.queued:
        label = 'Queued';
        color = tokens.textSecondary;
      case DownloadTaskStatus.failed:
        label = 'Failed';
        color = tokens.errorColor;
      case DownloadTaskStatus.cancelled:
        label = 'Cancelled';
        color = tokens.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: tokens.borderRadiusXs,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgress(AppTokens tokens) {
    final progress = task.progress.clamp(0.0, 1.0);
    final eta = _etaLabel;

    final stats = <String>[
      '${(progress * 100).toStringAsFixed(1)}%',
      task.formattedSize,
      if (task.status == DownloadTaskStatus.downloading) task.formattedSpeed,
      ?eta,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: tokens.borderRadiusXs,
          child: LinearProgressIndicator(
            value: progress <= 0 ? null : progress,
            minHeight: 4,
            backgroundColor: tokens.surfaceCard,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isPaused ? tokens.vipColor : tokens.primaryAccent,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          stats.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
        ),
      ],
    );
  }

  Widget _buildActions(AppTokens tokens) {
    final actions = <Widget>[];

    if (_isComplete && onWatch != null) {
      actions.add(
        _actionButton(
          tokens,
          icon: Icons.play_arrow_rounded,
          tooltip: 'Play this file',
          onTap: onWatch!,
          emphasized: true,
        ),
      );
      if (onExport != null) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.ios_share_rounded,
            tooltip: 'Export file',
            onTap: onExport!,
          ),
        );
      }
      if (onDeleteFile != null) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete download',
            onTap: onDeleteFile!,
            destructive: true,
          ),
        );
      }
      return Column(mainAxisSize: MainAxisSize.min, children: actions);
    }

    if (_isActive || _isFailed) {
      if (_isPaused) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.play_arrow_rounded,
            tooltip: 'Resume',
            onTap: () => DirectStreamService.instance.resumeDownload(task.id),
            emphasized: true,
          ),
        );
      } else if (_isFailed) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.refresh_rounded,
            tooltip: 'Retry',
            onTap: () => DirectStreamService.instance.retryDownload(task.id),
            emphasized: true,
          ),
        );
      } else if (task.status == DownloadTaskStatus.downloading) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.pause_rounded,
            tooltip: 'Pause',
            onTap: () => DirectStreamService.instance.pauseDownload(task.id),
          ),
        );
      }

      // Cancel/remove is always offered: a stuck row must be dismissable.
      actions.add(
        _actionButton(
          tokens,
          icon: Icons.close_rounded,
          tooltip: 'Cancel download',
          onTap: () => DirectStreamService.instance.cancelDownload(task.id),
          destructive: true,
        ),
      );

      if (_isFailed) {
        actions.add(
          _actionButton(
            tokens,
            icon: Icons.remove_circle_outline_rounded,
            tooltip: 'Remove from list',
            onTap: () => DirectStreamService.instance.removeTask(task.id),
          ),
        );
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: actions);
  }

  Widget _actionButton(
    AppTokens tokens, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool emphasized = false,
    bool destructive = false,
  }) {
    final color = destructive
        ? tokens.errorColor
        : (emphasized ? tokens.primaryAccent : tokens.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TvFocusable(
        borderRadius: tokens.borderRadiusXs,
        focusNode: focusNode,
        onDirection: onDirection,
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: emphasized
                  ? tokens.primaryAccent.withValues(alpha: 0.16)
                  : tokens.surfaceCard,
              borderRadius: tokens.borderRadiusXs,
              border: Border.all(
                color: emphasized
                    ? tokens.primaryAccent.withValues(alpha: 0.45)
                    : tokens.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
