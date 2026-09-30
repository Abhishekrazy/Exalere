import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/image_cache_manager.dart';
import '../../../services/tmdb_service.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// 10-foot UI horizontal shelf displaying cast members with photos,
/// actor names, and character roles on Android TV.
class TvCastShelf extends StatelessWidget {
  final List<TmdbCastMember> cast;
  final FocusNode? firstCardFocusNode;
  final bool Function()? onUpFocus;
  final bool Function()? onDownFocus;

  const TvCastShelf({
    super.key,
    required this.cast,
    this.firstCardFocusNode,
    this.onUpFocus,
    this.onDownFocus,
  });

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Cast & Crew',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            cacheExtent: 350.0,
            itemCount: cast.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, idx) {
              final member = cast[idx];
              final isFirst = idx == 0;

              return TvFocusable(
                focusNode: isFirst ? firstCardFocusNode : null,
                scaleFactor: 1.08,
                shape: tokens.shapeSm,
                borderRadius: tokens.borderRadiusMd,
                onDirection: (direction) {
                  if (direction == TraversalDirection.up && onUpFocus != null) {
                    return onUpFocus!();
                  }
                  if (direction == TraversalDirection.down &&
                      onDownFocus != null) {
                    return onDownFocus!();
                  }
                  return false;
                },
                child: Container(
                  width: 110,
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceCard,
                    radius: tokens.cardRadius,
                    side: BorderSide(color: tokens.borderSubtle, width: 1.0),
                    shadows: tokens.getCardShadows(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Image
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(tokens.cardRadius),
                          topRight: Radius.circular(tokens.cardRadius),
                        ),
                        child: SizedBox(
                          height: 115,
                          width: double.infinity,
                          child: member.profileUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: member.profileUrl!,
                                  cacheManager:
                                      ExalereImageCacheManager.instance,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => Container(
                                    color: tokens.surfaceElevated,
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: tokens.textMuted,
                                      size: 32,
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    color: tokens.surfaceElevated,
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: tokens.textMuted,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: tokens.surfaceElevated,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: tokens.textMuted,
                                    size: 32,
                                  ),
                                ),
                        ),
                      ),

                      // Name and Character
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                member.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (member.character != null &&
                                  member.character!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  member.character!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
