import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../../models/movie_collection.dart';
import '../../../services/image_cache_manager.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

/// Renders a franchise / movie collection timeline shelf (e.g. Harry Potter, Dark Knight).
class DetailsCollectionShelf extends StatelessWidget {
  final MovieCollection collection;
  final String? currentMediaId;
  final void Function(MediaItem item) onItemTap;
  final FocusNode? firstCardFocusNode;

  const DetailsCollectionShelf({
    super.key,
    required this.collection,
    this.currentMediaId,
    required this.onItemTap,
    this.firstCardFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);

    if (collection.parts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              collection.name.toUpperCase(),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
                borderRadius: tokens.borderRadiusXs,
              ),
              child: Text(
                'FRANCHISE',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Chronological release order (${collection.parts.length} titles)',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            clipBehavior: Clip.none,
            cacheExtent: 350.0,
            scrollDirection: Axis.horizontal,
            itemCount: collection.parts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = collection.parts[index];
              final isCurrent =
                  currentMediaId != null && item.id == currentMediaId;

              return TvFocusable(
                focusNode: index == 0 ? firstCardFocusNode : null,
                scaleFactor: 1.05,
                borderRadius: tokens.borderRadiusSm,
                onTap: () {
                  if (!isCurrent) onItemTap(item);
                },
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: tokens.borderRadiusSm,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: tokens.surfaceCard,
                                    border: Border.all(
                                      color: isCurrent
                                          ? theme.colorScheme.primary
                                          : tokens.borderSubtle,
                                      width: isCurrent ? 2.0 : 0.8,
                                    ),
                                  ),
                                  child:
                                      item.posterUrl != null &&
                                          item.posterUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: item.posterUrl!,
                                          cacheManager:
                                              ExalereImageCacheManager.instance,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        )
                                      : Center(
                                          child: Icon(
                                            Icons.movie_rounded,
                                            color: tokens.textMuted,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: tokens.borderRadiusXs,
                                    boxShadow: [
                                      BoxShadow(
                                        color: tokens.shadowColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : tokens.textPrimary,
                          fontSize: 12,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      if (item.year != null)
                        Text(
                          item.year!,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
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
