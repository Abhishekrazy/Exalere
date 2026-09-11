import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// 16:9 Landscape episode card for Android TV shelves.
/// Displays episode number badge, thumbnail, progress bar, title, and synopsis.
class TvEpisodeCard extends StatelessWidget {
  final Episode episode;
  final String? thumbnailUrl;
  final String title;
  final String overview;
  final int resumePositionSeconds;
  final bool isWatched;
  final VoidCallback onTap;

  const TvEpisodeCard({
    super.key,
    required this.episode,
    required this.thumbnailUrl,
    required this.title,
    required this.overview,
    required this.resumePositionSeconds,
    this.isWatched = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final cardRadius = tokens.borderRadiusSm.topLeft.x;
    final shapeBorder = tokens.getShapeBorder(
      radius: cardRadius,
      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
    );

    return TvFocusable(
      scaleFactor: 1.06,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        width: 230,
        decoration: tokens.getShapeDecoration(
          color: tokens.surfaceCard,
          radius: cardRadius,
          side: BorderSide(color: tokens.borderSubtle, width: 0.8),
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shapeBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail Still
              SizedBox(
                height: 108,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                          color: tokens.surfaceElevated,
                          child: Icon(
                            Icons.movie_rounded,
                            size: 30,
                            color: tokens.textMuted,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: tokens.surfaceElevated,
                        child: Icon(
                          Icons.movie_rounded,
                          size: 30,
                          color: tokens.textMuted,
                        ),
                      ),

                    // Dark overlay vignette
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              tokens.canvasBackground.withValues(alpha: 0.7),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Episode Number Badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceElevated.withValues(alpha: 0.85),
                          borderRadius: tokens.borderRadiusXs,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'E${episode.episode}',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // Watched badge (if watched)
                    if (isWatched)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: tokens.surfaceElevated.withValues(
                              alpha: 0.85,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.primaryAccent,
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: tokens.primaryAccent,
                          ),
                        ),
                      ),

                    // Play Center Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: tokens.canvasBackground.withValues(
                            alpha: 0.65,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: tokens.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),

                    // Resume progress bar (if watched)
                    if (resumePositionSeconds > 15)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: 0.5,
                          minHeight: 2.5,
                          backgroundColor: tokens.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            tokens.primaryAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Title & Synopsis Snippet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episode}. $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overview.isNotEmpty
                          ? overview
                          : 'Episode ${episode.episode}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 9.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
