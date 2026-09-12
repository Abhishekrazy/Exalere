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
        // 1. Full-Screen Cinematic Backdrop with Multi-Stop Vignette
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  tokens.textPrimary,
                  tokens.textPrimary,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.95],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
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
        ),

        // Ambient Gradient Layers for 100% Readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  tokens.canvasBackground,
                  tokens.canvasBackground.withValues(alpha: 0.98),
                  tokens.canvasBackground.withValues(alpha: 0.75),
                  tokens.canvasBackground.withValues(alpha: 0.19),
                ],
                stops: const [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  tokens.canvasBackground.withValues(alpha: 0.5),
                  tokens.canvasBackground,
                ],
                stops: const [0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
