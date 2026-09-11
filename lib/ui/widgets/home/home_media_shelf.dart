import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../media_card.dart';
import 'home_section_header.dart';

class HomeMediaShelf extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MediaItem> items;
  final String shelfPrefix;
  final VoidCallback? onExplore;
  final void Function(MediaItem item, String heroTag) onItemSelect;

  const HomeMediaShelf({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.shelfPrefix,
    this.onExplore,
    required this.onItemSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final uiScale = app.uiScale;
    final displayItems = items.take(10).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(title: title, icon: icon, onExplore: onExplore),
        SizedBox(
          height: (isTv ? 232.0 : 265.0) * (uiScale < 0.92 ? 0.92 : 1.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            cacheExtent: isTv ? 350.0 : 300.0,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final heroTag = '${shelfPrefix}_${item.id}_$index';
              return MediaCard(
                item: item,
                heroTag: heroTag,
                onTap: () => onItemSelect(item, heroTag),
              );
            },
          ),
        ),
        SizedBox(height: isTv ? 14 : 24),
      ],
    );
  }
}
