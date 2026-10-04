import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/app_feature.dart';
import 'package:exalere/services/viewing_stats_service.dart';
import 'package:exalere/services/watch_party_service.dart';
import 'package:exalere/ui/screens/player/player_audio_tuner_sheet.dart';

void main() {
  group('Batch 4 - Audio Equalizer & Clarity Tuner', () {
    test('AudioFilterPreset contains all calibrated acoustic profiles', () {
      expect(AudioFilterPreset.values.length, 5);
      expect(AudioFilterPreset.flat.mpvFilter, isEmpty);
      expect(AudioFilterPreset.nightMode.mpvFilter, contains('dynaudnorm'));
      expect(
        AudioFilterPreset.dialogBoost.mpvFilter,
        contains('equalizer=f=2500'),
      );
      expect(AudioFilterPreset.bassBoost.mpvFilter, contains('bass=g=7'));
      expect(
        AudioFilterPreset.lateNightWhisper.mpvFilter,
        contains('volume=volume=1.6'),
      );
    });

    test('AudioFilterPreset descriptions and labels are user-friendly', () {
      for (final preset in AudioFilterPreset.values) {
        expect(preset.label, isNotEmpty);
        expect(preset.description, isNotEmpty);
      }
    });
  });

  group('Batch 4 - Watch Together / LAN Watch Party', () {
    test('WatchPartyState serializes and deserializes cleanly', () {
      const state = WatchPartyState(
        partyId: '4321',
        hostName: 'Living Room TV',
        mediaId: 'tmdb_movie_123',
        mediaTitle: 'Inception',
        positionMs: 45000,
        isPlaying: true,
        speed: 1.0,
        timestamp: 1670000000,
      );

      final json = state.toJson();
      expect(json['partyId'], '4321');
      expect(json['hostName'], 'Living Room TV');
      expect(json['positionMs'], 45000);
      expect(json['isPlaying'], isTrue);

      final decoded = WatchPartyState.fromJson(json);
      expect(decoded.partyId, state.partyId);
      expect(decoded.mediaTitle, state.mediaTitle);
      expect(decoded.positionMs, state.positionMs);
      expect(decoded.isPlaying, state.isPlaying);
    });

    test('WatchPartyService initial state is cleanly idle', () {
      final service = WatchPartyService();
      expect(service.isHosting, isFalse);
      expect(service.isConnected, isFalse);
      expect(service.isInParty, isFalse);
      expect(service.currentPartyPin, isNull);
    });
  });

  group('Batch 4 - Viewing Habits & Statistics Model', () {
    test(
      'ViewingStats computes formatted total time and completion percentage',
      () {
        const stats = ViewingStats(
          totalMinutesWatched: 154,
          totalUniqueTitles: 4,
          moviesWatchedCount: 2,
          episodesWatchedCount: 2,
          completedCount: 3,
          genreBreakdown: {'Sci-Fi': 2, 'Action': 2},
          topDayOfWeek: 'Saturday',
          peakTimeOfDay: 'Prime Evening (5 PM - 10 PM)',
          activeStreakDays: 3,
        );

        expect(stats.formattedTotalTime, '2 hrs 34 mins');
        expect(stats.completionPercentage, 0.75);
      },
    );

    test('ViewingStats.empty returns safe zeroes without division by zero', () {
      final empty = ViewingStats.empty();
      expect(empty.totalMinutesWatched, 0);
      expect(empty.formattedTotalTime, '0 mins');
      expect(empty.completionPercentage, 0.0);
      expect(empty.genreBreakdown, isEmpty);
    });
  });

  group('Batch 4 - AppFeaturesCatalog Verification', () {
    test('AppFeaturesCatalog contains all new Batch 4 capabilities', () {
      expect(
        AppFeaturesCatalog.allFeatures.any(
          (f) => f.id == 'voice_search_overlay',
        ),
        isTrue,
      );
      expect(
        AppFeaturesCatalog.allFeatures.any(
          (f) => f.id == 'smart_intro_outro_detector',
        ),
        isTrue,
      );
      expect(
        AppFeaturesCatalog.allFeatures.any((f) => f.id == 'watch_party_sync'),
        isTrue,
      );
      expect(
        AppFeaturesCatalog.allFeatures.any(
          (f) => f.id == 'audio_equalizer_clarity',
        ),
        isTrue,
      );
      expect(
        AppFeaturesCatalog.allFeatures.any(
          (f) => f.id == 'audio_only_ambient_mode',
        ),
        isTrue,
      );
      expect(
        AppFeaturesCatalog.allFeatures.any(
          (f) => f.id == 'viewing_habits_insights',
        ),
        isTrue,
      );
    });

    test('Search finds newly introduced Batch 4 features by keyword', () {
      final voiceResults = AppFeaturesCatalog.search('voice');
      expect(voiceResults.any((f) => f.id == 'voice_search_overlay'), isTrue);

      final partyResults = AppFeaturesCatalog.search('watch party');
      expect(partyResults.any((f) => f.id == 'watch_party_sync'), isTrue);

      final equalizerResults = AppFeaturesCatalog.search('equalizer');
      expect(
        equalizerResults.any((f) => f.id == 'audio_equalizer_clarity'),
        isTrue,
      );

      final insightsResults = AppFeaturesCatalog.search('insights');
      expect(
        insightsResults.any((f) => f.id == 'viewing_habits_insights'),
        isTrue,
      );
    });
  });
}
