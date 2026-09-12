import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../theme/app_tokens.dart';

/// Fullscreen Trailer Overlay with dedicated gestures and playback controls
class DetailsFullscreenTrailerOverlay extends StatelessWidget {
  final VideoController videoController;
  final BoxFit trailerFit;
  final bool isTrailerMuted;
  final VoidCallback onTogglePause;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFit;
  final VoidCallback onExitFullscreen;

  const DetailsFullscreenTrailerOverlay({
    super.key,
    required this.videoController,
    required this.trailerFit,
    required this.isTrailerMuted,
    required this.onTogglePause,
    required this.onToggleMute,
    required this.onToggleFit,
    required this.onExitFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Positioned.fill(
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: onTogglePause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Video(
                  controller: videoController,
                  controls: NoVideoControls,
                  fit: trailerFit,
                ),
              ),
            ),

            // Top-left Back button
            Positioned(
              top: 16 + MediaQuery.of(context).padding.top,
              left: 16,
              child: InkWell(
                onTap: onExitFullscreen,
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

            // Bottom-right Mute, Fit & Exit Fullscreen buttons
            Positioned(
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              right: 16,
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
                          color: tokens.surfaceCard.withValues(alpha: 0.75),
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
                    onTap: onExitFullscreen,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surfaceCard.withValues(alpha: 0.75),
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Icon(
                        Icons.fullscreen_exit_rounded,
                        color: tokens.textPrimary,
                        size: 20,
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
