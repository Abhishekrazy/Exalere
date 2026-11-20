import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/verified_providers.dart';

/// Command-line twin of the in-app provider self-test (Settings → Add-ons →
/// Test, flask icon). Runs the same four stages — Catalog, Search, Metadata,
/// Streams — for one provider or all verified ones, and fails when a provider
/// resolves no stream.
///
/// Run it with:
///   flutter test test/provider_selftest_test.dart --dart-define=PROVIDERS=kisskh
///   flutter test test/provider_selftest_test.dart --dart-define=PROVIDERS=all
///   flutter test test/provider_selftest_test.dart --dart-define=PROVIDERS=animesalt --dart-define=QUERY=one piece
///
/// It lives under test/ because the app depends on Flutter (shared_preferences),
/// so a plain `dart run` cannot load it; `flutter test` gives the same CLI
/// ergonomics without a device.
const String _providersArg = String.fromEnvironment(
  'PROVIDERS',
  defaultValue: '',
);
const String _queryArg = String.fromEnvironment('QUERY');
const int _episodeArg = int.fromEnvironment('EPISODE', defaultValue: 1);

/// Fallbacks the registry uses before ProviderBaseUrlService has a mirror.
const Map<String, String> _fallbackBases = {
  'zeefliz': 'https://zeefliz.zze.workers.dev',
  'multimovies': 'https://m1.multimovies.courses',
  'internetarchive': 'https://archive.org',
  'torrentio': 'https://torrentio.strem.fun',
  'kisskh': 'https://kisskh.is',
  'kickassanime': 'https://kaa.lt',
  'animestream': 'https://anime.uniquestream.net',
  'animesalt': 'https://animesalt.in',
  'animesub': 'https://animesub.duckdns.org',
  'castle': 'https://api.hlowb.com',
  'anikoto': 'https://anikototv.to',
  'autoembed': 'https://v3-cinemeta.strem.io',
  'vegamovies': 'https://vegamovies.latino',
  'fourkhdhub': 'https://4khdhub.one',
  'extraflix': 'https://e14.extraflix.mobi',
  'gokuhd': 'https://gokuhd.nl',
  'animeworld': 'https://watchanimeworld.one',
};

/// Providers that cannot be exercised by a title search.
/// Torrentio resolves IMDb ids only, so the harness feeds it a known one.
const Map<String, String> _subjectOverrides = {
  'torrentio': 'tt1160419',
  // AnimeSub+ needs an IMDb id (its manifest has no catalogs/search).
  'animesub': 'tt0388629',
  // Castle needs a movieId from its own catalogue, not an IMDb id.
  // (handled by _catalogSubject below)
};

