import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../providers/library_provider.dart';
import '../../../services/tmdb_service.dart';
import 'tv_episode_card.dart';

/// Horizontal episode shelf for Android TV details screen.
class TvEpisodeShelf extends StatelessWidget {
  final List<Episode> episodes;
  final Map<int, TmdbEpisodeInfo> tmdbEpMap;
  final String? defaultThumbnailUrl;
  final String mediaItemId;
  final ValueChanged<Episode> onPlayEpisode;

  const TvEpisodeShelf({
    super.key,
    required this.episodes,
    required this.tmdbEpMap,
    this.defaultThumbnailUrl,
    required this.mediaItemId,
    required this.onPlayEpisode,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        cacheExtent: 350.0,
        clipBehavior: Clip.none,
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
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
            episode: ep,
            thumbnailUrl: epThumbnail,
            title: epTitle,
            overview: epOverview,
            resumePositionSeconds: epResume,
            isWatched: isWatched,
            onTap: () => onPlayEpisode(ep),
          );
        },
      ),
    );
  }
}
