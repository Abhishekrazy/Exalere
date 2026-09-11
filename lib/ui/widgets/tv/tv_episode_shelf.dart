import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dpad/dpad.dart';

import '../../../models/media_details.dart';
import '../../../providers/library_provider.dart';
import '../../../services/tmdb_service.dart';
import 'tv_episode_card.dart';

/// Horizontal episode shelf for Android TV details screen.
///
/// [firstCardFocusNode] is an optional external [FocusNode] that will be
/// assigned to the very first episode card. The parent screen can then
/// explicitly call [firstCardFocusNode.requestFocus()] when the user navigates
/// D-Pad Down into this shelf from the action bar or season controls.
class TvEpisodeShelf extends StatelessWidget {
  final List<Episode> episodes;
  final Map<int, TmdbEpisodeInfo> tmdbEpMap;
  final String? defaultThumbnailUrl;
  final String mediaItemId;
  final ValueChanged<Episode> onPlayEpisode;
  final void Function(
    Episode episode,
    String title,
    int resumeSeconds,
    bool isWatched,
  )?
  onEpisodeLongPress;

  /// Optional focus node for the first episode card.
  /// Assign this from the parent so it can programmatically move focus into
  /// the shelf on D-Pad Down from the row above.
  final FocusNode? firstCardFocusNode;

  const TvEpisodeShelf({
    super.key,
    required this.episodes,
    required this.tmdbEpMap,
    this.defaultThumbnailUrl,
    required this.mediaItemId,
    required this.onPlayEpisode,
    this.onEpisodeLongPress,
    this.firstCardFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return DpadRegion(
      enter: DpadEnterBehavior.nearest,
      child: SizedBox(
        // Compact height for sleek episode strip without scale-up clipping
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          cacheExtent: 350.0,
          clipBehavior: Clip.none,
          itemCount: episodes.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, epIdx) {
            final ep = episodes[epIdx];
            final tmdbEp = tmdbEpMap[ep.episode];
            final epThumbnail = tmdbEp?.stillUrl ?? defaultThumbnailUrl;
            final epTitle = tmdbEp?.name?.isNotEmpty == true
                ? tmdbEp!.name!
                : (ep.title.isNotEmpty ? ep.title : 'Episode ${ep.episode}');
            final epOverview = tmdbEp?.overview?.isNotEmpty == true
                ? tmdbEp!.overview!
                : (ep.overview ?? '');

            final epResume = library.getResumePosition(
              mediaItemId,
              season: ep.season,
              episode: ep.episode,
            );
            final isWatched = library.isEpisodeWatched(
              mediaItemId,
              ep.season,
              ep.episode,
            );

            return TvEpisodeCard(
              // Assign the external focus node only to the first card so the
              // parent can request focus on this shelf programmatically.
              focusNode: epIdx == 0 ? firstCardFocusNode : null,
              episode: ep,
              thumbnailUrl: epThumbnail,
              title: epTitle,
              overview: epOverview,
              resumePositionSeconds: epResume,
              isWatched: isWatched,
              onTap: () => onPlayEpisode(ep),
              onLongPress: onEpisodeLongPress != null
                  ? () => onEpisodeLongPress!(ep, epTitle, epResume, isWatched)
                  : null,
              // Edge guards: prevent D-Pad from escaping the shelf horizontally
              isFirstCard: epIdx == 0,
              isLastCard: epIdx == episodes.length - 1,
            );
          },
        ),
      ),
    );
  }
}
