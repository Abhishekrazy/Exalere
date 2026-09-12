import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../providers/cast_provider.dart';
import '../../../providers/library_provider.dart';
import '../../theme/app_tokens.dart';
import '../cast_dialog.dart';

/// Ambient cinematic backdrop or live trailer video header with obsidian gradients
class DetailsBackdropLayer extends StatelessWidget {
  final double height;
  final bool isTrailerPlaying;
  final bool isTrailerLoading;
  final VideoController? trailerVideoController;
  final BoxFit trailerFit;
  final String? backdropUrl;
  final bool isDesktop;

  const DetailsBackdropLayer({
    super.key,
    required this.height,
    required this.isTrailerPlaying,
    required this.isTrailerLoading,
    this.trailerVideoController,
    required this.trailerFit,
    this.backdropUrl,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isTrailerPlaying && trailerVideoController != null) ...[
            Center(
              child: Video(
                controller: trailerVideoController!,
                controls: NoVideoControls,
                fit: trailerFit,
              ),
            ),
          ] else if (backdropUrl != null && backdropUrl!.isNotEmpty) ...[
            CachedNetworkImage(
              imageUrl: backdropUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, _, _) =>
                  Container(color: theme.scaffoldBackgroundColor),
            ),
          ] else ...[
            Container(color: theme.scaffoldBackgroundColor),
          ],

          // Multi-stop gradients for seamless blend into obsidian background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.canvasBackground.withValues(
                    alpha: isTrailerPlaying ? 0.35 : 0.45,
                  ),
                  tokens.canvasBackground.withValues(alpha: 0.0),
                  theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
                  theme.scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.25, 0.75, 1.0],
              ),
            ),
          ),
          if (isDesktop && !isTrailerPlaying)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
                    tokens.canvasBackground.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 0.9],
                ),
              ),
            ),

          if (isTrailerLoading)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.85),
                  borderRadius: tokens.borderRadiusMd,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: tokens.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading Official Trailer...',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating Top App Bar (Back button, Trailer Controls, Cast button, Watchlist)
class DetailsTopBar extends StatelessWidget {
  final MediaItem mediaItem;
  final bool isTrailerPlaying;
  final bool isTrailerMuted;
  final bool isTrailerFullscreen;
  final BoxFit trailerFit;
  final VoidCallback onBack;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onStopTrailer;

  const DetailsTopBar({
    super.key,
    required this.mediaItem,
    required this.isTrailerPlaying,
    required this.isTrailerMuted,
    required this.isTrailerFullscreen,
    required this.trailerFit,
    required this.onBack,
    required this.onToggleMute,
    required this.onToggleFit,
    required this.onToggleFullscreen,
    required this.onStopTrailer,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final isFav = library.isFavorite(mediaItem.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop =
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ||
        screenWidth >= 900;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Back Button (Desktop or Mobile)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: tokens.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                ),

                // Trailer floating quick controls
                if (isTrailerPlaying)
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: onToggleMute,
                          borderRadius: tokens.borderRadiusPill,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Icon(
                              isTrailerMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: tokens.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: trailerFit == BoxFit.cover
                              ? 'Fit to Screen'
                              : 'Original Aspect',
                          child: InkWell(
                            onTap: onToggleFit,
                            borderRadius: tokens.borderRadiusPill,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.surfaceCard.withValues(
                                  alpha: 0.75,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Icon(
                                trailerFit == BoxFit.cover
                                    ? Icons.fit_screen_rounded
                                    : Icons.aspect_ratio_rounded,
                                color: tokens.textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: onToggleFullscreen,
                          borderRadius: tokens.borderRadiusPill,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(color: tokens.borderSubtle),
                            ),
                            child: Icon(
                              isTrailerFullscreen
                                  ? Icons.fullscreen_exit_rounded
                                  : Icons.fullscreen_rounded,
                              color: tokens.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Stop Trailer',
                          child: InkWell(
                            onTap: onStopTrailer,
                            borderRadius: tokens.borderRadiusPill,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tokens.surfaceCard.withValues(
                                  alpha: 0.75,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: tokens.textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Right actions (Cast and Desktop Watchlist)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<CastProvider>(
                        builder: (context, cast, _) {
                          final isCasting = cast.isConnected;
                          return InkWell(
                            onTap: () {
                              CastDialog.show(context, mediaItem: mediaItem);
                            },
                            borderRadius: tokens.borderRadiusPill,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isCasting
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.25,
                                      )
                                    : tokens.surfaceCard.withValues(
                                        alpha: 0.75,
                                      ),
                                borderRadius: tokens.borderRadiusPill,
                                border: Border.all(
                                  color: isCasting
                                      ? theme.colorScheme.primary
                                      : tokens.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isCasting
                                        ? Icons.cast_connected_rounded
                                        : Icons.cast_rounded,
                                    color: isCasting
                                        ? theme.colorScheme.primary
                                        : tokens.textPrimary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isCasting
                                        ? (cast.connectedDevice?.name ??
                                              'Casting')
                                        : 'Cast',
                                    style: TextStyle(
                                      color: isCasting
                                          ? theme.colorScheme.primary
                                          : tokens.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (isDesktop && screenWidth >= 1100) ...[
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => library.toggleFavorite(mediaItem),
                          borderRadius: tokens.borderRadiusPill,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.surfaceCard.withValues(alpha: 0.75),
                              borderRadius: tokens.borderRadiusPill,
                              border: Border.all(
                                color: isFav
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.8,
                                      )
                                    : tokens.borderSubtle,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFav
                                      ? Icons.check_rounded
                                      : Icons.bookmark_border_rounded,
                                  color: isFav
                                      ? theme.colorScheme.primary
                                      : tokens.textPrimary,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isFav ? 'In Watchlist' : 'Add to Watchlist',
                                  style: TextStyle(
                                    color: isFav
                                        ? theme.colorScheme.primary
                                        : tokens.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }
}
