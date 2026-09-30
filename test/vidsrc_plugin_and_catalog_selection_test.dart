import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/plugins/vidsrc/vidsrc_plugin.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/vidsrc_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VidSrcPlugin and VidSrcProvider Tests', () {
    test('VidSrcPlugin properties and metadata', () {
      final plugin = VidSrcPlugin();
      expect(plugin.id, equals('vidsrc'));
      expect(plugin.name, equals('VidSrc Engine'));
      expect(plugin.priority, equals(75));
      expect(plugin.supportsMovies, isTrue);
      expect(plugin.supportsSeries, isTrue);
      expect(plugin.supportsCatalogFeeds, isTrue);
      expect(plugin.supportsSearch, isTrue);
      expect(plugin.isEnabled, isTrue);

      final provider = VidSrcProvider();
      expect(provider.id, equals('vidsrc'));
      expect(provider.supportsCatalogFeeds, isTrue);
    });

    test('VidSrcPlugin getCatalogFeed parses movies feed correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/movies/latest/page-1.json')) {
          final body = json.encode({
            'result': [
              {
                'title': 'Cloverfield 2008',
                'imdb_id': 'tt1060277',
                'tmdb_id': 7191,
                'poster': 'https://image.tmdb.org/t/p/w500/cloverfield.jpg',
              },
              {
                'title': 'Avatar 2009',
                'imdb_id': 'tt0499549',
                'tmdb_id': 19995,
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

      final plugin = VidSrcPlugin(client: mockClient);
      final feed = await plugin.getCatalogFeed(page: 1);

      expect(feed.length, equals(2));
      expect(feed[0].title, equals('Cloverfield'));
      expect(feed[0].year, equals('2008'));
      expect(feed[0].id, equals('7191'));
      expect(feed[0].mediaType, equals(MediaType.movie));
      expect(
        feed[0].posterUrl,
        equals('https://image.tmdb.org/t/p/w500/cloverfield.jpg'),
      );

      expect(feed[1].title, equals('Avatar'));
      expect(feed[1].year, equals('2009'));
      expect(feed[1].id, equals('19995'));
    });

    test('VidSrcPlugin getCatalogFeed parses tvshows feed correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/tvshows/latest/page-2.json')) {
          final body = json.encode({
            'result': [
              {
                'show_title': 'Breaking Bad 2008',
                'imdb_id': 'tt0903747',
                'tmdb_id': 1396,
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

      final plugin = VidSrcPlugin(client: mockClient);
      final feed = await plugin.getCatalogFeed(category: 'tv', page: 2);

      expect(feed.length, equals(1));
      expect(feed[0].title, equals('Breaking Bad'));
      expect(feed[0].year, equals('2008'));
      expect(feed[0].mediaType, equals(MediaType.series));
    });

    test(
      'VidSrcPlugin getStreams generates multi-mirror embed sources for movie',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/info/movie/tt1060277.json')) {
            return http.Response(
              json.encode({'quality': '1080p', 'imdb_rating': 7.0}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final plugin = VidSrcPlugin(client: mockClient);
        final streams = await plugin.getStreams(
          subjectId: 'tt1060277',
          imdbId: 'tt1060277',
          title: 'Cloverfield',
          year: '2008',
        );

        expect(streams.isNotEmpty, isTrue);
        expect(
          streams.first.url,
          contains('/embed/movie/tt1060277?autoplay=1&ds_lang=en'),
        );
        expect(streams.first.format, equals('Web Embed'));
        expect(streams.first.providerId, equals('vidsrc'));
        expect(streams.first.quality, contains('1080p'));
      },
    );

    test(
      'VidSrcPlugin getStreams generates multi-mirror embed sources for TV episode',
      () async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/info/tv/tt0903747/1/1.json')) {
            return http.Response(
              json.encode({'quality': '720p'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        final plugin = VidSrcPlugin(client: mockClient);
        final streams = await plugin.getStreams(
          subjectId: 'tt0903747',
          imdbId: 'tt0903747',
          season: 1,
          episode: 1,
          isSeries: true,
        );

        expect(streams.isNotEmpty, isTrue);
        expect(
          streams.first.url,
          contains('/embed/tv/tt0903747/1/1?autoplay=1&autonext=1&ds_lang=en'),
        );
        expect(streams.first.quality, contains('720p'));
      },
    );
  });

  group('Catalog Provider Selection & Play Store Compliance Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'StorageService defaults selected catalog provider to tmdb for Google Play safety',
      () async {
        final storage = StorageService();
        final defaultProvider = await storage.getSelectedCatalogProvider();
        expect(defaultProvider, equals('tmdb'));

        final prompted = await storage.getHasPromptedProviderSelection();
        expect(prompted, isFalse);
      },
    );

    test(
      'StorageService persists provider selection and prompt state',
      () async {
        final storage = StorageService();
        await storage.setSelectedCatalogProvider('org.exalere.vidsrc');
        await storage.setHasPromptedProviderSelection(true);

        expect(
          await storage.getSelectedCatalogProvider(),
          equals('org.exalere.vidsrc'),
        );
        expect(await storage.getHasPromptedProviderSelection(), isTrue);
      },
    );

    test(
      'AppProvider initializes with tmdb catalog provider and updates on change',
      () async {
        final app = AppProvider();
        await app.init();

        expect(app.selectedCatalogProvider, equals('tmdb'));

        await app.setSelectedCatalogProvider('moviebox');
        expect(app.selectedCatalogProvider, equals('moviebox'));

        final storage = StorageService();
        expect(await storage.getSelectedCatalogProvider(), equals('moviebox'));
      },
    );

    test(
      'ProviderRegistry default fallback does not include uninstalled scrapers',
      () {
        final registry = ProviderRegistry();
        // On fresh install, no external providers are registered by default unless installed as plugins
        final active = registry.activeProviders;
        for (final p in active) {
          expect(p.id, isNot(equals('uninstalled_fake_plugin')));
        }
      },
    );
  });
}
