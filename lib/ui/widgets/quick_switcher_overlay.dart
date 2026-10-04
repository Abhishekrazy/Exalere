import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../providers/library_provider.dart';
import '../theme/app_tokens.dart';
import '../screens/deep_discover_screen.dart';
import '../screens/details_screen.dart';
import '../screens/live_tv_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/tv_details_screen.dart';
import 'tv_focusable.dart';
import 'tv_web_remote_dialog.dart';

/// Media Multitasker Quick Switcher slide-out overlay for TV and Desktop.
class QuickSwitcherOverlay extends StatelessWidget {
  const QuickSwitcherOverlay({super.key});

  static Future<void> show(BuildContext context) {
    final tokens = context.tokens;
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Switcher',
      barrierColor: tokens.canvasBackground.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const QuickSwitcherOverlay(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  void _openDetails(BuildContext context, MediaItem item) {
    Navigator.of(context).pop();
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsScreen(mediaItem: item)),
      );
    }
  }

  void _teleportToLiveTv(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveTvScreen()),
    );
  }

  void _teleportToDiscover(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DeepDiscoverScreen()),
    );
  }

  void _teleportToSettings(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openWebRemote(BuildContext context) {
    Navigator.of(context).pop();
    TvWebRemoteDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final libProv = context.watch<LibraryProvider>();
    final continueWatching = libProv.continueWatching.take(6).toList();

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          height: double.infinity,
          decoration: BoxDecoration(
            color: tokens.surfaceCard,
            border: Border(
              left: BorderSide(color: tokens.borderSubtle, width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.shadowColor,
                blurRadius: 30,
                offset: const Offset(-8, 0),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: tokens.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Switcher',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Media Multitasker',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12,
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
              const SizedBox(height: 28),

              // Teleport Shortcuts Header
              Text(
                'DESTINATION TELEPORTS',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),

              // Teleport Grid
              Row(
                children: [
                  Expanded(
                    child: _buildTeleportTile(
                      context,
                      label: 'Live TV',
                      icon: Icons.tv_rounded,
                      color: theme.colorScheme.secondary,
                      onTap: () => _teleportToLiveTv(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTeleportTile(
                      context,
                      label: 'Discover',
                      icon: Icons.explore_rounded,
                      color: theme.colorScheme.primary,
                      onTap: () => _teleportToDiscover(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTeleportTile(
                      context,
                      label: 'Web Remote',
                      icon: Icons.phonelink_ring_rounded,
                      color: theme.colorScheme.primary,
                      onTap: () => _openWebRemote(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTeleportTile(
                      context,
                      label: 'Settings',
                      icon: Icons.settings_rounded,
                      color: tokens.textSecondary,
                      onTap: () => _teleportToSettings(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Continue Watching Header
              Row(
                children: [
                  Text(
                    'RESUME PLAYBACK',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${continueWatching.length} active',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Continue Watching List
              Expanded(
                child: continueWatching.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 40,
                              color: tokens.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No recent in-progress streams',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: continueWatching.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final watchItem = continueWatching[index];
                          final item = watchItem.item;
                          final progress = watchItem.progress;

                          return TvFocusable(
                            scaleFactor: 1.04,
                            shape: tokens.shapeSm,
                            onTap: () => _openDetails(context, item),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: tokens.surfaceElevated,
                                borderRadius: tokens.borderRadiusSm,
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: tokens.borderRadiusSm,
                                    child: SizedBox(
                                      width: 50,
                                      height: 70,
                                      child: item.posterUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: item.posterUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                        color:
                                                            tokens.surfaceCard,
                                                        child: const Icon(
                                                          Icons.movie_outlined,
                                                          size: 20,
                                                        ),
                                                      ),
                                            )
                                          : Container(
                                              color: tokens.surfaceCard,
                                              child: const Icon(
                                                Icons.movie_outlined,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Details & progress
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.isSeries
                                              ? 'Series'
                                              : (item.year ?? 'Movie'),
                                          style: TextStyle(
                                            color: tokens.textMuted,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: tokens.borderRadiusSm,
                                          child: LinearProgressIndicator(
                                            value: progress.clamp(0.0, 1.0),
                                            minHeight: 4,
                                            backgroundColor: tokens.surfaceCard,
                                            valueColor: AlwaysStoppedAnimation(
                                              theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeleportTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;

    return TvFocusable(
      scaleFactor: 1.05,
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
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
