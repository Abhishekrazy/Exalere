import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/media_details.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

/// Modal bottom sheet for viewing and switching episodes while inside the player.
class PlayerEpisodesSheet extends StatefulWidget {
  final MediaDetails details;
  final int currentSeason;
  final int currentEpisode;
  final void Function(int season, int episode) onEpisodeSelected;

  const PlayerEpisodesSheet({
    super.key,
    required this.details,
    required this.currentSeason,
    required this.currentEpisode,
    required this.onEpisodeSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required MediaDetails details,
    required int currentSeason,
    required int currentEpisode,
    required void Function(int season, int episode) onEpisodeSelected,
  }) {
    final tokens = context.tokens;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final modalHeight = (screenHeight * 0.75).clamp(320.0, 500.0);

    return showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surfaceElevated,
      shape: tokens.getShapeBorder(radius: tokens.cardRadius + 8),
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: modalHeight,
          child: PlayerEpisodesSheet(
            details: details,
            currentSeason: currentSeason,
            currentEpisode: currentEpisode,
            onEpisodeSelected: onEpisodeSelected,
          ),
        );
      },
    );
  }

  @override
  State<PlayerEpisodesSheet> createState() => _PlayerEpisodesSheetState();
}

class _PlayerEpisodesSheetState extends State<PlayerEpisodesSheet> {
  late int _selectedSeasonNumber;

  @override
  void initState() {
    super.initState();
    _selectedSeasonNumber = widget.currentSeason > 0
        ? widget.currentSeason
        : (widget.details.seasons.isNotEmpty
              ? widget.details.seasons.first.seasonNumber
              : 1);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final seasons = widget.details.seasons;
    final currentSeasonData = seasons.firstWhere(
      (s) => s.seasonNumber == _selectedSeasonNumber,
      orElse: () => seasons.isNotEmpty
          ? seasons.first
          : const Season(seasonNumber: 1, episodeCount: 0, episodes: []),
    );
    final episodes = currentSeasonData.episodes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.video_library_rounded,
                    color: tokens.primaryAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Episodes',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TvFocusable(
                onTap: () => Navigator.of(context).pop(),
                shape: tokens.shapePill,
                borderRadius: tokens.borderRadiusPill,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: tokens.getShapeDecoration(
                    color: tokens.surfaceCard.withValues(alpha: 0.6),
                    radius: tokens.cardRadius * 0.8,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: tokens.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Season Tabs (if more than 1 season)
          if (seasons.length > 1) ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                cacheExtent: 350.0,
                itemCount: seasons.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final s = seasons[idx];
                  final isSelected = s.seasonNumber == _selectedSeasonNumber;
                  return TvFocusable(
                    onTap: () {
                      setState(() => _selectedSeasonNumber = s.seasonNumber);
                    },
                    shape: tokens.shapePill,
                    borderRadius: tokens.borderRadiusPill,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: isSelected
                            ? tokens.primaryAccent
                            : tokens.surfaceCard,
                        radius: tokens.cardRadius * 0.8,
                        side: BorderSide(
                          color: isSelected
                              ? tokens.primaryAccent
                              : tokens.borderSubtle,
                        ),
                      ),
                      child: Text(
                        'Season ${s.seasonNumber}',
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : tokens.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Episodes List
          Expanded(
            child: episodes.isEmpty
                ? Center(
                    child: Text(
                      'No episodes available for this season',
                      style: TextStyle(color: tokens.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: episodes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ep = episodes[index];
                      final isCurrent =
                          _selectedSeasonNumber == widget.currentSeason &&
                          ep.episode == widget.currentEpisode;

                      return TvFocusable(
                        autofocus: isCurrent,
                        scaleFactor: 1.02,
                        shape: tokens.shapeSm,
                        borderRadius: tokens.borderRadiusSm,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onEpisodeSelected(
                            _selectedSeasonNumber,
                            ep.episode,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: tokens.getShapeDecoration(
                            color: isCurrent
                                ? tokens.primaryAccent.withValues(alpha: 0.15)
                                : tokens.surfaceCard.withValues(alpha: 0.7),
                            radius: tokens.cardRadius * 0.8,
                            side: BorderSide(
                              color: isCurrent
                                  ? tokens.primaryAccent
                                  : tokens.borderSubtle,
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Thumbnail or Episode Badge
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  tokens.cardRadius * 0.5,
                                ),
                                child:
                                    ep.thumbnail != null &&
                                        ep.thumbnail!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: ep.thumbnail!,
                                        width: 100,
                                        height: 58,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              width: 100,
                                              height: 58,
                                              color: tokens.surfaceCard,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: 100,
                                              height: 58,
                                              color: tokens.surfaceCard,
                                              child: Icon(
                                                Icons.movie_outlined,
                                                color: tokens.textMuted,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        width: 100,
                                        height: 58,
                                        color: tokens.surfaceCard,
                                        alignment: Alignment.center,
                                        child: Text(
                                          'E${ep.episode}',
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 14),

                              // Title & Overview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${ep.episode}. ${ep.title}',
                                          style: TextStyle(
                                            color: isCurrent
                                                ? tokens.primaryAccent
                                                : tokens.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: tokens
                                                .getShapeDecoration(
                                                  color: tokens.primaryAccent,
                                                  radius:
                                                      tokens.cardRadius * 0.4,
                                                ),
                                            child: Text(
                                              'NOW PLAYING',
                                              style: TextStyle(
                                                color:
                                                    theme.colorScheme.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (ep.overview != null &&
                                        ep.overview!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        ep.overview!,
                                        style: TextStyle(
                                          color: tokens.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Play icon
                              Icon(
                                isCurrent
                                    ? Icons.equalizer_rounded
                                    : Icons.play_arrow_rounded,
                                color: isCurrent
                                    ? tokens.primaryAccent
                                    : tokens.textSecondary,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
