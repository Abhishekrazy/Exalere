import 'package:flutter/material.dart';

import '../../../models/media_item.dart';
import '../../theme/app_tokens.dart';
import '../media_card.dart';

class TvMoreLikeThisShelf extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item) onItemSelect;

  const TvMoreLikeThisShelf({
    super.key,
    required this.items,
    required this.onItemSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'More Like This',
          style: TextStyle(
            color: context.tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            cacheExtent: 350.0,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, idx) {
              final item = items[idx];
              return MediaCard(
                item: item,
                width: 105,
                height: 155,
                onTap: () => onItemSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
