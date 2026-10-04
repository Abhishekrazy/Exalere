import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Ambient low-power audio visualization screen displayed when Audio-Only Mode is active.
class AmbientAudioView extends StatefulWidget {
  final MediaItem mediaItem;
  final String? episodeTitle;
  final VoidCallback onRestoreVideo;
  final bool isTv;

  const AmbientAudioView({
    super.key,
    required this.mediaItem,
    this.episodeTitle,
    required this.onRestoreVideo,
    this.isTv = false,
  });

  @override
  State<AmbientAudioView> createState() => _AmbientAudioViewState();
}

class _AmbientAudioViewState extends State<AmbientAudioView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final posterUrl = widget.mediaItem.posterUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Deep Black / Low-power canvas background
        Container(color: tokens.canvasBackground),

        // 2. Dimmed Blurred Backdrop
        if (posterUrl != null && posterUrl.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: CachedNetworkImage(
                  imageUrl: posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

        // 3. Center Ambient Card
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Breathing Album Art
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.isTv ? 160 : 130,
                      height: widget.isTv ? 160 : 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ],
                        border: Border.all(
                          color: tokens.borderFocus.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: posterUrl != null && posterUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(
                                  color: tokens.surfaceCard,
                                  child: Icon(
                                    Icons.audiotrack_rounded,
                                    size: 48,
                                    color: tokens.primaryAccent,
                                  ),
                                ),
                              )
                            : Container(
                                color: tokens.surfaceCard,
                                child: Icon(
                                  Icons.audiotrack_rounded,
                                  size: 48,
                                  color: tokens.primaryAccent,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.mediaItem.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.isTv ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (widget.episodeTitle != null &&
                  widget.episodeTitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.episodeTitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.primaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Energy-saving pill badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.8),
                  borderRadius: tokens.borderRadiusPill,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.energy_savings_leaf_rounded,
                      size: 15,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Audio-Only Mode • Display Powered Down',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Restore Video Button
              TvFocusable(
                autofocus: true,
                scaleFactor: 1.06,
                shape: tokens.shapePill,
                borderRadius: tokens.borderRadiusPill,
                onTap: widget.onRestoreVideo,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: tokens.borderRadiusPill,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Restore Video View',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
