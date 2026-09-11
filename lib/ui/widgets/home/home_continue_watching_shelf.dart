import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../continue_watching_card.dart';
import '../tv_play_helper.dart';
import 'home_section_header.dart';

class HomeContinueWatchingShelf extends StatelessWidget {
  final void Function(MediaItem item) onItemSelect;

  const HomeContinueWatchingShelf({super.key, required this.onItemSelect});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final app = context.watch<AppProvider>();

    if (library.continueWatching.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayContinueWatching = library.continueWatching.take(10).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionHeader(
          title: 'Continue Watching',
          icon: Icons.play_circle_outline_rounded,
        ),
        DpadRegion(
          enter: DpadEnterBehavior.nearest,
          child: SizedBox(
            height: app.isTvMode ? 144 : 156,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              cacheExtent: app.isTvMode ? 350.0 : 300.0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              itemCount: displayContinueWatching.length,
              itemBuilder: (context, index) {
                final h = displayContinueWatching[index];
                return ContinueWatchingCard(
                  historyItem: h,
                  isLastCard: index == displayContinueWatching.length - 1,
                  onPlay: () => TvPlayHelper.resumePlayback(context, h),
                  onTap: () => onItemSelect(h.item),
                  onMarkWatched: () => library.markAsWatched(
                    h.item.id,
                    season: h.season,
                    episode: h.episode,
                    isWatched: true,
                    item: h.item,
                  ),
                  onRemove: () => library.removeFromHistory(
                    h.item.id,
                    season: h.season,
                    episode: h.episode,
                  ),
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
