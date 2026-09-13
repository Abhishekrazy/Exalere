import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/library_provider.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/tv/tv_details_action_bar.dart';
import 'package:exalere/ui/widgets/tv/tv_episode_shelf.dart';
import 'package:exalere/ui/widgets/tv/tv_more_like_this_shelf.dart';
import 'package:exalere/ui/widgets/tv/tv_season_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildDetailsGridHarness({
    required int seasonCount,
    required bool isSeries,
    required FocusNode playNode,
    required FocusNode seasonPillNode,
    required FocusNode markSeasonNode,
    required FocusNode firstEpisodeNode,
    required FocusNode firstRecNode,
    List<MediaItem> relatedItems = const [],
  }) {
    final seasons = List.generate(
      seasonCount,
      (sIdx) => Season(
        seasonNumber: sIdx + 1,
        episodeCount: 3,
        episodes: List.generate(
          3,
          (eIdx) => Episode(
            season: sIdx + 1,
            episode: eIdx + 1,
            title: 'S${sIdx + 1} E${eIdx + 1}',
          ),
        ),
      ),
    );

    int selectedSeason = 0;

    void safeFocus(FocusNode node) {
      if (node.canRequestFocus) {
        node.requestFocus();
      }
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
      ],
      child: MaterialApp(
        theme: AppThemes.netflixBlack.themeData,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 0: Action Bar
                    TvDetailsActionBar(
                      playButtonFocusNode: playNode,
                      playButtonLabel: 'Play',
                      hasResume: false,
                      onPlay: () {},
                      isFavorite: false,
                      onToggleFavorite: () {},
                      trailerYoutubeKey: 'trailer_key',
                      onOpenTrailer: () {},
                      onDownFocus: () {
                        if (isSeries && seasons.isNotEmpty) {
                          if (seasons.length > 1) {
                            safeFocus(seasonPillNode);
                          } else {
                            safeFocus(markSeasonNode);
                          }
                          return true;
                        } else if (relatedItems.isNotEmpty) {
                          safeFocus(firstRecNode);
                          return true;
                        }
                        return false;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Row 1 & 2: TV Series Controls and Episodes
                    if (isSeries && seasons.isNotEmpty) ...[
                      TvSeasonControls(
                        mediaItemId: 'series_1',
                        seasons: seasons,
                        selectedSeasonIndex: selectedSeason,
                        onSeasonSelected: (idx) {
                          setState(() => selectedSeason = idx);
                        },
                        selectedSeasonFocusNode: seasonPillNode,
                        markSeasonFocusNode: markSeasonNode,
                        onUpFocus: () {
                          safeFocus(playNode);
                          return true;
                        },
                        onDownFocus: () {
                          safeFocus(firstEpisodeNode);
                          return true;
                        },
                      ),
                      const SizedBox(height: 12),
                      TvEpisodeShelf(
                        episodes: seasons[selectedSeason].episodes,
                        tmdbEpMap: const {},
                        mediaItemId: 'series_1',
                        onPlayEpisode: (_) {},
                        firstCardFocusNode: firstEpisodeNode,
                        onUpFocus: () {
                          if (seasons.length > 1) {
                            safeFocus(seasonPillNode);
                          } else if (seasons.length == 1) {
                            safeFocus(markSeasonNode);
                          } else {
                            safeFocus(playNode);
                          }
                          return true;
                        },
                        onDownFocus: () {
                          if (relatedItems.isNotEmpty) {
                            safeFocus(firstRecNode);
                            return true;
                          }
                          return false;
                        },
                      ),
                    ],

                    // Row 3: More Like This
                    if (relatedItems.isNotEmpty)
                      TvMoreLikeThisShelf(
                        items: relatedItems,
                        firstCardFocusNode: firstRecNode,
                        onItemSelect: (_) {},
                        onUpFocus: () {
                          if (isSeries && seasons.isNotEmpty) {
                            safeFocus(firstEpisodeNode);
                          } else {
                            safeFocus(playNode);
                          }
                          return true;
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  group('2D Row-Grid Navigation Suite', () {
    testWidgets(
      'Multi-season series: Row 0 ↔ Row 1 ↔ Row 2 ↔ Row 3 full cycle',
      (WidgetTester tester) async {
        final playNode = FocusNode(debugLabel: 'PlayNode');
        final seasonPillNode = FocusNode(debugLabel: 'SeasonPillNode');
        final markSeasonNode = FocusNode(debugLabel: 'MarkSeasonNode');
        final firstEpNode = FocusNode(debugLabel: 'FirstEpNode');
        final firstRecNode = FocusNode(debugLabel: 'FirstRecNode');

        final recItems = [
          MediaItem(id: 'rec_1', title: 'Rec 1', mediaType: MediaType.movie),
          MediaItem(id: 'rec_2', title: 'Rec 2', mediaType: MediaType.movie),
        ];

        await tester.pumpWidget(
          buildDetailsGridHarness(
            seasonCount: 2,
            isSeries: true,
            playNode: playNode,
            seasonPillNode: seasonPillNode,
            markSeasonNode: markSeasonNode,
            firstEpisodeNode: firstEpNode,
            firstRecNode: firstRecNode,
            relatedItems: recItems,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial focus on Play (Row 0)
        playNode.requestFocus();
        await tester.pumpAndSettle();
        expect(playNode.hasFocus, isTrue);

        // 2. Down from Play -> Row 1 (Season 1 Pill)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(seasonPillNode.hasFocus, isTrue);

        // 3. Right on Row 1 -> Season 2 Pill
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        // 4. Right from Season 2 Pill -> Mark Season Watched
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(markSeasonNode.hasFocus, isTrue);

        // 5. Left from Mark Season -> Back to Season Pill
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(seasonPillNode.hasFocus, isTrue);

        // 6. Down from Season Pill -> Row 2 (Episode 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(firstEpNode.hasFocus, isTrue);

        // 7. Down from Episode 1 -> Row 3 (More Like This card 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(firstRecNode.hasFocus, isTrue);

        // 8. Up from More Like This -> Row 2 (Episode 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(firstEpNode.hasFocus, isTrue);

        // 9. Up from Episode 1 -> Row 1 (Season Pill)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(seasonPillNode.hasFocus, isTrue);

        // 10. Up from Season Pill -> Row 0 (Play)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(playNode.hasFocus, isTrue);

        playNode.dispose();
        seasonPillNode.dispose();
        markSeasonNode.dispose();
        firstEpNode.dispose();
        firstRecNode.dispose();
      },
    );

    testWidgets(
      'Single-season series: Row 0 ↔ Row 1 (Mark Season) ↔ Row 2 ↔ Row 3',
      (WidgetTester tester) async {
        final playNode = FocusNode(debugLabel: 'PlayNode');
        final seasonPillNode = FocusNode(debugLabel: 'SeasonPillNode');
        final markSeasonNode = FocusNode(debugLabel: 'MarkSeasonNode');
        final firstEpNode = FocusNode(debugLabel: 'FirstEpNode');
        final firstRecNode = FocusNode(debugLabel: 'FirstRecNode');

        final recItems = [
          MediaItem(id: 'rec_1', title: 'Rec 1', mediaType: MediaType.movie),
        ];

        await tester.pumpWidget(
          buildDetailsGridHarness(
            seasonCount: 1,
            isSeries: true,
            playNode: playNode,
            seasonPillNode: seasonPillNode,
            markSeasonNode: markSeasonNode,
            firstEpisodeNode: firstEpNode,
            firstRecNode: firstRecNode,
            relatedItems: recItems,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial focus on Play (Row 0)
        playNode.requestFocus();
        await tester.pumpAndSettle();
        expect(playNode.hasFocus, isTrue);

        // 2. Down from Play -> Row 1 (Mark Season directly!)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(markSeasonNode.hasFocus, isTrue);

        // 3. Down from Mark Season -> Row 2 (Episode 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(firstEpNode.hasFocus, isTrue);

        // 4. Down from Episode 1 -> Row 3 (Recommendation)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(firstRecNode.hasFocus, isTrue);

        // 5. Up from Recommendation -> Row 2 (Episode 1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(firstEpNode.hasFocus, isTrue);

        // 6. Up from Episode 1 -> Row 1 (Mark Season)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(markSeasonNode.hasFocus, isTrue);

        // 7. Up from Mark Season -> Row 0 (Play)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(playNode.hasFocus, isTrue);

        playNode.dispose();
        seasonPillNode.dispose();
        markSeasonNode.dispose();
        firstEpNode.dispose();
        firstRecNode.dispose();
      },
    );

    testWidgets('Movie mode: Row 0 (Action Bar) ↔ Row 3 (More Like This)', (
      WidgetTester tester,
    ) async {
      final playNode = FocusNode(debugLabel: 'PlayNode');
      final seasonPillNode = FocusNode(debugLabel: 'SeasonPillNode');
      final markSeasonNode = FocusNode(debugLabel: 'MarkSeasonNode');
      final firstEpNode = FocusNode(debugLabel: 'FirstEpNode');
      final firstRecNode = FocusNode(debugLabel: 'FirstRecNode');

      final recItems = [
        MediaItem(id: 'rec_1', title: 'Rec 1', mediaType: MediaType.movie),
      ];

      await tester.pumpWidget(
        buildDetailsGridHarness(
          seasonCount: 0,
          isSeries: false,
          playNode: playNode,
          seasonPillNode: seasonPillNode,
          markSeasonNode: markSeasonNode,
          firstEpisodeNode: firstEpNode,
          firstRecNode: firstRecNode,
          relatedItems: recItems,
        ),
      );
      await tester.pumpAndSettle();

      playNode.requestFocus();
      await tester.pumpAndSettle();
      expect(playNode.hasFocus, isTrue);

      // Down from Play -> Row 3 directly (More Like This)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(firstRecNode.hasFocus, isTrue);

      // Up from More Like This -> Row 0 directly (Play)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(playNode.hasFocus, isTrue);

      playNode.dispose();
      seasonPillNode.dispose();
      markSeasonNode.dispose();
      firstEpNode.dispose();
      firstRecNode.dispose();
    });
  });
}
