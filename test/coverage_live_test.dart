import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/verified_providers.dart';

/// What does a user actually get with every verified add-on installed?
///
/// The badges say each add-on resolves *something*; they do not say whether a
/// popular film and two popular series are covered, which is the question a person
/// installing these asks. Measured 2026-11-20: Dune 12 of 19, Breaking Bad 13 of
/// 19, Attack on Titan 16 of 19.
///
/// The floor below is deliberate and loose (8 of 19). It is not a coverage target;
/// it is an early warning for a shared-code change that quietly breaks many add-ons
/// at once — round 82's broken archive pattern took several to zero before anyone
/// noticed, and one title failing everywhere is the shape of that bug.
///
///   flutter test test/coverage_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  HttpOverrides.global = null;

  const subjects = <String, ({String id, String title, bool series})>{
    'Dune': (id: 'tt1160419', title: 'Dune', series: false),
    'Breaking Bad': (id: 'tt0903747', title: 'Breaking Bad', series: true),
    'Attack on Titan': (
      id: 'tt2560140',
      title: 'Attack on Titan',
      series: true,
    ),
  };

  test(
    'coverage of three popular titles',
    () async {
      final coverage = <String, List<String>>{
        for (final k in subjects.keys) k: [],
      };
      final failures = <String>[];

      for (final id in VerifiedProviders.ids) {
        final plugin = createPlugin(
          ExalerePluginConfig(
            id: id,
            name: id,
            baseUrl: '$id://engine',
            addedAt: DateTime.now(),
          ),
        );
        for (final entry in subjects.entries) {
          final subject = entry.value;
          try {
            final streams = await plugin
                .getStreams(
                  subjectId: subject.id,
                  title: subject.title,
                  imdbId: subject.id,
                  season: subject.series ? 1 : null,
                  episode: subject.series ? 1 : null,
                  isSeries: subject.series,
                )
                .timeout(const Duration(seconds: 25));
            if (streams.isNotEmpty) {
              coverage[entry.key]!.add(id);
            }
          } catch (error) {
            failures.add('$id/${entry.key}: $error');
          }
        }
      }

      for (final entry in coverage.entries) {
        // ignore: avoid_print
        print(
          '${entry.key.padRight(16)} ${entry.value.length}/'
          '${VerifiedProviders.ids.length} -> ${entry.value.join(', ')}',
        );
      }
      // ignore: avoid_print
      print('threw: ${failures.length}');
      for (final failure in failures.take(6)) {
        // ignore: avoid_print
        print('   $failure');
      }

      const floor = 8;
      for (final entry in coverage.entries) {
        expect(
          entry.value.length,
          greaterThanOrEqualTo(floor),
          reason:
              '${entry.key} resolves from only ${entry.value.length} verified '
              'add-ons; a shared change may have broken several at once',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
    skip: !live,
  );
}
