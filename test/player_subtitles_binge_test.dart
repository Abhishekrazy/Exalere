import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/ui/screens/player/player_next_episode_card.dart';
import 'package:exalere/ui/screens/player/player_playback_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Next Episode Auto-Play & Binge Helpers', () {
    final sampleDetails = MediaDetails(
      id: 'show-1',
      title: 'Dark Matter',
      mediaType: MediaType.series,
      description: 'Sci-fi thriller series',
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: 2,
          episodes: [
            const Episode(title: 'Pilot', season: 1, episode: 1),
            const Episode(title: 'Chapter Two', season: 1, episode: 2),
          ],
        ),
        Season(
          seasonNumber: 2,
          episodeCount: 1,
          episodes: [const Episode(title: 'Rebirth', season: 2, episode: 1)],
        ),
      ],
    );

    test('EpisodeHelper.findNextEpisode finds next episode in same season', () {
      final next = EpisodeHelper.findNextEpisode(
        details: sampleDetails,
        currentSeason: 1,
        currentEpisode: 1,
      );
      expect(next, isNotNull);
      expect(next!.season, 1);
      expect(next.episode, 2);
      expect(next.title, 'Chapter Two');
    });

    test(
      'EpisodeHelper.findNextEpisode advances to next season when season ends',
      () {
        final next = EpisodeHelper.findNextEpisode(
          details: sampleDetails,
          currentSeason: 1,
          currentEpisode: 2,
        );
        expect(next, isNotNull);
        expect(next!.season, 2);
        expect(next.episode, 1);
        expect(next.title, 'Rebirth');
      },
    );

    test(
      'EpisodeHelper.findNextEpisode returns null when series has no more episodes',
      () {
        final next = EpisodeHelper.findNextEpisode(
          details: sampleDetails,
          currentSeason: 2,
          currentEpisode: 1,
        );
        expect(next, isNull);
      },
    );

    test('EpisodeHelper.findCurrentEpisode locates active episode', () {
      final current = EpisodeHelper.findCurrentEpisode(
        details: sampleDetails,
        currentSeason: 1,
        currentEpisode: 2,
      );
      expect(current, isNotNull);
      expect(current!.season, 1);
      expect(current.episode, 2);
      expect(current.title, 'Chapter Two');
    });
  });

  group('PlayerNextEpisodeCountdownCard Widget Tests', () {
    testWidgets(
      'renders countdown card with title, countdown and action buttons',
      (tester) async {
        bool playNowTapped = false;
        bool cancelTapped = false;

        const testEpisode = Episode(
          title: 'The Unfolding',
          season: 1,
          episode: 2,
        );

        final appProvider = AppProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: appProvider,
            child: MaterialApp(
              theme: appProvider.currentTheme.themeData,
              home: Scaffold(
                body: PlayerNextEpisodeCountdownCard(
                  nextEpisode: testEpisode,
                  countdownSeconds: 12,
                  onPlayNow: () => playNowTapped = true,
                  onCancel: () => cancelTapped = true,
                  isTv: false,
                ),
              ),
            ),
          ),
        );

        expect(find.text('UP NEXT IN 12s'), findsOneWidget);
        expect(find.text('Season 1 • Episode 2'), findsOneWidget);
        expect(find.text('The Unfolding'), findsOneWidget);
        expect(find.text('Play Now (12s)'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(find.text('Play Now (12s)'));
        await tester.pumpAndSettle();
        expect(playNowTapped, isTrue);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(cancelTapped, isTrue);
      },
    );
  });

  group('Subtitle Timing Offset Math Tests', () {
    test('Subtitle delay clamping logic enforces valid bounds [-10s, 10s]', () {
      double delay = 0.0;
      double adjust(double current, double delta) {
        return double.parse(
          (current + delta).clamp(-10.0, 10.0).toStringAsFixed(2),
        );
      }

      delay = adjust(delay, 0.5);
      expect(delay, 0.5);

      delay = adjust(delay, 0.1);
      expect(delay, 0.6);

      delay = adjust(delay, -0.5);
      expect(delay, 0.1);

      // Clamping upper
      delay = adjust(9.8, 0.5);
      expect(delay, 10.0);

      // Clamping lower
      delay = adjust(-9.8, -0.5);
      expect(delay, -10.0);
    });
  });
}
