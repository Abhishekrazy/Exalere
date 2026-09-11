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

    return Consumer<LibraryProvider>(
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
            // Season label + pill selector isolated in their own traversal
            // group so D-Pad Right through pills never jumps to "Mark Season".
            FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                  if (seasons.length > 1) ...[
                    const SizedBox(width: 16),
                    TvSeasonSelector(
                      seasonCount: seasons.length,
                      selectedSeasonIndex: selectedSeasonIndex,
                      onSeasonSelected: onSeasonSelected,
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            // "Mark Season" button is in its own traversal group so it does
            // not receive spatial nav focus from the season pill D-Pad Right.
            // It is reachable via D-Pad Right from within the action bar row
            // when no more season pills exist to the right, or via D-Pad Down
            // from whatever is directly above it.
            FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: TvFocusable(
                scaleFactor: 1.08,
                shape: context.tokens.shapePill,
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
                        shape: context.tokens.shapeSm,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: ShapeDecoration(
                    color: isSeasonWatched
                        ? context.tokens.primaryAccent.withValues(alpha: 0.18)
                        : context.tokens.surfaceElevated.withValues(alpha: 0.4),
                    shape: context.tokens.getShapePill(
                      side: BorderSide(
                        color: isSeasonWatched
                            ? context.tokens.primaryAccent
                            : context.tokens.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSeasonWatched
                            ? Icons.done_all_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: isSeasonWatched
                            ? context.tokens.primaryAccent
                            : context.tokens.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isSeasonWatched ? 'Season Watched' : 'Mark Season',
                        style: TextStyle(
                          color: isSeasonWatched
                              ? context.tokens.primaryAccent
                              : context.tokens.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
