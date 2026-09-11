import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.tokens.textPrimary,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Metadata Chips Row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (year != null && year!.isNotEmpty)
              Text(
                year!,
                style: TextStyle(
                  color: context.tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: context.tokens.getShapeDecoration(
                color: context.tokens.borderSubtle,
                radius: (context.tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                side: BorderSide(
                  color: context.tokens.borderSubtle,
                  width: 0.6,
                ),
              ),
              child: Text(
                ageCert,
                style: TextStyle(
                  color: context.tokens.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (rating != null && rating!.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: context.tokens.vipColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating!,
                    style: TextStyle(
                      color: context.tokens.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: context.tokens.getShapeDecoration(
                color: context.tokens.primaryAccent.withValues(alpha: 0.2),
                radius: (context.tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                side: BorderSide(
                  color: context.tokens.primaryAccent,
                  width: 0.8,
                ),
              ),
              child: Text(
                isSeries ? 'SERIES' : 'MOVIE',
                style: TextStyle(
                  color: context.tokens.primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (isCam)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: context.tokens.getShapeDecoration(
                  color: context.tokens.borderSubtle,
                  radius: (context.tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                ),
                child: Text(
                  qualityTag ?? 'CAM',
                  style: TextStyle(
                    color: context.tokens.vipColor,
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
                decoration: context.tokens.getShapeDecoration(
                  color: context.tokens.surfaceElevated,
                  radius: (context.tokens.cardRadius * 0.35).clamp(2.0, 6.0),
                  side: BorderSide(
                    color: context.tokens.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  languageTag!.toUpperCase(),
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Overview / Synopsis
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            overview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: context.tokens.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