const Map<String, String> _queries = {
  'fourkhdhub': 'avengers',
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

class SelfTestReport {
  SelfTestReport(this.id);

  final String id;
  final List<String> lines = [];
  bool catalog = false;
  bool search = false;
  bool metadata = false;
  bool streams = false;

  bool get plays => streams;

  @override
  String toString() {
    final badge = VerifiedProviders.isVerified(id) ? ' (verified)' : '';
    final verdict = plays ? 'PLAYS' : 'NO STREAM';
    // A verified add-on that only resolves from home is worth saying so: on a
    // cloud runner the failure is the IP talking, not the site dying.
    final ipNote = !plays && VerifiedProviders.ipSensitive.contains(id)
        ? '  note    : IP-sensitive - re-check from a residential connection\n'
        : '';
    return '\n$id$badge\n${lines.map((l) => '  $l').join('\n')}'
        '\n  verdict : $verdict\n$ipNote';
  }
}

String _short(String url) {
  final cleaned = url.replaceAll(RegExp(r'\?.*$'), '');
  return cleaned.length <= 68 ? cleaned : '${cleaned.substring(0, 68)}…';
}

Future<SelfTestReport> runSelfTest(String id) async {
  final report = SelfTestReport(id);
  final plugin = createPlugin(
    ExalerePluginConfig(
      id: id,
      name: id,
      baseUrl: _fallbackBases[id] ?? 'https://example.com',
      addedAt: DateTime.now(),
    ),
  );

  try {
    final rows = plugin.catalogs;
    final items = rows.isEmpty
        ? <MediaItem>[]
        : await plugin.getCatalogFeed(category: rows.first.id);
    report.catalog = items.isNotEmpty;
    report.lines.add(
      'catalog : ${items.length} items'
      '${rows.isEmpty ? ' (no rows declared)' : ' from "${rows.first.title}"'}',
    );
  } catch (error) {
    report.lines.add('catalog : FAILED $error');
  }

  // Castle's ids are internal, so resolve the first catalogue item instead of
  // searching by title.
  if (id == 'castle' || id == 'gokuhd' || id == 'extraflix') {
    try {
      final catalogue = await plugin.getCatalogFeed();
      if (catalogue.isNotEmpty) {
        final subject = catalogue.first;
        final sources = await plugin.getStreams(
          subjectId: subject.id,
          season: 1,
          episode: 1,
        );
        report.streams = sources.isNotEmpty;
        report.lines.add(
          sources.isEmpty
              ? 'streams : FAILED no source for "${subject.title}"'
              : 'streams : ${sources.length} source(s), first '
                    '${sources.first.format} ${_short(sources.first.url)}',
        );
        return report;
      }
      report.lines.add('streams : FAILED empty catalogue');
    } catch (error) {
      report.lines.add('streams : FAILED $error');
    }
    return report;
  }

  final override = _subjectOverrides[id];
  if (override != null) {
    try {
      final sources = await plugin.getStreams(
        subjectId: override,
        season: 1,
        episode: _episodeArg,
      );
      report.streams = sources.isNotEmpty;
      report.lines.add(
        sources.isEmpty
            ? 'streams : FAILED no source for $override'
            : 'streams : ${sources.length} source(s), first '
                  '${sources.first.format} ${_short(sources.first.url)}',
      );
    } catch (error) {
      report.lines.add('streams : FAILED $error');
    }
    return report;
  }

  final query = _queryArg.isNotEmpty ? _queryArg : (_queries[id] ?? 'dune');
  var hits = <MediaItem>[];
  try {
    hits = await plugin.search(query);
    report.search = hits.isNotEmpty;
    report.lines.add('search  : ${hits.length} hits for "$query"');
  } catch (error) {
    report.lines.add('search  : FAILED $error');
  }

  if (hits.isEmpty) {
    report.lines.add('streams : FAILED (no search hit to resolve)');
    return report;
  }

  final subject = hits.first;
  try {
    final details = await plugin.getDetails(subject.id);
    report.metadata = details != null;
    report.lines.add(
      'metadata: ${details == null ? 'none' : '${details.title}, '
                '${details.seasons.length} season(s)'}',
    );
  } catch (error) {
    report.lines.add('metadata: FAILED $error');
  }

  // The first hit is not always a post with live mirrors; a search index also
  // returns announcements ("… Encore") that never carried a stream. Try a few,
  // as the in-app health check does, so one dead post does not condemn the
  // add-on.
  try {
    final candidates = hits.take(3).toList();
    for (final candidate in candidates) {
      final sources = await plugin.getStreams(
        subjectId: candidate.id,
        title: candidate.title,
        season: 1,
        episode: _episodeArg,
      );
      if (sources.isEmpty) continue;

      // A URL coming back is not the same claim as a stream playing. MovieBox
      // answered every subject with one 23-second advert for fifteen rounds, and
      // a single successful resolve could not tell the difference. A second,
      // differently titled subject that returns the identical URL is a
      // placeholder, not a release.
      final other = hits.firstWhere(
        (hit) => hit.title != candidate.title,
        orElse: () => candidate,
      );
      if (other.title != candidate.title) {
        final otherSources = await plugin.getStreams(
          subjectId: other.id,
          title: other.title,
          season: 1,
          episode: _episodeArg,
        );
        if (otherSources.isNotEmpty &&
            otherSources.first.url == sources.first.url) {
          report.streams = false;
          report.lines.add(
            'streams : FAILED placeholder — "${candidate.title}" and '
            '"${other.title}" return the same file '
            '${_short(sources.first.url)}',
          );
          return report;
        }
      }

      report.streams = true;
      report.lines.add(
        'streams : ${sources.length} source(s) from "${candidate.title}", '
        'first ${sources.first.format} ${_short(sources.first.url)}',
      );
      return report;
    }
    report.lines.add(
      'streams : FAILED no playable source for '
      '${candidates.map((h) => '"${h.title}"').join(', ')}',
    );
  } catch (error) {
    report.lines.add('streams : FAILED $error');
  }
  return report;
}

void main() {
  // The app runs with platform bindings; without them a provider that reads
  // SharedPreferences (MovieBox's upstream config) throws 'Binding has not yet
  // been initialized' and looks dead.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  // flutter_test blocks sockets by default; the probe needs the real network.
  HttpOverrides.global = null;
  final ids = _providersArg.isEmpty
      ? <String>[]
      : (_providersArg == 'all'
            ? VerifiedProviders.ids.toList()
            : _providersArg.split(',').map((id) => id.trim()).toList());

  group('provider self-test (needs --dart-define=PROVIDERS)', () {
    if (ids.isEmpty) {
      test('skipped: pass --dart-define=PROVIDERS=<id|all>', () {
        expect(ids, isEmpty);
      }, skip: 'no PROVIDERS given');
      return;
    }

    for (final id in ids) {
      test('$id resolves a stream', () async {
        final report = await runSelfTest(id);
        // ignore: avoid_print
        print(report);
        expect(
          report.streams,
          isTrue,
          reason: '$id must resolve a playable stream to stay listed',
        );
      }, timeout: const Timeout(Duration(minutes: 4)));
    }
  });
}
