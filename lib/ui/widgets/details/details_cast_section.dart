import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';

/// Renders the cast avatar shelf and featured crew members grid on details screen.
class DetailsCastSection extends StatelessWidget {
  final List<TmdbCastMember> cast;
  final List<TmdbCrewMember> crew;
  final String? director;
  final String? fallbackStars;

  const DetailsCastSection({
    super.key,
    required this.cast,
    required this.crew,
    this.director,
    this.fallbackStars,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (director != null && director!.isNotEmpty && crew.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                children: [
                  TextSpan(
                    text: 'Director: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  TextSpan(text: director),
                ],
              ),
            ),
          ),

        if (cast.isNotEmpty) ...[
          Text(
            'Top Cast',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, idx) {
                final member = cast[idx];
                return SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tokens.borderSubtle,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.shadowColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: member.profileUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: member.profileUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      Container(color: tokens.surfaceElevated),
                                  errorWidget: (_, _, _) => Container(
                                    color: tokens.surfaceElevated,
                                    child: Icon(
                                      Icons.person,
                                      color: tokens.textMuted,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: tokens.surfaceElevated,
                                  child: Icon(
                                    Icons.person,
                                    color: tokens.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      if (member.character != null &&
                          member.character!.isNotEmpty)
                        Text(
                          member.character!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: tokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ] else if (fallbackStars != null && fallbackStars!.isNotEmpty)
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              children: [
                TextSpan(
                  text: 'Starring: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                TextSpan(text: fallbackStars!),
              ],
            ),
          ),
      ],
    );
  }
}

/// Renders the 2-column featured crew grid on desktop / tablet layouts
class DetailsFeaturedCrewGrid extends StatelessWidget {
  final List<TmdbCrewMember> crew;

  const DetailsFeaturedCrewGrid({super.key, required this.crew});

  @override
  Widget build(BuildContext context) {
    if (crew.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;
    final displayCrew = crew.take(6).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Wrap(
        spacing: 36,
        runSpacing: 14,
        children: displayCrew.map((member) {
          return SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member.role,
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
