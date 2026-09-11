import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/library_provider.dart';
import '../../theme/app_tokens.dart';
import '../episode_tile.dart';

/// Responsive episodes section for TV series on the details screen:
/// Renders season selector header and switches between 16:9 grid (desktop/tablet)
/// and compact card list (mobile).
class DetailsEpisodesSection extends StatelessWidget {
  final MediaItem seriesItem;
  final List<Season> seasons;
  final int selectedSeasonIdx;
  final int selectedEpisodeIdx;
  final ValueChanged<int> onSeasonChanged;
  final void Function(int season, int episode) onEpisodePlay;
  final double screenWidth;

  const DetailsEpisodesSection({
    super.key,
    required this.seriesItem,
    required this.seasons,
    required this.selectedSeasonIdx,
    required this.selectedEpisodeIdx,
    required this.onSeasonChanged,
    required this.onEpisodePlay,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    final currentSeason =
        seasons[selectedSeasonIdx.clamp(0, seasons.length - 1)];
    final episodes = currentSeason.episodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSeasonHeader(context, currentSeason),
        const SizedBox(height: 16),
        _buildEpisodesList(context, episodes),
      ],
    );
  }

  Widget _buildSeasonHeader(BuildContext context, Season currentSeason) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Episodes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: tokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Season ${currentSeason.seasonNumber} • ${currentSeason.episodes.length} Episodes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Consumer<LibraryProvider>(
          builder: (context, library, _) {
            final epNumbers = currentSeason.episodes
                .map((e) => e.episode)
                .toList();
            final isSeasonWatched = library.isSeasonWatched(
              seriesItem.id,
              currentSeason.seasonNumber,
              epNumbers,
            );

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: isSeasonWatched
                      ? 'Mark Season ${currentSeason.seasonNumber} as Unwatched'
                      : 'Mark Season ${currentSeason.seasonNumber} as Watched',
                  child: InkWell(
                    onTap: () async {
                      await library.toggleSeasonWatched(
                        seriesId: seriesItem.id,
                        season: currentSeason.seasonNumber,
                        episodeNumbers: epNumbers,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isSeasonWatched
                                  ? 'Marked Season ${currentSeason.seasonNumber} as unwatched'
                                  : 'Marked Season ${currentSeason.seasonNumber} as watched',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: tokens.surfaceElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: tokens.borderRadiusSm,
                              side: BorderSide(color: tokens.borderSubtle),
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSeasonWatched
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : tokens.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSeasonWatched
                              ? theme.colorScheme.primary
                              : tokens.borderSubtle,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadowColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isSeasonWatched
                            ? Icons.done_all_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: isSeasonWatched
                            ? theme.colorScheme.primary
                            : tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                if (seasons.length > 1) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: 'Select Season',
                    initialValue: selectedSeasonIdx,
                    onSelected: (i) {
                      if (i != selectedSeasonIdx) {
                        onSeasonChanged(i);
                      }
                    },
                    color: tokens.surfaceElevated,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: tokens.borderRadiusMd,
                      side: BorderSide(color: tokens.borderSubtle, width: 1),
                    ),
                    itemBuilder: (context) {
                      return List.generate(seasons.length, (i) {
                        final s = seasons[i];
                        final isSelected = selectedSeasonIdx == i;
                        return PopupMenuItem<int>(
                          value: i,
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : tokens.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Season ${s.seasonNumber}',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${s.episodes.length} eps',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusPill,
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadowColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Season ${currentSeason.seasonNumber}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: tokens.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEpisodesList(BuildContext context, List<Episode> episodes) {
    final tokens = context.tokens;

    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No episode details available for this season.',
            style: TextStyle(color: tokens.textMuted),
          ),
        ),
      );
    }

    if (screenWidth >= 750) {
      final crossAxisCount = screenWidth >= 1150
          ? 4
          : (screenWidth >= 850 ? 3 : 2);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: episodes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.25,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, epIdx) {
          final ep = episodes[epIdx];
          final isSelected = selectedEpisodeIdx == epIdx;
          final library = context.watch<LibraryProvider>();
          final epHistory = library.getHistoryItem(
            seriesItem.id,
            season: ep.season,
            episode: ep.episode,
          );
          final isWatched = library.isEpisodeWatched(
            seriesItem.id,
            ep.season,
            ep.episode,
          );
          return EpisodeGridCard(
            episode: ep,
            isSelected: isSelected,
            progress: epHistory?.progress,
            isWatched: isWatched,
            onToggleWatched: () => library.toggleEpisodeWatched(
              series: seriesItem,
              season: ep.season,
              episode: ep.episode,
            ),
            onTap: () => onEpisodePlay(ep.season, ep.episode),
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, epIdx) {
        final ep = episodes[epIdx];
        final isSelected = selectedEpisodeIdx == epIdx;
        final library = context.watch<LibraryProvider>();
        final epHistory = library.getHistoryItem(
          seriesItem.id,
          season: ep.season,
          episode: ep.episode,
        );
        final isWatched = library.isEpisodeWatched(
          seriesItem.id,
          ep.season,
          ep.episode,
        );
        return EpisodeTile(
          episode: ep,
          isSelected: isSelected,
          progress: epHistory?.progress,
          isWatched: isWatched,
          onToggleWatched: () => library.toggleEpisodeWatched(
            series: seriesItem,
            season: ep.season,
            episode: ep.episode,
          ),
          onTap: () => onEpisodePlay(ep.season, ep.episode),
        );
      },
    );
  }
}
