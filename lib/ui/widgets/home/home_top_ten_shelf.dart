import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dpad/dpad.dart';

import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../top_ten_card.dart';
import 'home_section_header.dart';

class HomeTopTenShelf extends StatelessWidget {
  final List<MediaItem> items;
  final void Function(MediaItem item, String heroTag) onItemSelect;

  const HomeTopTenShelf({
    super.key,
    required this.items,
    required this.onItemSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final app = context.watch<AppProvider>();
    final topTen = items.take(10).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Top 10 Movies Today',
          icon: Icons.trending_up_rounded,
        ),
        DpadRegion(
          enter: DpadEnterBehavior.nearest,
          child: SizedBox(
            height:
                (app.isTvMode ? 180.0 : 210.0) *
                (app.uiScale < 0.92 ? 0.92 : 1.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              cacheExtent: app.isTvMode ? 350.0 : 300.0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: topTen.length,
              itemBuilder: (context, index) {
                final item = topTen[index];
                final heroTag = 'top10_${item.id}_$index';
                return TopTenCard(
                  item: item,
                  rank: index + 1,
                  heroTag: heroTag,
                  isLastCard: index == topTen.length - 1,
                  onTap: () => onItemSelect(item, heroTag),
                );
              },
            ),
          ),
        ),
        SizedBox(height: app.isTvMode ? 14 : 24),
      ],
    );
  }
}
