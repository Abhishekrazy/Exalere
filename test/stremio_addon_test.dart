import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/models/stremio_addon.dart';
import 'package:exalere/services/addon_service.dart';
import 'package:exalere/services/stremio_addon_plugin.dart';

void main() {
  group('StremioManifest', () {
    test('parses standard Stremio manifest json correctly', () {
      final json = {
        'id': 'org.community.testaddon',
        'name': 'Test Stream Addon',
        'version': '1.2.0',
        'description': 'Provides high speed streams',
        'resources': ['stream'],
        'types': ['movie', 'series'],
        'idPrefixes': ['tt', 'tmdb'],
      };

      final manifest = StremioManifest.fromJson(json);

      expect(manifest.id, 'org.community.testaddon');
      expect(manifest.name, 'Test Stream Addon');
      expect(manifest.version, '1.2.0');
      expect(manifest.description, 'Provides high speed streams');
      expect(manifest.supportsStreams, isTrue);
      expect(manifest.supportsMovies, isTrue);
      expect(manifest.supportsSeries, isTrue);
      expect(manifest.idPrefixes, contains('tt'));
    });

    test('handles object-based resources structure in manifest', () {
      final json = {
        'id': 'org.custom.objaddon',
        'name': 'Object Resource Addon',
        'resources': [
          {
            'name': 'stream',
            'types': ['movie'],
          },
        ],
        'types': ['movie'],
      };

      final manifest = StremioManifest.fromJson(json);
      expect(manifest.supportsStreams, isTrue);
      expect(manifest.supportsMovies, isTrue);
      expect(manifest.supportsSeries, isFalse);
    });
  });

  group('StremioStream & toStreamSource', () {
    test(
      'converts HLS Stremio stream with headers and subtitles to StreamSource',
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

        final stream = StremioStream.fromJson(json);
        expect(stream.url, 'https://cdn.example.com/stream/master.m3u8');
        expect(stream.requestHeaders['Referer'], 'https://example.com/');
        expect(stream.subtitles.length, 1);
        expect(stream.subtitles.first.language, 'en');

        final source = stream.toStreamSource(fallbackName: 'Addon');
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

      final stream = StremioStream.fromJson(json);
      final source = stream.toStreamSource();
      expect(source.format, 'MP4');
      expect(source.quality, contains('1080p'));
      expect(source.resolution, '1920x1080');
    });
  });

  group('StremioAddonConfig serialization', () {
    test('roundtrips config to and from JSON', () {
      final now = DateTime.now();
      final config = StremioAddonConfig(
        id: 'test.addon',
        name: 'Test',
        baseUrl: 'https://test.example.com',
        isEnabled: true,
        addedAt: now,
      );

      final jsonMap = config.toJson();
      final restored = StremioAddonConfig.fromJson(jsonMap);

      expect(restored.id, config.id);
      expect(restored.name, config.name);
      expect(restored.baseUrl, config.baseUrl);
      expect(restored.isEnabled, isTrue);
    });
  });

  group('AddonService.normalizeUrl', () {
    test('normalizes stremio:// protocol to https://', () {
      expect(
        AddonService.normalizeUrl(
          'stremio://torrentio.strem.fun/manifest.json',
        ),
        'https://torrentio.strem.fun',
      );
    });

    test('strips trailing slashes and manifest.json suffix', () {
      expect(
        AddonService.normalizeUrl('https://my-addon.example.com/manifest.json'),
        'https://my-addon.example.com',
      );
      expect(
        AddonService.normalizeUrl('https://my-addon.example.com///'),
        'https://my-addon.example.com',
      );
    });

    test('adds https:// if missing protocol', () {
      expect(
        AddonService.normalizeUrl('my-addon.example.com'),
        'https://my-addon.example.com',
      );
    });
  });

  group('StremioAddonPlugin getStreams', () {
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

        final config = StremioAddonConfig(
          id: 'mock.addon',
          name: 'Mock Addon',
          baseUrl: 'https://mock.addon',
          addedAt: DateTime.now(),
        );

        final plugin = StremioAddonPlugin(config: config, client: mockClient);
        final streams = await plugin.getStreams(subjectId: 'tt0137523');

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

      final config = StremioAddonConfig(
        id: 'mock.addon',
        name: 'Mock Addon',
        baseUrl: 'https://mock.addon',
        addedAt: DateTime.now(),
      );

      final plugin = StremioAddonPlugin(config: config, client: mockClient);
      final streams = await plugin.getStreams(
        subjectId: 'tt0944947',
        season: 1,
        episode: 5,
      );

      expect(streams.length, 1);
      expect(streams.first.url, 'https://mock.stream/ep5.mp4');
      expect(streams.first.quality, contains('720p'));
    });
  });
}
