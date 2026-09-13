import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dpad/dpad.dart';

import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../continue_watching_card.dart';
import '../tv_play_helper.dart';
import 'home_section_header.dart';

class HomeContinueWatchingShelf extends StatelessWidget {
  final void Function(MediaItem item) onItemSelect;
  final FocusNode? firstCardFocusNode;
  final bool Function()? onUpFocus;
  final bool Function()? onDownFocus;

  const HomeContinueWatchingShelf({
    super.key,
    required this.onItemSelect,
    this.firstCardFocusNode,
    this.onUpFocus,
    this.onDownFocus,
  });

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
                  focusNode: index == 0 ? firstCardFocusNode : null,
                  isFirstCard: index == 0,
                  isLastCard: index == displayContinueWatching.length - 1,
                  onUp: onUpFocus,
                  onDown: onDownFocus,
                  historyItem: h,
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
