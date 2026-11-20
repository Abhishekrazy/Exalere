import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/verified_providers.dart';

/// Which verified add-ons can play a series opened from *another* add-on.
///
/// The self-test and the first-run matrix both hand each add-on an item from its
/// own catalogue, which is the easy path. A user also opens a series from TMDB
/// or from a different add-on, and then the subject is an IMDb id the add-on has
/// never seen: this prints who copes and who does not, so the blind spots are
/// measured instead of assumed.
///
///   flutter test test/cross_provider_series_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  // The app runs with platform bindings; MovieBox keeps its visitor session in
  // SharedPreferences and aborts instantly without them.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  HttpOverrides.global = null;

  test(
    'cross-provider series resolution',
    () async {
      const title = 'One Piece';
      const imdb = 'tt0388629';

      final failed = <String>[];
      for (final id in VerifiedProviders.ids) {
        final plugin = createPlugin(
          ExalerePluginConfig(
            id: id,
            name: id,
            baseUrl: '$id://engine',
            addedAt: DateTime.now(),
          ),
        );
        final watch = Stopwatch()..start();
        var count = 0;
        try {
          final streams = await plugin
              .getStreams(
                subjectId: imdb,
                title: title,
                year: '1999',
                imdbId: imdb,
                season: 1,
                episode: 1,
                isSeries: true,
              )
              .timeout(const Duration(seconds: 25));
          count = streams.length;
        } catch (error) {
          count = -1;
        }
        watch.stop();
        // ignore: avoid_print
        print(
          '${id.padRight(15)} series=${count.toString().padLeft(4)} '
          '${watch.elapsedMilliseconds.toString().padLeft(5)} ms',
        );
        if (count <= 0) failed.add(id);
      }
      // ignore: avoid_print
      print('blind to a foreign series: ${failed.join(', ')}');

      // The install path is not the thing under test here — the point is the
      // measurement — but an empty result everywhere would mean the harness broke
      // rather than the add-ons being honest about their ids.
      expect(
        VerifiedProviders.ids.length - failed.length,
        greaterThan(0),
        reason: 'at least one add-on must resolve a foreign series',
      );
    },
    timeout: const Timeout(Duration(minutes: 8)),
    skip: !live,
  );
}
