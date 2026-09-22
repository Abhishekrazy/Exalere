import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/providers/plugin_provider.dart';

import 'package:exalere/services/exalere_plugin_adapter.dart';
import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/tmdb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final p in List<MediaProviderPlugin>.from(
      ProviderRegistry().activeProviders,
    )) {
      ProviderRegistry().unregisterProvider(p.id);
    }
  });

  group('ExalerePluginManifest', () {
    test('parses standard plugin manifest json correctly', () {
      final json = {
        'id': 'org.community.testplugin',
        'name': 'Test Stream Plugin',
        'version': '1.2.0',
        'description': 'Provides high speed streams',
        'resources': ['stream'],
        'types': ['movie', 'series'],
        'idPrefixes': ['tt', 'tmdb'],
      };

      final manifest = ExalerePluginManifest.fromJson(json);

      expect(manifest.id, 'org.community.testplugin');
      expect(manifest.name, 'Test Stream Plugin');
      expect(manifest.version, '1.2.0');
      expect(manifest.description, 'Provides high speed streams');
      expect(manifest.supportsStreams, isTrue);
      expect(manifest.supportsMovies, isTrue);
      expect(manifest.supportsSeries, isTrue);
      expect(manifest.idPrefixes, contains('tt'));
    });

    test('handles object-based resources structure in manifest', () {
      final json = {
        'id': 'org.custom.objplugin',
        'name': 'Object Resource Plugin',
        'resources': [
          {
            'name': 'stream',
            'types': ['movie'],
          },
        ],
        'types': ['movie'],
      };

      final manifest = ExalerePluginManifest.fromJson(json);
      expect(manifest.supportsStreams, isTrue);
      expect(manifest.supportsMovies, isTrue);
      expect(manifest.supportsSeries, isFalse);
    });
  });

  group('ExalerePluginStream & toStreamSource', () {
    test(
      'converts HLS plugin stream with headers and subtitles to StreamSource',
      () {
        final json = {
          'name': 'Server 1\n4K HDR',
          'title': '4K UHD • HEVC • Multi-Sub',
          'url': 'https://cdn.example.com/stream/master.m3u8',
          'behaviorHints': {
            'proxyHeaders': {
              'request': {
                'User-Agent': 'CustomUA/1.0',
                'Referer': 'https://example.com/',
              },
            },
          },
          'subtitles': [
            {
              'lang': 'en',
              'name': 'English [CC]',
              'url': 'https://cdn.example.com/subs/en.vtt',
            },
          ],
        };

        final stream = ExalerePluginStream.fromJson(json);
        expect(stream.url, 'https://cdn.example.com/stream/master.m3u8');
        expect(stream.requestHeaders['Referer'], 'https://example.com/');
        expect(stream.subtitles.length, 1);
        expect(stream.subtitles.first.language, 'en');

        final source = stream.toStreamSource(fallbackName: 'Plugin');
        expect(source.isHls, isTrue);
        expect(source.quality, contains('4K'));
        expect(source.resolution, '3840x2160');
        expect(source.headers['User-Agent'], 'CustomUA/1.0');
        expect(
          source.subtitles.first.url,
          'https://cdn.example.com/subs/en.vtt',
        );
      },
    );

    test('detects 1080p MP4 stream correctly', () {
      final json = {
        'name': 'Mirror 2',
        'title': '1080p BluRay Remux',
        'url': 'https://cdn.example.com/video.mp4',
      };

      final stream = ExalerePluginStream.fromJson(json);
      final source = stream.toStreamSource();
      expect(source.format, 'MP4');
      expect(source.quality, contains('1080p'));
      expect(source.resolution, '1920x1080');
    });

    test('resolves infoHash to magnet URI and sets Torrent format in toStreamSource', () {
      final json = {
        'name': 'ThePirateBay+\n1080p',
        'title': 'The Matrix 1999 1080p BluRay x264',
        'infoHash': '4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
        'fileIdx': 0,
      };

      final stream = ExalerePluginStream.fromJson(json);
      expect(
        stream.url,
        startsWith(
          'magnet:?xt=urn:btih:4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
        ),
      );
      expect(stream.infoHash, '4a73752e25d2b7814b62db1dbb16b47c0b4d45be');

      final source = stream.toStreamSource(fallbackName: 'ThePirateBay+');
      expect(source.format, 'Torrent');
      expect(source.quality, contains('1080p'));
      expect(source.resolution, '1920x1080');
      expect(source.url, startsWith('magnet:'));
    });
  });

  group('ExalerePluginConfig serialization', () {
    test('roundtrips config to and from JSON', () {
      final now = DateTime.now();
      final config = ExalerePluginConfig(
        id: 'test.plugin',
        name: 'Test',
        baseUrl: 'https://test.example.com',
        isEnabled: true,
        addedAt: now,
      );

      final jsonMap = config.toJson();
      final restored = ExalerePluginConfig.fromJson(jsonMap);

      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.baseUrl, config.baseUrl);
      expect(restored.isEnabled, isTrue);
    });
  });

  group('PluginService.normalizeUrl', () {
    test('normalizes custom protocol to https://', () {
      expect(
        PluginService.normalizeUrl(
          'exalere://torrentio.strem.fun/manifest.json',
        ),
        'https://torrentio.strem.fun',
      );
    });

    test('strips trailing slashes and manifest.json suffix', () {
      expect(
        PluginService.normalizeUrl(
          'https://my-plugin.example.com/manifest.json',
        ),
        'https://my-plugin.example.com',
      );
      expect(
        PluginService.normalizeUrl('https://my-plugin.example.com///'),
        'https://my-plugin.example.com',
      );
    });

    test('adds https:// if missing protocol', () {
      expect(
        PluginService.normalizeUrl('my-plugin.example.com'),
        'https://my-plugin.example.com',
      );
    });
  });

  group('ExalerePluginAdapter getStreams', () {
    test(
      'correctly queries movie endpoint and returns StreamSource list',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path == '/stream/movie/tt0137523.json') {
            final body = json.encode({
              'streams': [
                {
                  'name': 'MockProvider\n1080p',
                  'title': '1080p WebRip',
                  'url': 'https://mock.stream/video.m3u8',
                },
              ],
            });
            return http.Response(
              body,
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final config = ExalerePluginConfig(
          id: 'mock.plugin',
          name: 'Mock Plugin',
          baseUrl: 'https://mock.plugin',
          addedAt: DateTime.now(),
        );

        final adapter = ExalerePluginAdapter(
          config: config,
          client: mockClient,
        );
        final streams = await adapter.getStreams(subjectId: 'tt0137523');

        expect(streams.length, 1);
        expect(streams.first.url, 'https://mock.stream/video.m3u8');
        expect(streams.first.isHls, isTrue);
        expect(streams.first.quality, contains('1080p'));
      },
    );

    test('correctly queries series endpoint with season and episode', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/stream/series/tt0944947:1:5.json') {
          final body = json.encode({
            'streams': [
              {
                'name': 'MockSeries\n720p',
                'title': '720p HDTV',
                'url': 'https://mock.stream/ep5.mp4',
              },
            ],
          });
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final config = ExalerePluginConfig(
        id: 'mock.plugin',
        name: 'Mock Plugin',
        baseUrl: 'https://mock.plugin',
        addedAt: DateTime.now(),
      );

      final adapter = ExalerePluginAdapter(config: config, client: mockClient);
      final streams = await adapter.getStreams(
        subjectId: 'tt0944947',
        season: 1,
        episode: 5,
      );

      expect(streams.length, 1);
      expect(streams.first.url, 'https://mock.stream/ep5.mp4');
      expect(streams.first.quality, contains('720p'));
    });

    test('prioritizes imdbId over non-imdb subjectId for Stremio addon compatibility', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/stream/movie/tt0137523.json') {
          final body = json.encode({
            'streams': [
              {
                'name': 'Torrentio\n1080p',
                'title': 'Fight Club 1080p BluRay',
                'url': 'https://mock.stream/video.m3u8',
              },
            ],
          });
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final config = ExalerePluginConfig(
        id: 'org.stremio.torrentio',
        name: 'Torrentio',
        baseUrl: 'https://torrentio.strem.fun',
        addedAt: DateTime.now(),
      );

      final adapter = ExalerePluginAdapter(config: config, client: mockClient);
      final streams = await adapter.getStreams(
        subjectId: '12345_internal_id',
        imdbId: 'tt0137523',
      );

      expect(streams.length, 1);
      expect(streams.first.url, 'https://mock.stream/video.m3u8');
    });

    test('correctly returns magnet/torrent streams from P2P plugin (e.g. ThePirateBay+)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/stream/movie/tt0133093.json') {
          final body = json.encode({
            'streams': [
              {
                'name': 'TPB+\n1080p',
                'title': 'The Matrix 1080p',
                'infoHash': '4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
              },
            ],
          });
          return http.Response(
            body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final config = ExalerePluginConfig(
        id: 'com.stremio.thepiratebay.plus',
        name: 'ThePirateBay+ (TPB+)',
        baseUrl: 'https://thepiratebay-plus.strem.fun',
        addedAt: DateTime.now(),
      );

      final adapter = ExalerePluginAdapter(config: config, client: mockClient);
      final streams = await adapter.getStreams(subjectId: 'tt0133093');

      expect(streams.length, 1);
      expect(
        streams.first.url,
        startsWith(
          'magnet:?xt=urn:btih:4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
        ),
      );
      expect(streams.first.format, 'Torrent');
      expect(streams.first.quality, contains('1080p'));
    });
  });

  group('PluginService URL normalization & Community Catalog', () {
    test('normalizes stremio:// scheme to https://', () {
      expect(
        PluginService.normalizeUrl(
          'stremio://torrentio.strem.fun/manifest.json',
        ),
        'https://torrentio.strem.fun',
      );
      expect(
        PluginService.normalizeUrl('stremio://cinemeta.strem.io/'),
        'https://cinemeta.strem.io',
      );
    });

    test('normalizes exalere:// scheme to https://', () {
      expect(
        PluginService.normalizeUrl(
          'exalere://myworker.example.workers.dev/manifest.json',
        ),
        'https://myworker.example.workers.dev',
      );
    });

    test(
      'provides curated community catalog with Stremio & worker plugins',
      () {
        final catalog = PluginService().getCommunityCatalog();
        expect(catalog.length, greaterThanOrEqualTo(3));

        final torrentio = catalog.firstWhere(
          (p) => p.name.contains('Torrentio'),
        );
        expect(torrentio.name, contains('Torrentio'));
        expect(
          torrentio.manifestUrl,
          'https://torrentio.strem.fun/manifest.json',
        );
        expect(torrentio.isFeatured, isTrue);

        final tpb = catalog.firstWhere(
          (p) => p.id == 'com.stremio.thepiratebay.plus',
        );
        expect(tpb.name, contains('ThePirateBay+'));
        expect(tpb.isFeatured, isTrue);
      },
    );

    test('CommunityPluginItem correctly serializes to and from JSON', () {
      const item = CommunityPluginItem(
        id: 'test.id',
        name: 'Test Plugin',
        description: 'Description',
        manifestUrl: 'https://example.com/manifest.json',
        author: 'Author',
        isFeatured: true,
        tags: ['Fast', 'HLS'],
      );

      final jsonMap = item.toJson();
      final reconstituted = CommunityPluginItem.fromJson(jsonMap);

      expect(reconstituted.id, item.id);
      expect(reconstituted.name, item.name);
      expect(reconstituted.description, item.description);
      expect(reconstituted.manifestUrl, item.manifestUrl);
      expect(reconstituted.author, item.author);
      expect(reconstituted.isFeatured, item.isFeatured);
      expect(reconstituted.tags, item.tags);
    });

    test(
      'includes ThePirateBay+, MediaFusion, and CyberFlix in default catalog',
      () {
        final catalog = PluginService().getCommunityCatalog();
        final tpb = catalog.firstWhere(
          (p) => p.id == 'com.stremio.thepiratebay.plus',
        );
        expect(tpb.name, contains('ThePirateBay+'));
        expect(
          tpb.manifestUrl,
          'https://thepiratebay-plus.strem.fun/manifest.json',
        );
        expect(tpb.tags, contains('Torrents'));

        final mediaFusion = catalog.firstWhere(
          (p) => p.id == 'com.elfhosted.mediafusion',
        );
        expect(
          mediaFusion.manifestUrl,
          'https://mediafusion.elfhosted.com/manifest.json',
        );

        final cyberflix = catalog.firstWhere(
          (p) => p.id == 'com.cyberflix.catalog',
        );
        expect(
          cyberflix.manifestUrl,
          'https://cyberflix.elfhosted.com/manifest.json',
        );
      },
    );

    test('fetchRemoteCommunityCatalog queries pages catalog and falls back if primary fails', () async {
      final service = PluginService();
      final sampleItems = [
        {
          'id': 'test.mock.plugin',
          'name': 'Mock Plugin',
          'description': 'A mock plugin',
          'manifestUrl': 'https://mock.plugin/manifest.json',
          'author': 'Tester',
          'isFeatured': true,
          'tags': ['Test'],
        },
      ];

      // Simulate primary failing (500), fallback succeeding (200)
      service.client = MockClient((request) async {
        if (request.url.toString() == PluginService.pagesCatalogUrl) {
          return http.Response('Server Error', 500);
        } else if (request.url.toString() == PluginService.defaultCatalogUrl) {
          return http.Response(
            json.encode(sampleItems),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final results = await service.fetchRemoteCommunityCatalog();
      expect(results.length, 1);
      expect(results.first.id, 'test.mock.plugin');
    });

    test(
      'fetchRemoteCommunityCatalog succeeds on pagesCatalogUrl directly',
      () async {
        final service = PluginService();
        final sampleItems = [
          {
            'id': 'com.pages.plugin',
            'name': 'Pages Plugin',
            'description': 'A pages plugin',
            'manifestUrl': 'https://pages.plugin/manifest.json',
            'author': 'Tester',
            'isFeatured': true,
            'tags': ['Pages'],
          },
        ];

        service.client = MockClient((request) async {
          if (request.url.toString() == PluginService.pagesCatalogUrl) {
            return http.Response(
              json.encode(sampleItems),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final results = await service.fetchRemoteCommunityCatalog();
        expect(results.length, 1);
        expect(results.first.id, 'com.pages.plugin');
      },
    );

    test(
      'PluginProvider calls onPluginsChanged on toggle, install, and uninstall',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.endsWith('/manifest.json')) {
            return http.Response(
              json.encode({
                'id': 'test.mock.plugin',
                'name': 'Test Mock Plugin',
                'version': '1.0.0',
                'resources': ['stream'],
                'types': ['movie'],
              }),
              200,
            );
          }
          return http.Response('Not Found', 404);
        });

        final service = PluginService()..client = mockClient;
        final provider = PluginProvider(service: service);
        int changeCount = 0;
        provider.onPluginsChanged = () {
          changeCount++;
        };

        // Install remote plugin
        final installed = await provider.installPlugin(
          'https://test.plugin/manifest.json',
        );
        expect(installed, isTrue);
        expect(changeCount, 1);

        // Toggle plugin
        await provider.togglePlugin('test.mock.plugin', false);
        expect(changeCount, 2);

        // Uninstall plugin
        await provider.uninstallPlugin('test.mock.plugin');
        expect(changeCount, 3);
      },
    );

    group('createPlugin Factory', () {
      test('instantiates native MovieBoxPlugin for MovieBox config', () {
        final config = ExalerePluginConfig(
          id: 'org.exalere.moviebox',
          name: 'MovieBox Engine',
          baseUrl: 'https://abhishekrazy.github.io/Exalere/plugins/moviebox',
          addedAt: DateTime.now(),
        );
        final plugin = createPlugin(config);
        expect(plugin, isA<MovieBoxPlugin>());
        expect(plugin.id, 'org.exalere.moviebox');
        expect(plugin.name, 'MovieBox Engine');
      });

      test('instantiates native FourKHdHubPlugin for 4K HD Hub config', () {
        final config = ExalerePluginConfig(
          id: 'org.exalere.fourkhd',
          name: '4K HD Hub Engine',
          baseUrl: 'https://abhishekrazy.github.io/Exalere/plugins/fourkhd',
          addedAt: DateTime.now(),
        );
        final plugin = createPlugin(config);
        expect(plugin, isA<FourKHdHubPlugin>());
        expect(plugin.id, 'org.exalere.fourkhd');
      });

      test('instantiates native DramachiPlugin for Dramachi config', () {
        final config = ExalerePluginConfig(
          id: 'org.exalere.dramachi',
          name: 'Dramachi Engine',
          baseUrl: 'https://abhishekrazy.github.io/Exalere/plugins/dramachi',
          addedAt: DateTime.now(),
        );
        final plugin = createPlugin(config);
        expect(plugin, isA<DramachiPlugin>());
        expect(plugin.id, 'org.exalere.dramachi');
      });

      test('falls back to StremioAddonPlugin for third-party addons', () {
        final config = ExalerePluginConfig(
          id: 'com.stremio.torrentio.addon',
          name: 'Torrentio',
          baseUrl: 'https://torrentio.strem.fun',
          addedAt: DateTime.now(),
        );
        final plugin = createPlugin(config);
        expect(plugin, isA<StremioAddonPlugin>());
        expect(plugin.id, 'com.stremio.torrentio.addon');
      });
    });

    test(
      'TmdbEnrichedDetails builds complete fallback seasons and toMediaDetails',
      () {
        const details = TmdbEnrichedDetails(
          id: 1399,
          title: 'Game of Thrones',
          overview: 'Seven noble families fight for control of the mythical land of Westeros.',
          rating: 8.4,
          genres: ['Sci-Fi & Fantasy', 'Drama', 'Action & Adventure'],
          seasons: [
            TmdbSeasonSummary(
              seasonNumber: 0,
              episodeCount: 5,
              name: 'Specials',
            ),
            TmdbSeasonSummary(
              seasonNumber: 1,
              episodeCount: 10,
              name: 'Season 1',
            ),
            TmdbSeasonSummary(
              seasonNumber: 2,
              episodeCount: 10,
              name: 'Season 2',
            ),
          ],
        );

        final seasons = details.buildFallbackSeasons();
        expect(seasons.length, 2); // Excludes season 0 specials
        expect(seasons[0].seasonNumber, 1);
        expect(seasons[0].episodeCount, 10);
        expect(seasons[0].episodes.length, 10);
        expect(seasons[0].episodes[0].title, 'Episode 1');
        expect(seasons[0].episodes[9].title, 'Episode 10');

        const item = MediaItem(
          id: '1399',
          title: 'Game of Thrones',
          mediaType: MediaType.series,
          year: '2011',
        );

        final mediaDetails = details.toMediaDetails(item);
        expect(mediaDetails.id, '1399');
        expect(mediaDetails.title, 'Game of Thrones');
        expect(mediaDetails.isSeries, isTrue);
        expect(mediaDetails.seasons.length, 2);
        expect(mediaDetails.seasons.first.episodes.length, 10);
      },
    );

    test('ProviderRegistry.resolveStreams forwards title and year to active providers', () async {
      final registry = ProviderRegistry();
      String? capturedTitle;
      String? capturedYear;

      final testPlugin = _MockTitleCheckPlugin(
        onGetStreams: (title, year) {
          capturedTitle = title;
          capturedYear = year;
        },
      );

      registry.registerProvider(testPlugin);
      try {
        await registry.resolveStreams(
          subjectId: '1399',
          title: 'Game of Thrones',
          year: '2011',
          season: 1,
          episode: 1,
        );

        expect(capturedTitle, 'Game of Thrones');
        expect(capturedYear, '2011');
      } finally {
        registry.unregisterProvider(testPlugin.id);
      }
    });

    test('ProviderRegistry.resolveStreams aggregates streams across multiple active providers for TV series', () async {
      final registry = ProviderRegistry();

      final p1 = _MockStreamPlugin(
        id: 'mock_4khd',
        name: '4K HD Hub Engine',
        stream: const StreamSource(
          quality: '4K',
          resolution: '3840x2160',
          format: 'MKV',
          url: 'https://cdn.example.com/stream4k.mkv',
          server: '4K HD Hub',
        ),
      );

      final p2 = _MockStreamPlugin(
        id: 'mock_vidsrc',
        name: 'VidSrc Engine',
        stream: const StreamSource(
          quality: '1080p',
          resolution: '1920x1080',
          format: 'HLS',
          url: 'https://cdn.example.com/stream1080.m3u8',
          server: 'VidSrc',
        ),
      );

      registry.registerProvider(p1);
      registry.registerProvider(p2);

      try {
        final streams = await registry.resolveStreams(
          subjectId: 'neagley',
          title: 'Neagley',
          year: '2026',
          season: 1,
          episode: 1,
        );

        expect(streams.length, equals(2));
        expect(streams.any((s) => s.quality == '4K'), isTrue);
        expect(streams.any((s) => s.quality == '1080p'), isTrue);
      } finally {
        registry.unregisterProvider(p1.id);
        registry.unregisterProvider(p2.id);
      }
    });

    test('ProviderRegistry.getDetails and search delegate dynamically to active providers', () async {
      final registry = ProviderRegistry();

      final p = _MockStreamPlugin(
        id: 'mock_catalog',
        name: 'Mock Catalog',
        stream: const StreamSource(
          quality: 'HD',
          resolution: '1080p',
          format: 'MP4',
          url: 'https://cdn.example.com/video.mp4',
        ),
      );

      registry.registerProvider(p);

      try {
        final results = await registry.search('Test Query');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Mock Item'));

        final details = await registry.getDetails(
          'mock_item_1',
          providerId: 'mock_catalog',
        );
        expect(details, isNotNull);
        expect(details!.title, equals('Mock Details'));
      } finally {
        registry.unregisterProvider(p.id);
      }
    });

    test('createPlugin instantiates StremioAddonPlugin for any remote plugin config', () {
      final extConfig = ExalerePluginConfig(
        id: 'external_addon',
        name: 'External Addon',
        baseUrl: 'https://example.com/addon',
        addedAt: DateTime.now(),
      );
      final extPlugin = createPlugin(extConfig);
      expect(extPlugin, isA<StremioAddonPlugin>());
      expect(extPlugin.id, equals('external_addon'));
      expect(extPlugin.name, equals('External Addon'));
    });

    test('PluginService.loadInstalledPlugins returns empty list when storage is empty (no auto-seeding)', () async {
      final service = PluginService();
      final plugins = await service.loadInstalledPlugins();
      // Fresh install must return [] — user must explicitly install plugins.
      expect(plugins, isEmpty);
    });

    test('PluginService sets, gets and clears defaultProviderId', () async {
      final service = PluginService();
      await service.setDefaultProviderId('fourkhdhub');
      expect(await service.getDefaultProviderId(), 'fourkhdhub');
      expect(ProviderRegistry().defaultProviderId, 'fourkhdhub');

      await service.setDefaultProviderId(null);
      expect(await service.getDefaultProviderId(), isNull);
      expect(ProviderRegistry().defaultProviderId, isNull);
    });

    test('ProviderRegistry.resolveStreams prioritizes defaultProviderId streams first while keeping all active providers available', () async {
      final registry = ProviderRegistry();
      registry.clearAll();

      final streamA = StreamSource(
        quality: '1080p',
        resolution: '1920x1080',
        format: 'MP4',
        url: 'https://example.com/a.mp4',
        server: 'Server A',
        providerId: 'provider_a',
        providerName: 'Provider A',
      );
      final streamB = StreamSource(
        quality: '720p',
        resolution: '1280x720',
        format: 'MP4',
        url: 'https://example.com/b.mp4',
        server: 'Server B',
        providerId: 'provider_b',
        providerName: 'Provider B',
      );

      registry.registerProvider(
        _ConfigurableStreamPlugin(
          id: 'provider_a',
          name: 'Provider A',
          streams: [streamA],
        ),
      );
      registry.registerProvider(
        _ConfigurableStreamPlugin(
          id: 'provider_b',
          name: 'Provider B',
          streams: [streamB],
        ),
      );

      registry.defaultProviderId = 'provider_b';

      final resolved = await registry.resolveStreams(
        subjectId: '123',
        season: 1,
        episode: 1,
      );
      // Both providers must be present for player server selection
      expect(resolved.length, 2);
      // But provider_b (the default) is prioritized at the top
      expect(resolved.first.providerId, 'provider_b');
      expect(resolved.first.url, 'https://example.com/b.mp4');
      // provider_a is still available
      expect(resolved.last.providerId, 'provider_a');
      expect(resolved.last.url, 'https://example.com/a.mp4');

      registry.clearAll();
      registry.defaultProviderId = null;
    });

    test('ProviderRegistry.resolveStreams still returns other active providers if defaultProviderId returns empty', () async {
      final registry = ProviderRegistry();
      registry.clearAll();

      final streamB = StreamSource(
        quality: '720p',
        resolution: '1280x720',
        format: 'MP4',
        url: 'https://example.com/b.mp4',
        server: 'Server B',
        providerId: 'provider_b',
        providerName: 'Provider B',
      );

      registry.registerProvider(
        _ConfigurableStreamPlugin(
          id: 'provider_a',
          name: 'Provider A',
          streams: [],
        ),
      );
      registry.registerProvider(
        _ConfigurableStreamPlugin(
          id: 'provider_b',
          name: 'Provider B',
          streams: [streamB],
        ),
      );

      registry.defaultProviderId = 'provider_a';

      final resolved = await registry.resolveStreams(
        subjectId: '123',
        season: 1,
        episode: 1,
      );
      expect(resolved.length, 1);
      expect(resolved.first.providerId, 'provider_b');

      registry.clearAll();
      registry.defaultProviderId = null;
    });

    test('PluginService.uninstallPlugin clears defaultProviderId if uninstalled plugin was default', () async {
      final service = PluginService();
      await service.setDefaultProviderId('test_default');
      expect(await service.getDefaultProviderId(), 'test_default');

      await service.uninstallPlugin('test_default');
      expect(await service.getDefaultProviderId(), isNull);
      expect(ProviderRegistry().defaultProviderId, isNull);
    });
  });
}

class _ConfigurableStreamPlugin extends MediaProviderPlugin {
  @override
  final String id;
  @override
  final String name;
  final List<StreamSource> streams;

  _ConfigurableStreamPlugin({
    required this.id,
    required this.name,
    required this.streams,
  });

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsMovies => true;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async => streams;
}

class _MockStreamPlugin extends MediaProviderPlugin {
  @override
  final String id;
  @override
  final String name;
  final StreamSource stream;

  _MockStreamPlugin({
    required this.id,
    required this.name,
    required this.stream,
  });

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<List<MediaItem>> search(String query) async => [
    MediaItem(
      id: 'mock_item_1',
      title: 'Mock Item',
      mediaType: MediaType.series,
      providerId: id,
    ),
  ];

  @override
  Future<MediaDetails?> getDetails(String id) async => MediaDetails(
    id: id,
    title: 'Mock Details',
    mediaType: MediaType.series,
    description: 'Mock Description',
  );

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async => [stream];
}

class _MockTitleCheckPlugin extends MediaProviderPlugin {
  final void Function(String? title, String? year) onGetStreams;
  _MockTitleCheckPlugin({required this.onGetStreams});

  @override
  String get id => 'mock_title_check';

  @override
  String get name => 'Mock Title Check';

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsMovies => true;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async {
    onGetStreams(title, year);
    return [];
  }
}
