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
  final FocusNode? selectedSeasonFocusNode;
  final FocusNode? markSeasonFocusNode;
  final bool Function()? onUpFocus;
  final bool Function()? onDownFocus;

  const TvSeasonControls({
    super.key,
    required this.mediaItemId,
    required this.seasons,
    required this.selectedSeasonIndex,
    required this.onSeasonSelected,
    this.selectedSeasonFocusNode,
    this.markSeasonFocusNode,
    this.onUpFocus,
    this.onDownFocus,
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

        Widget buildMarkSeasonButton({required bool isSingleSeason}) {
          return TvFocusable(
            focusNode: markSeasonFocusNode,
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
            onDirection: (direction) {
              if (direction == TraversalDirection.left) {
                if (!isSingleSeason && selectedSeasonFocusNode != null) {
                  selectedSeasonFocusNode!.requestFocus();
                  return true;
                }
                return true; // Clamp left
              }
              if (direction == TraversalDirection.right) {
                return true; // Clamp right
              }
              if (direction == TraversalDirection.up && onUpFocus != null) {
                return onUpFocus!();
              }
              if (direction == TraversalDirection.down && onDownFocus != null) {
                return onDownFocus!();
              }
              return false;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          );
        }

        if (seasons.length > 1) {
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
              const SizedBox(width: 16),
              TvSeasonSelector(
                seasonCount: seasons.length,
                selectedSeasonIndex: selectedSeasonIndex,
                onSeasonSelected: onSeasonSelected,
                selectedSeasonFocusNode: selectedSeasonFocusNode,
                onRightFromLast: () {
                  markSeasonFocusNode?.requestFocus();
                  return true;
                },
                onUpFocus: onUpFocus,
                onDownFocus: onDownFocus,
              ),
              const Spacer(),
              buildMarkSeasonButton(isSingleSeason: false),
            ],
          );
        } else {
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
              buildMarkSeasonButton(isSingleSeason: true),
            ],
          );
        }
      },
    );
  }
}
