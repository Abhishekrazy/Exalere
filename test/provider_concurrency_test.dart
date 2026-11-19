import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/verified_providers.dart';

/// Resolves every verified provider **at the same time**, the way the app does
/// when a user opens a detail page with several add-ons installed. A provider
/// that only works alone (rate limits, shared mutable state, a token fetched per
/// request) fails here even though the serial self-test passes.
///
/// Run it with:
///   flutter test test/provider_concurrency_test.dart --dart-define=CONCURRENT=true
///
/// Skipped by default: it needs the real network for all twelve add-ons.
const bool _live = bool.fromEnvironment('CONCURRENT');

const Map<String, String> _bases = {
  'zeefliz': 'https://zeefliz.zze.workers.dev',
  'internetarchive': 'https://archive.org',
  'torrentio': 'https://torrentio.strem.fun',
  'kisskh': 'https://kisskh.is',
  'kickassanime': 'https://kaa.lt',
  'animestream': 'https://anime.uniquestream.net',
  'animesalt': 'https://animesalt.in',
  'animeworld': 'https://watchanimeworld.one',
  'animesub': 'https://animesub.duckdns.org',
  'castle': 'https://api.hlowb.com',
  'anikoto': 'https://anikototv.to',
  'autoembed': 'https://v3-cinemeta.strem.io',
};

const Map<String, String> _queries = {
  'zeefliz': 'dune',
  'internetarchive': 'scarlet',
  'kisskh': 'demon',
  'kickassanime': 'naruto',
  'animestream': 'one piece',
  'animesalt': 'one piece',
  'animeworld': 'arifureta',
  'anikoto': 'solo',
  'autoembed': 'dune',
};

/// Providers that cannot be reached by a title search.
const Map<String, String> _subjectOverrides = {
  'torrentio': 'tt1160419',
  'animesub': 'tt0388629',
};

void main() {
  HttpOverrides.global = null;

  test(
    'every verified provider resolves under concurrent load',
    () async {
      final stopwatch = Stopwatch()..start();
      final results = await Future.wait(
        VerifiedProviders.ids.map((id) => _resolve(id)),
      );
      stopwatch.stop();

      final report = StringBuffer();
      var failed = 0;
      for (final result in results) {
        report.writeln(
          '  ${result.id.padRight(15)} '
          '${result.streams.toString().padLeft(2)} streams  '
          '${result.millis.toString().padLeft(5)} ms  '
          '${result.detail}',
        );
        if (result.streams == 0) failed++;
      }
      // ignore: avoid_print
      print(
        '\nconcurrent resolution of ${results.length} providers '
        'in ${stopwatch.elapsedMilliseconds} ms\n$report',
      );

      expect(
        failed,
        0,
        reason: 'a provider that only works alone is not usable in the app',
      );
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

class _Result {
  _Result(this.id);

  final String id;
  int streams = 0;
  int millis = 0;
  String detail = '';
}

Future<_Result> _resolve(String id) async {
  final result = _Result(id);
  final watch = Stopwatch()..start();
  final plugin = createPlugin(
    ExalerePluginConfig(
      id: id,
      name: id,
      baseUrl: _bases[id] ?? 'https://example.com',
      addedAt: DateTime.now(),
    ),
  );

  try {
    var subjectId = _subjectOverrides[id] ?? '';
    var season = 1;
    var episode = 1;
    var title = '';

    if (id == 'castle') {
      final catalogue = await plugin.getCatalogFeed();
      if (catalogue.isEmpty) {
        result.detail = 'empty catalogue';
        return result;
      }
      subjectId = catalogue.first.id;
      title = catalogue.first.title;
    } else if (subjectId.isEmpty) {
      final query = _queries[id] ?? 'dune';
      final hits = await plugin.search(query);
      if (hits.isEmpty) {
        result.detail = 'no search hits for "$query"';
        return result;
      }
      final item = _pick(hits);
      subjectId = item.id;
      title = item.title;
    }

    final streams = await plugin.getStreams(
      subjectId: subjectId,
      title: title,
      season: season,
      episode: episode,
    );
    result.streams = streams.length;
    result.detail = streams.isEmpty ? 'no source' : streams.first.format;
  } catch (error) {
    result.detail = 'error: $error';
  }
  result.millis = watch.elapsedMilliseconds;
  return result;
}

/// Castle's ids are internal, so the first catalogue item is the subject.
MediaItem _pick(List<MediaItem> hits) => hits.first;
