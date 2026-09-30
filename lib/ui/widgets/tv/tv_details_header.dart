import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

class TvDetailsHeader extends StatelessWidget {
  final String title;
  final String? year;
  final String ageCert;
  final String? rating;
  final bool isSeries;
  final bool isCam;
  final String? qualityTag;
  final String? languageTag;
  final String overview;
  final String? tagline;
  final List<String> genres;
  final String? runtime;
  final String? director;
  final List<String> cast;
  final VoidCallback? onOpenFullDetails;
  final FocusNode? overviewFocusNode;

  const TvDetailsHeader({
    super.key,
    required this.title,
    this.year,
    required this.ageCert,
    this.rating,
    required this.isSeries,
    this.isCam = false,
    this.qualityTag,
    this.languageTag,
    required this.overview,
    this.tagline,
    this.genres = const [],
    this.runtime,
    this.director,
    this.cast = const [],
    this.onOpenFullDetails,
    this.overviewFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: tokens.textPrimary,
              letterSpacing: -0.4,
              height: 1.15,
              shadows: [
                Shadow(
                  color: tokens.shadowColor.withValues(alpha: 0.9),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),

        // Tagline (if available)
        if (tagline != null && tagline!.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Text(
              '“$tagline”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: tokens.textSecondary,
                shadows: [
                  Shadow(
                    color: tokens.shadowColor.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Metadata Chips Row (Year, Rating, AgeCert, Runtime, Format, Genres)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (year != null && year!.isNotEmpty)
              Text(
                year!,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: tokens.shadowColor.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5.5,
                vertical: 1.5,
              ),
              decoration: tokens.getShapeDecoration(
                color: tokens.borderSubtle,
                radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                side: BorderSide(color: tokens.borderSubtle, width: 0.6),
              ),
              child: Text(
                ageCert,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (rating != null && rating!.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 15, color: tokens.vipColor),
                  const SizedBox(width: 3),
                  Text(
                    rating!,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5.5,
                vertical: 1.5,
              ),
              decoration: tokens.getShapeDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.2),
                radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                side: BorderSide(color: tokens.primaryAccent, width: 0.8),
              ),
              child: Text(
                isSeries ? 'SERIES' : 'MOVIE',
                style: TextStyle(
                  color: tokens.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (runtime != null && runtime!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.5),
                  radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                  side: BorderSide(color: tokens.borderSubtle, width: 0.7),
                ),
                child: Text(
                  runtime!,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (isCam)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.borderSubtle,
                  radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                ),
                child: Text(
                  qualityTag ?? 'CAM',
                  style: TextStyle(
                    color: tokens.vipColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (languageTag != null && languageTag!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceElevated,
                  radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                  side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                ),
                child: Text(
                  languageTag!.toUpperCase(),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            for (final genre in genres.take(4))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 1.5,
                ),
                decoration: tokens.getShapeDecoration(
                  color: tokens.surfaceElevated.withValues(alpha: 0.4),
                  radius: (tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                  side: BorderSide(color: tokens.borderSubtle, width: 0.6),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Overview / Synopsis with Optional Full Details Trigger
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overview.isNotEmpty ? overview : 'No synopsis available.',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                  height: 1.4,
                  shadows: [
                    Shadow(
                      color: tokens.shadowColor.withValues(alpha: 0.85),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              if (onOpenFullDetails != null) ...[
                const SizedBox(height: 6),
                TvFocusable(
                  focusNode: overviewFocusNode,
                  scaleFactor: 1.06,
                  borderRadius: tokens.borderRadiusPill,
                  onTap: onOpenFullDetails,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3.5,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceElevated.withValues(alpha: 0.5),
                      radius: 999.0,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: tokens.primaryAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Full Details & Synopsis',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 11,
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

        // Starring & Director / Creator Info
        if (cast.isNotEmpty || (director != null && director!.isNotEmpty)) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (cast.isNotEmpty)
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Starring: ',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: cast.take(4).join(', '),
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (director != null && director!.isNotEmpty)
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: isSeries ? 'Creator: ' : 'Director: ',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: director!,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
