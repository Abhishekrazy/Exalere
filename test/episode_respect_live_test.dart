import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/plugins/plugins.dart';

/// Does the episode change the answer?
///
/// Pack-style sites publish a whole season as one set of packs, so identical
/// sources are correct there. Episode-keyed sites must return a different file per
/// episode — the same URL for episode 1 and 4 means the request is being ignored,
/// which a four-stage self-test can never catch because it only asks for one.
///
///   flutter test test/episode_respect_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  HttpOverrides.global = null;

  const ids = [
    'kisskh',
    'kickassanime',
    'animestream',
    'animeworld',
    'anikoto',
    'animesub',
    'movies4u',
    'vegamovies',
    'multimovies',
    'castle',
    'moviebox',
  ];

  test(
    'episode-keyed add-ons answer per episode',
    () async {
      const perEpisode = {
        'kisskh',
        'kickassanime',
        'animestream',
        'animeworld',
        'anikoto',
      };
      final ignored = <String>[];
      for (final id in ids) {
        final plugin = createPlugin(
          ExalerePluginConfig(
            id: id,
            name: id,
            baseUrl: '$id://engine',
            addedAt: DateTime.now(),
          ),
        );
        try {
          final hits = plugin.supportsSearch
              ? await plugin.search('one piece')
              : const <MediaItem>[];
          if (hits.isEmpty) {
            // ignore: avoid_print
            print('${id.padRight(14)} no hits');
            continue;
          }
          final subject = hits.firstWhere(
            (hit) => hit.mediaType == MediaType.series,
            orElse: () => hits.first,
          );
          final first = await plugin.getStreams(
            subjectId: subject.id,
            title: subject.title,
            season: 1,
            episode: 1,
            isSeries: true,
          );
          final fourth = await plugin.getStreams(
            subjectId: subject.id,
            title: subject.title,
            season: 1,
            episode: 4,
            isSeries: true,
          );
          final firstUrl = first.isEmpty ? '' : first.first.url;
          final fourthUrl = fourth.isEmpty ? '' : fourth.first.url;
          final verdict = firstUrl.isEmpty && fourthUrl.isEmpty
              ? 'none'
              : (firstUrl == fourthUrl ? 'SAME (pack or ignored)' : 'differs');
          // ignore: avoid_print
          print(
            '${id.padRight(14)} ep1=${first.length} ep4=${fourth.length} $verdict',
          );
          if (perEpisode.contains(id) &&
              firstUrl.isNotEmpty &&
              fourthUrl.isNotEmpty &&
              firstUrl == fourthUrl) {
            ignored.add(id);
          }
        } catch (error) {
          // ignore: avoid_print
          print('${id.padRight(14)} threw $error');
        }
      }
      // An episode-keyed add-on that ignores the episode hands the user the wrong
      // file, which is worse than returning nothing.
      expect(ignored, isEmpty, reason: 'these ignored the episode: $ignored');
    },
    timeout: const Timeout(Duration(minutes: 12)),
    skip: !live,
  );
}
