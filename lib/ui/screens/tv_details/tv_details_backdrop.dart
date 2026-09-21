import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../theme/app_tokens.dart';

/// Full-screen cinematic backdrop for TV details with multi-stop vignette
/// and dual ambient gradient overlays for 100% legibility.
class TvDetailsBackdrop extends StatelessWidget {
  final bool isTrailerPlaying;
  final VideoController? trailerVideoController;
  final String? backdropUrl;

  const TvDetailsBackdrop({
    super.key,
    required this.isTrailerPlaying,
    required this.trailerVideoController,
    required this.backdropUrl,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Stack(
      children: [
        // 1. Full-Screen Cinematic Backdrop
        Positioned.fill(
          child: isTrailerPlaying && trailerVideoController != null
              ? Video(
                  controller: trailerVideoController!,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                )
              : (backdropUrl != null && backdropUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: backdropUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topRight,
                  memCacheWidth: 960,
                  maxWidthDiskCache: 960,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
        ),

        // 2. Lateral Cinematic Gradient (Left-to-Right)
        // Deep solid dark canvas on the left where title, chips, overview,
        // and action buttons reside, smoothly fading to transparent on the right
        // to let the character/poster artwork breathe.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  tokens.canvasBackground,
                  tokens.canvasBackground.withValues(alpha: 0.95),
                  tokens.canvasBackground.withValues(alpha: 0.75),
                  tokens.canvasBackground.withValues(alpha: 0.35),
                  tokens.canvasBackground.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.35, 0.55, 0.75, 1.0],
              ),
            ),
          ),
        ),

        // 3. Vertical Gradient Scrim (Top & Bottom Vignette)
        // Blends the top edge for overscan and fades the bottom into solid canvasBackground
        // so that episode/recommendation shelves and their text labels never clash with the artwork.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tokens.canvasBackground.withValues(alpha: 0.65),
                  tokens.canvasBackground.withValues(alpha: 0.0),
                  tokens.canvasBackground.withValues(alpha: 0.0),
                  tokens.canvasBackground.withValues(alpha: 0.8),
                  tokens.canvasBackground,
                ],
                stops: const [0.0, 0.12, 0.35, 0.65, 0.90],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
