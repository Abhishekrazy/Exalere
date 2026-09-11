import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../theme/app_tokens.dart';
import '../media_card.dart';

/// Renders the "More Like This" recommended titles carousel on the details screen.
class DetailsRelatedSection extends StatelessWidget {
  final List<MediaItem> relatedItems;
  final double screenWidth;
  final ValueChanged<MediaItem> onItemTap;

  const DetailsRelatedSection({
    super.key,
    required this.relatedItems,
    required this.screenWidth,
    required this.onItemTap,
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
        Text(
          'More Like This',
          style: TextStyle(
            fontSize: screenWidth < 600 ? 17 : 19,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: cardHeight + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
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
