import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../providers/library_provider.dart';
import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';
import 'tv_season_selector.dart';

class TvSeasonControls extends StatelessWidget {
  final String mediaItemId;
  final List<Season> seasons;
  final int selectedSeasonIndex;
  final ValueChanged<int> onSeasonSelected;

  const TvSeasonControls({
    super.key,
    required this.mediaItemId,
    required this.seasons,
    required this.selectedSeasonIndex,
    required this.onSeasonSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<LibraryProvider>(
          builder: (context, library, _) {
            final selectedSeason =
                seasons[selectedSeasonIndex.clamp(0, seasons.length - 1)];
            final epNumbers = selectedSeason.episodes
                .map((e) => e.episode)
                .toList();
            final isSeasonWatched = library.isSeasonWatched(
              mediaItemId,
              selectedSeason.seasonNumber,
              epNumbers,
            );

            return Row(
              children: [
                Text(
                  'Episodes',
                  style: TextStyle(
                    color: context.tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 14),
                TvFocusable(
                  scaleFactor: 1.08,
                  borderRadius: context.tokens.borderRadiusPill,
                  onTap: () async {
                    await library.toggleSeasonWatched(
                      seriesId: mediaItemId,
                      season: selectedSeason.seasonNumber,
                      episodeNumbers: epNumbers,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isSeasonWatched
                                ? 'Marked Season ${selectedSeason.seasonNumber} as unwatched'
                                : 'Marked Season ${selectedSeason.seasonNumber} as watched',
                            style: TextStyle(
                              color: context.tokens.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: context.tokens.surfaceElevated,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: context.tokens.borderRadiusSm,
                            side: BorderSide(
                              color: context.tokens.borderSubtle,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isSeasonWatched
                          ? context.tokens.primaryAccent.withValues(alpha: 0.2)
                          : context.tokens.surfaceElevated.withValues(
                              alpha: 0.4,
                            ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSeasonWatched
                            ? context.tokens.primaryAccent
                            : context.tokens.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      isSeasonWatched
                          ? Icons.done_all_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isSeasonWatched
                          ? context.tokens.primaryAccent
                          : context.tokens.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (seasons.length > 1) ...[
          const SizedBox(height: 8),
          TvSeasonSelector(
            seasonCount: seasons.length,
            selectedSeasonIndex: selectedSeasonIndex,
            onSeasonSelected: onSeasonSelected,
          ),
        ],
      ],
    );
  }
}
