import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/verified_providers.dart';

/// Does a verified add-on answer at all for a title it did not pick?
///
/// The self-test resolves whatever its own search or catalogue offers, which a
/// dead-for-everything-but-one-entry index still passes. This asks every
/// searchable add-on about a film and a series it did not choose, and requires at
/// least one of them to resolve — an add-on that answers neither is alive only by
/// the accident of the first test's subject.
///
///   flutter test test/foreign_subject_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  HttpOverrides.global = null;

  test(
    'a verified add-on answers a subject it did not choose',
    () async {
      final both = <String>[];
      final movieOnly = <String>[];
      final seriesOnly = <String>[];
      final neither = <String>[];

      for (final id in VerifiedProviders.ids) {
        final plugin = createPlugin(
          ExalerePluginConfig(
            id: id,
            name: id,
            baseUrl: '$id://engine',
            addedAt: DateTime.now(),
          ),
        );
        // Catalogue-only add-ons never claim to resolve a foreign id; their own
        // catalogue is the only path they advertise, and the first-run matrix
        // covers that.
        if (!plugin.supportsSearch) continue;
        Future<int> resolve({
          required String subjectId,
          required String title,
          required bool series,
        }) async {
          try {
            final streams = await plugin
                .getStreams(
                  subjectId: subjectId,
                  title: title,
                  imdbId: subjectId,
                  season: series ? 1 : null,
                  episode: series ? 1 : null,
                  isSeries: series,
                )
                .timeout(const Duration(seconds: 30));
            return streams.length;
          } catch (_) {
            return 0;
          }
        }

        final movie = await resolve(
          subjectId: 'tt1160419',
          title: 'Dune',
          series: false,
        );
        final series = await resolve(
          subjectId: 'tt0388629',
          title: 'One Piece',
          series: true,
        );
        // ignore: avoid_print
        print('${id.padRight(15)} movie=$movie series=$series');
        if (movie > 0 && series > 0) {
          both.add(id);
        } else if (movie > 0) {
          movieOnly.add(id);
        } else if (series > 0) {
          seriesOnly.add(id);
        } else {
          neither.add(id);
        }
      }

      // ignore: avoid_print
      print(
        'both=${both.length} movieOnly=$movieOnly seriesOnly=$seriesOnly '
        'neither=$neither',
      );

      expect(
        neither,
        isEmpty,
        reason:
            'these resolve neither a foreign film nor a foreign series: '
            '$neither',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
    skip: !live,
  );
}
