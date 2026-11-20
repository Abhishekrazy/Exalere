import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/scrapers/vega_site_config.dart';
import 'package:exalere/services/verified_providers.dart';
import 'package:exalere/services/internet_archive_provider.dart';
import 'package:exalere/services/animesalt_provider.dart';
import 'package:exalere/services/animeworld_provider.dart';
import 'package:exalere/services/animestream_provider.dart';
import 'package:exalere/services/kickassanime_provider.dart';
import 'package:exalere/services/kisskh_provider.dart';
import 'package:exalere/services/scrapers/vega_site_scraper.dart';
import 'package:exalere/services/torrentio_provider.dart';

/// Live smoke probe for the ported Vega providers.
///
/// Network access is disabled in normal widget tests, so this file is skipped
/// unless it is run explicitly:
///
/// ```
/// flutter test test/live_vega_probe_test.dart --dart-define=LIVE=1
/// ```
///
/// It is deliberately not part of CI: the sites rotate domains and rate-limit,
/// and a red run there would say nothing about the code.
void main() {
  const liveFlag = String.fromEnvironment('LIVE');

  const live = liveFlag == '1' || liveFlag == 'true';
  HttpOverrides.global = null;

  test(
    'ported providers list and resolve live',
    () async {
      final failures = <String>[];

      for (final config in VegaSiteConfig.all) {
        // A provider the app itself knows is out of order must not fail this
        // probe: the record lives in verified_providers.dart.
        final known = VerifiedProviders.unavailableReason(config.id);
        if (known != null) {
          // ignore: avoid_print
          print('SKIP ${config.id.padRight(12)} $known');
          continue;
        }

        final plugin = VegaSitePlugin(config);
        await plugin.init();

        // Catalogue-only add-ons have no search by design; probe their listing.
        final results = plugin.supportsSearch
            ? await plugin.search('dune')
            : await plugin.getCatalogFeed();
        final listed = results.isNotEmpty;
        var streams = 0;
        String? title;
        // An archive/index page ("All Anime & Cartoon Movies List") can rank
        // first in a search; try the first few real results so the verdict is
        // about the site, not about one menu page.
        for (final item in results.take(3)) {
          try {
            final sources = await plugin.getStreams(subjectId: item.id);
            if (sources.isNotEmpty) {
              streams = sources.length;
              title = item.title;
              break;
            }
          } catch (_) {
            continue;
          }
        }
        title ??= results.isEmpty ? null : results.first.title;

        final verdict = listed && streams > 0 ? 'OK  ' : 'FAIL';
        // ignore: avoid_print
        print(
          '$verdict ${config.id.padRight(12)} search=${results.length} '
          'streams=$streams'
          '${title == null ? '' : ' first="${title.length > 60 ? title.substring(0, 60) : title}"'}',
        );
        if (!(listed && streams > 0)) failures.add(config.id);
      }

      // ignore: avoid_print
      print('failures: ${failures.join(', ')}');
      expect(failures, isEmpty, reason: 'providers without a playable stream');
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'Internet Archive lists and resolves live',
    () async {
      final provider = InternetArchiveProvider();

      final results = await provider.search('metropolis');
      // ignore: avoid_print
      print('IA search=${results.length}');
      expect(results, isNotEmpty);

      final first = results.first;
      final streams = await provider.getStreams(subjectId: first.id);
      // ignore: avoid_print
      print(
        'IA item="${first.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.quality} ${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'Torrentio indexes live',
    () async {
      final provider = TorrentioProvider();

      final streams = await provider.getStreams(
        subjectId: 'tt0133093',
        imdbId: 'tt0133093',
      );
      // ignore: avoid_print
      print(
        'TO streams=${streams.length}'
        '${streams.isEmpty ? '' : ' top=${streams.first.quality}/${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
      expect(streams.first.url, startsWith('magnet:?xt=urn:btih:'));
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'KissKh lists and resolves live',
    () async {
      final provider = KissKhProvider();

      final results = await provider.search('demon');
      // ignore: avoid_print
      print('KK search=${results.length}');
      expect(results, isNotEmpty);

      final streams = await provider.getStreams(subjectId: results.first.id);
      // ignore: avoid_print
      print(
        'KK item="${results.first.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'KickAssAnime lists and resolves live',
    () async {
      final provider = KickAssAnimeProvider();

      final shows = await provider.getCatalogFeed();
      // ignore: avoid_print
      print('KAA trending=${shows.length}');
      expect(shows, isNotEmpty);

      final streams = await provider.getStreams(
        subjectId: shows.first.id,
        episode: 1,
      );
      // ignore: avoid_print
      print(
        'KAA show="${shows.first.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.format} ${streams.first.url.substring(0, 30)}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'AnimeStream lists and resolves live',
    () async {
      final provider = AnimeStreamProvider();

      final shows = await provider.getCatalogFeed();
      // ignore: avoid_print
      print('AS trending=${shows.length}');
      expect(shows, isNotEmpty);

      final streams = await provider.getStreams(
        subjectId: shows.first.id,
        season: 1,
        episode: 1,
      );
      // ignore: avoid_print
      print(
        'AS show="${shows.first.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'AnimeSalt lists and resolves live',
    () async {
      final known = VerifiedProviders.unavailableReason('animesalt');
      if (known != null) {
        // ignore: avoid_print
        print('SKIP animesalt   $known');
        return;
      }

      final provider = AnimeSaltProvider();

      final shows = await provider.getCatalogFeed();
      // ignore: avoid_print
      print('ASalt catalog=${shows.length}');
      expect(shows, isNotEmpty);

      final show = shows.first;
      final streams = await provider.getStreams(subjectId: show.id, episode: 1);
      // ignore: avoid_print
      print(
        'ASalt show="${show.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'AnimeWorld lists and resolves live',
    () async {
      final provider = AnimeWorldProvider();

      final shows = await provider.getCatalogFeed();
      // ignore: avoid_print
      print('AW catalog=${shows.length}');
      expect(shows, isNotEmpty);

      final series = shows.firstWhere(
        (show) => show.id.contains('/series/'),
        orElse: () => shows.first,
      );
      final streams = await provider.getStreams(
        subjectId: series.id,
        season: 1,
        episode: 1,
      );
      // ignore: avoid_print
      print(
        'AW show="${series.title}" streams=${streams.length}'
        '${streams.isEmpty ? '' : ' ${streams.first.format}'}',
      );
      expect(streams, isNotEmpty);
    },
    skip: !live,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
