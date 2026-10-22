import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../theme/app_tokens.dart';
import '../media_card.dart';
import '../tv_focusable.dart';

/// Renders the "More Like This" recommended titles carousel on the details screen.
///
/// When [onExplore] is supplied the header gains a "See All" action, which opens
/// the full grid. That matters because this carousel is capped by how many
/// related titles fit on screen; without it the rest are unreachable.
class DetailsRelatedSection extends StatelessWidget {
  final List<MediaItem> relatedItems;
  final double screenWidth;
  final ValueChanged<MediaItem> onItemTap;

  /// Opens the full list of related titles. Omitted when there is nowhere to go.
  final VoidCallback? onExplore;

  const DetailsRelatedSection({
    super.key,
    required this.relatedItems,
    required this.screenWidth,
    required this.onItemTap,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    if (relatedItems.isEmpty) return const SizedBox.shrink();

    final tokens = context.tokens;
    final cardWidth = screenWidth < 600 ? 110.0 : 135.0;
    final cardHeight = screenWidth < 600 ? 165.0 : 200.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'More Like This',
                style: TextStyle(
                  fontSize: screenWidth < 600 ? 17 : 19,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (onExplore != null) ...[
              const SizedBox(width: 12),
              TvFocusable(
                borderRadius: tokens.borderRadiusPill,
                onTap: onExplore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceCard,
                    borderRadius: tokens.borderRadiusPill,
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: tokens.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          // Card height, the caption beneath it, and room for the focus
          // scale-up so the glow is not clipped.
          height: cardHeight + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Mandatory for TV: lets the focus glow bleed outside the viewport
            // and pre-renders the next cards for D-Pad spatial navigation.
            clipBehavior: Clip.none,
            cacheExtent: 350.0,
            itemCount: relatedItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final item = relatedItems[idx];
              return MediaCard(
                item: item,
                width: cardWidth,
                height: cardHeight,
                onTap: () => onItemTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
