import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/exalere_plugin_adapter.dart';

const String _baseUrl = 'https://addon.example';

ExalerePluginManifest _manifest({
  List<String> resources = const ['stream', 'catalog', 'meta'],
  List<String> types = const ['movie', 'series'],
  List<String> idPrefixes = const ['tt'],
  List<Map<String, String>> catalogs = const [
    {'type': 'movie', 'id': 'top', 'name': 'Top Movies'},
    {'type': 'series', 'id': 'top', 'name': 'Top Series'},
  ],
}) => ExalerePluginManifest.fromJson({
  'id': 'test.addon',
  'name': 'Test Addon',
  'version': '1.0.0',
  'resources': resources,
  'types': types,
  'idPrefixes': idPrefixes,
  'catalogs': catalogs,
});

ExalerePluginConfig _config([ExalerePluginManifest? manifest]) =>
    ExalerePluginConfig(
      id: 'test.addon',
      name: 'Test Addon',
      baseUrl: _baseUrl,
      addedAt: DateTime(2024),
      manifest: manifest ?? _manifest(),
    );

void main() {
  group('ExalerePluginManifest catalogs', () {
    test('parses declared catalogs instead of dropping them', () {
      final manifest = _manifest();
      expect(manifest.hasCatalogs, isTrue);
      expect(manifest.catalogs, hasLength(2));
      expect(manifest.catalogs.first.type, 'movie');
      expect(manifest.catalogs.first.id, 'top');
      expect(manifest.catalogs.first.name, 'Top Movies');
      expect(manifest.catalogs[1].isSeriesType, isTrue);
      expect(manifest.supportsCatalogResource, isTrue);
      expect(manifest.supportsStreams, isTrue);
    });

    test('round-trips catalogs through toJson', () {
      final restored = ExalerePluginManifest.fromJson(_manifest().toJson());
      expect(restored.catalogs, hasLength(2));
      expect(restored.catalogs[1].id, 'top');
      expect(restored.catalogs[1].isSeriesType, isTrue);
    });

    test('reports stream-less catalog addons as metadata only', () {
      final manifest = _manifest(resources: const ['catalog', 'meta']);
      expect(manifest.supportsStreams, isFalse);
      expect(manifest.hasCatalogs, isTrue);
    });

    test('handles manifests that declare no catalogs', () {
      final manifest = ExalerePluginManifest.fromJson({
        'id': 'stream.only',
        'name': 'Stream Only',
        'resources': ['stream'],
        'types': ['movie'],
      });
      expect(manifest.hasCatalogs, isFalse);
      expect(manifest.supportsStreams, isTrue);
    });
  });

  group('ExalerePluginAdapter capabilities', () {
    test('advertises search and catalogs only when catalogs exist', () {
      final withCatalogs = ExalerePluginAdapter(config: _config());
      expect(withCatalogs.supportsCatalogFeeds, isTrue);
      expect(withCatalogs.supportsSearch, isTrue);
      expect(withCatalogs.supportsStreams, isTrue);
      expect(withCatalogs.supportsSubtitles, isFalse);

      final streamOnly = ExalerePluginAdapter(
        config: _config(
          _manifest(resources: const ['stream'], catalogs: const []),
        ),
      );
      expect(streamOnly.supportsCatalogFeeds, isFalse);
      expect(streamOnly.supportsSearch, isFalse);
      expect(streamOnly.supportsStreams, isTrue);
    });

    test('a metadata-only addon is never a stream source', () {
      final adapter = ExalerePluginAdapter(
        config: _config(_manifest(resources: const ['catalog', 'meta'])),
      );
      expect(adapter.supportsStreams, isFalse);
      expect(adapter.supportsCatalogFeeds, isTrue);
    });

    test('reports subtitle capability from the manifest resources', () {
      final adapter = ExalerePluginAdapter(
        config: _config(_manifest(resources: const ['stream', 'subtitles'])),
      );
      expect(adapter.supportsSubtitles, isTrue);
    });
  });

  group('ExalerePluginAdapter catalog requests', () {
    test('maps the movies category to the movie catalog', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            json.encode({
              'metas': [
                {
                  'id': 'tt1160419',
                  'type': 'movie',
                  'name': 'Dune',
                  'releaseInfo': '2021',
                  'poster': 'https://img.example/dune.jpg',
                  'genres': ['Sci-Fi', 'Adventure'],
                  'imdbRating': '8.0',
                },
              ],
            }),
            200,
          );
        }),
      );

      final items = await adapter.getCatalogFeed(category: 'movies', page: 1);

      expect(requested!.path, '/catalog/movie/top.json');
      expect(items, hasLength(1));
      expect(items.first.title, 'Dune');
      expect(items.first.year, '2021');
      expect(items.first.rating, 8.0);
      expect(items.first.genre, 'Sci-Fi • Adventure');
      expect(items.first.isSeries, isFalse);
      // Tagged with the addon id so the availability gate trusts it.
      expect(items.first.providerId, 'test.addon');
    });

    test('maps the series category to the series catalog', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(json.encode({'metas': []}), 200);
        }),
      );

      await adapter.getCatalogFeed(category: 'series', page: 1);
      expect(requested!.path, '/catalog/series/top.json');
    });

    test('paginates with a skip parameter', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(json.encode({'metas': []}), 200);
        }),
      );

      await adapter.getCatalogFeed(category: 'movies', page: 3);
      expect(requested!.queryParameters['skip'], '200');
    });

    test('search queries the catalog search endpoint', () async {
      final requested = <Uri>[];
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested.add(request.url);
          return http.Response(
            json.encode({
              'metas': [
                {'id': 'tt1160419', 'type': 'movie', 'name': 'Dune'},
              ],
            }),
            200,
          );
        }),
      );

      final results = await adapter.search('Dune');

      expect(requested, isNotEmpty);
      expect(requested.first.path, '/catalog/movie/top/search=Dune.json');
      expect(results.map((r) => r.id), contains('tt1160419'));
    });

    test(
      'a failing catalog response yields an empty list, not a throw',
      () async {
        final adapter = ExalerePluginAdapter(
          config: _config(),
          client: MockClient((_) async => http.Response('nope', 404)),
        );

        expect(await adapter.getCatalogFeed(category: 'movies'), isEmpty);
        expect(await adapter.search('Dune'), isEmpty);
        expect(await adapter.getCatalogFeed(category: 'movies'), isEmpty);
      },
    );
  });

  group('ExalerePluginAdapter metadata requests', () {
    test('builds seasons and episodes from the videos list', () async {
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          if (request.url.path == '/meta/movie/tt1.json') {
            return http.Response(json.encode({'meta': null}), 200);
          }
          return http.Response(
            json.encode({
              'meta': {
                'id': 'tt1',
                'type': 'series',
                'name': 'Test Show',
                'description': 'A show',
                'videos': [
                  {'season': 1, 'episode': 2, 'name': 'Second'},
                  {'season': 1, 'episode': 1, 'name': 'First'},
                  {'season': 2, 'episode': 1, 'name': 'Return'},
                ],
              },
            }),
            200,
          );
        }),
      );

      final details = await adapter.getDetails('tt1');

      expect(details, isNotNull);
      expect(details!.title, 'Test Show');
      expect(details.isSeries, isTrue);
      expect(details.seasons.map((s) => s.seasonNumber), [1, 2]);
      expect(
        details.seasons.first.episodes.map((e) => e.episode),
        [1, 2],
        reason: 'episodes must be ordered',
      );
      expect(details.seasons.first.episodeCount, 2);
    });

    test('returns null when neither type has metadata', () async {
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(await adapter.getDetails('tt404'), isNull);
    });
  });

  group('ExalerePluginAdapter streams', () {
    test('uses an IMDb id directly and tags the provider', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            json.encode({
              'streams': [
                {
                  'name': 'Addon',
                  'title': '1080p',
                  'url': 'https://cdn.example/movie.mp4',
                },
              ],
            }),
            200,
          );
        }),
      );

      final streams = await adapter.getStreams(
        subjectId: 'tt1160419',
        imdbId: 'tt1160419',
        title: 'Dune',
        isSeries: false,
      );

      expect(requested!.path, '/stream/movie/tt1160419.json');
      expect(streams, hasLength(1));
      expect(streams.first.url, 'https://cdn.example/movie.mp4');
      expect(streams.first.providerId, 'test.addon');
      expect(streams.first.providerName, 'Test Addon');
    });

    test('appends season and episode for series requests', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(json.encode({'streams': []}), 200);
        }),
      );

      await adapter.getStreams(
        subjectId: 'tt1',
        imdbId: 'tt1',
        title: 'Test Show',
        season: 2,
        episode: 5,
        isSeries: true,
      );

      expect(requested!.path, '/stream/series/tt1:2:5.json');
    });

    test('makes no request when the id cannot be addressed', () async {
      var calls = 0;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((_) async {
          calls++;
          return http.Response(json.encode({'streams': []}), 200);
        }),
      );

      // idPrefixes is ['tt'], the subject id is a bare TMDB number, and there is
      // no title to resolve an IMDb id from, so the addon cannot be queried.
      final streams = await adapter.getStreams(
        subjectId: '438631',
        isSeries: false,
      );

      expect(streams, isEmpty);
      expect(calls, 0, reason: 'no pointless request should be made');
    });

    test('accepts any id when the manifest declares no idPrefixes', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(_manifest(idPrefixes: const [])),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(json.encode({'streams': []}), 200);
        }),
      );

      await adapter.getStreams(subjectId: 'tt99', isSeries: false);

      expect(requested!.path, '/stream/movie/tt99.json');
    });
  });

  group('ExalerePluginAdapter subtitles', () {
    test('parses subtitle entries for the requested episode', () async {
      Uri? requested;
      final adapter = ExalerePluginAdapter(
        config: _config(_manifest(resources: const ['stream', 'subtitles'])),
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(
            json.encode({
              'subtitles': [
                {'id': '1', 'url': 'https://subs.example/en.srt', 'lang': 'en'},
                {'id': '2', 'url': 'https://subs.example/hi.srt', 'lang': 'hi'},
              ],
            }),
            200,
          );
        }),
      );

      final subs = await adapter.getSubtitles(
        subjectId: 'tt1',
        imdbId: 'tt1',
        title: 'Test Show',
        season: 1,
        episode: 4,
      );

      expect(requested!.path, '/subtitles/series/tt1:1:4.json');
      expect(subs.map((s) => s.language), ['en', 'hi']);
      expect(subs.first.url, 'https://subs.example/en.srt');
    });

    test('does nothing when the addon has no subtitle resource', () async {
      var calls = 0;
      final adapter = ExalerePluginAdapter(
        config: _config(),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );

      expect(adapter.supportsSubtitles, isFalse);
      expect(await adapter.getSubtitles(subjectId: 'tt1'), isEmpty);
      expect(calls, 0);
    });
  });

  group('ExalerePluginStream mapping', () {
    test('synthesizes a magnet link from an infoHash', () {
      final stream = ExalerePluginStream.fromJson({
        'name': 'Torrentio',
        'title': 'Dune 2160p',
        'infoHash': 'ABCDEF1234567890',
      });

      final source = stream.toStreamSource(
        fallbackName: 'Torrentio',
        providerId: 'com.stremio.torrentio.addon',
      );

      expect(source.url, startsWith('magnet:?xt=urn:btih:ABCDEF1234567890'));
      expect(source.format, 'Torrent');
      expect(source.providerId, 'com.stremio.torrentio.addon');
      expect(source.providerName, 'Torrentio');
    });

    test('carries proxy headers declared by the addon', () {
      final stream = ExalerePluginStream.fromJson({
        'url': 'https://cdn.example/video.m3u8',
        'behaviorHints': {
          'proxyHeaders': {
            'request': {'Referer': 'https://site.example'},
          },
        },
      });

      final source = stream.toStreamSource(fallbackName: 'X');
      expect(source.format, 'HLS');
      expect(source.headers['Referer'], 'https://site.example');
    });
  });

  group('MediaItem tagging', () {
    test('normalizes a protocol-relative poster URL from an addon', () {
      expect(
        MediaItem.normalizeImageUrl('//img.example/a.jpg'),
        'https://img.example/a.jpg',
      );
    });
  });
}
