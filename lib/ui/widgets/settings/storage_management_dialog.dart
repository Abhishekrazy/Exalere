import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/library_provider.dart';
import '../../../services/image_cache_manager.dart';
import '../../../services/storage_service.dart';
import '../../../services/video_cache_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// Interactive Storage & Stream Cache Hygiene dialog.
class StorageManagementDialog extends StatefulWidget {
  const StorageManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const StorageManagementDialog(),
    );
  }

  @override
  State<StorageManagementDialog> createState() =>
      _StorageManagementDialogState();
}

class _StorageManagementDialogState extends State<StorageManagementDialog> {
  final StorageService _storageService = StorageService();
  final VideoCacheService _videoCache = VideoCacheService.instance;

  int _videoCacheBytes = 0;
  int _historyCount = 0;
  bool _isLoading = true;
  String? _statusBanner;

  @override
  void initState() {
    super.initState();
    _refreshStorageStats();
  }

  Future<void> _refreshStorageStats() async {
    setState(() => _isLoading = true);
    try {
      final videoBytes = await _videoCache.getCacheSizeBytes();
      final history = await _storageService.getWatchHistory();

      if (mounted) {
        setState(() {
          _videoCacheBytes = videoBytes;
          _historyCount = history.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _purgeVideoCache() async {
    await _videoCache.clearCache();
    await _refreshStorageStats();
    if (mounted) {
      setState(() => _statusBanner = 'Video stream buffer purged successfully');
    }
  }

  Future<void> _purgeImageCache() async {
    try {
      await ExalereImageCacheManager.instance.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) {
        setState(() => _statusBanner = 'Image poster cache cleared');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusBanner = 'Error clearing image cache: $e');
      }
    }
  }

  Future<void> _clearHistory() async {
    await _storageService.clearWatchHistory();
    if (mounted) {
      context.read<LibraryProvider>().clearHistory();
      await _refreshStorageStats();
      setState(() => _statusBanner = 'Watch history cleared');
    }
  }

  Future<void> _purgeAll() async {
    await _videoCache.clearCache();
    try {
      await ExalereImageCacheManager.instance.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
    await _refreshStorageStats();
    if (mounted) {
      setState(
        () => _statusBanner = 'All temporary buffers & image caches cleaned',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: tokens.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cardRadius * 1.5),
        side: BorderSide(color: tokens.borderSubtle, width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusMd,
                    ),
                    child: Icon(
                      Icons.cleaning_services_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Storage Hygiene & Cache Cleaner',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reclaim disk space and manage streaming cache buffers',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TvFocusable(
                    scaleFactor: 1.1,
                    shape: tokens.shapeSm,
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Feedback banner
              if (_statusBanner != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusBanner!,
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
                const SizedBox(height: 16),
              ],

              // Storage Overview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated,
                  borderRadius: tokens.borderRadiusMd,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stream Buffer Temp Files:',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isLoading ? '...' : _formatBytes(_videoCacheBytes),
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Watch History Entries:',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isLoading ? '...' : '$_historyCount items',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Tiles
              _buildActionTile(
                context,
                title: 'Purge Stream Cache',
                subtitle:
                    'Deletes temporary media chunks & disk buffering files',
                icon: Icons.video_collection_outlined,
                onTap: _purgeVideoCache,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                title: 'Clear Poster Image Cache',
                subtitle:
                    'Purges cached thumbnails, backdrops, and cast headshots',
                icon: Icons.image_not_supported_outlined,
                onTap: _purgeImageCache,
              ),
              const SizedBox(height: 10),
              _buildActionTile(
                context,
                title: 'Clear Watch History',
                subtitle: 'Removes all playback history and progress markers',
                icon: Icons.history_rounded,
                onTap: _clearHistory,
              ),
              const SizedBox(height: 24),

              // Action buttons row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TvFocusable(
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: _purgeAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusSm,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_delete_rounded,
                            size: 16,
                            color: tokens.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Clean All Caches',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TvFocusable(
                    autofocus: true,
                    scaleFactor: 1.05,
                    shape: tokens.shapeSm,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: tokens.borderRadiusSm,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    return TvFocusable(
      scaleFactor: 1.03,
      shape: tokens.shapeSm,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: tokens.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
