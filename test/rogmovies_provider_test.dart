import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/extractors/hubcloud_extractor.dart';
import 'package:exalere/services/extractors/nexdrive_extractor.dart';
import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/rogmovies_provider.dart';

/// Encodes a URL the way a V-Cloud page does: base64 applied twice.
String _doubleAtob(String value) {
  final once = base64.encode(utf8.encode(value));
  return base64.encode(utf8.encode(once));
}

const _postPage = '''
<html><body>
<h5>Sample Movie 480p [500MB]</h5>
<p><a href="https://nexdrive.beer/abc480/" target="_blank" rel="nofollow">
  <button class="dwd-button">Download Now</button></a></p>
<h5>Sample Movie 720p [1GB]</h5>
<p><a href="https://nexdrive.beer/abc720/" target="_blank" rel="nofollow">
  <button class="dwd-button">Download Now</button></a></p>
<h5>Sample Movie 1080p [2GB]</h5>
<p><a href="https://nexdrive.beer/abc1080/" target="_blank" rel="nofollow">
  <button class="dwd-button">Download Now</button></a></p>
</body></html>
''';

String _nexdrivePage(String quality) =>
    '''
<html><body>
<a href="https://vcloud.my/v$quality">&#x26a1; V-Cloud [Resumable]</a>
<a href="https://gofile.io/d/abc">Gofile mirror</a>
</body></html>
''';

String _vcloudPage(String quality) {
  final token = 'https://vcloud.my/v$quality?token=signed-$quality';
  return '<html><body><script>\n'
      'var url = atob(atob(\'${_doubleAtob(token)}\'));\n'
      '</script></body></html>';
}

String _tokenPage(String quality) =>
    '''
<html><body>
<a class="btn btn-success" href="https://pub-test.r2.dev/file-$quality?token=1">Download</a>
<a class="btn" href="https://pixeldrain.dev/u/abc">PixelDrain</a>
</body></html>
''';

MockClient _client() {
  return MockClient((request) async {
    final host = request.url.host;
    final path = request.url.path;

    if (host.contains('rogmovies')) {
      if (path.contains('ts-search')) {
        return http.Response(
          json.encode({
            'found': 1,
            'hits': [
              {
                'document': {
                  'post_title': 'Download Sample Movie (2026) 1080p',
                  'permalink': '/sample-movie-2026/',
                  'post_thumbnail': 'https://img.example/cover.jpg',
                },
              },
            ],
          }),
          200,
        );
      }
      return http.Response(_postPage, 200);
    }

    if (host.contains('nexdrive')) {
      final quality = path.replaceAll('/', '');
      return http.Response(_nexdrivePage(quality), 200);
    }

    if (host.contains('vcloud')) {
      if (request.url.queryParameters.containsKey('token')) {
        final quality = path.replaceAll('/', '');
        return http.Response(_tokenPage(quality), 200);
      }
      final quality = path.replaceAll('/', '');
      return http.Response(_vcloudPage(quality), 200);
    }

    return http.Response('not found', 404);
  });
}

void main() {
  group('V-Cloud decoding', () {
    test('decodes the double atob() URL a V-Cloud page hides', () {
      final html =
          '<script>var url = atob(atob(\'${_doubleAtob('https://vcloud.my/x?token=1')}\'));</script>';
      expect(
        HubCloudExtractor.decodeDoubleAtob(html),
        'https://vcloud.my/x?token=1',
      );
    });

    test('returns null for pages without a decodable URL', () {
      expect(
        HubCloudExtractor.decodeDoubleAtob('<html>nothing</html>'),
        isNull,
      );
      expect(
        HubCloudExtractor.decodeDoubleAtob(
          '<script>atob("not-base64")</script>',
        ),
        isNull,
      );
    });

    test('recognises vcloud URLs', () {
      expect(HubCloudExtractor.isVCloudUrl('https://vcloud.my/abc'), isTrue);
      expect(
        HubCloudExtractor.isVCloudUrl('https://hubcloud.cx/drive/1'),
        isFalse,
      );
    });

    test('treats an R2 CDN link as a streamable server', () {
      final servers = HubCloudExtractor.parseServers(
        '<a href="https://pub-test.r2.dev/file-1080?token=1">Download</a>',
      );
      expect(servers.single.server, 'R2 CDN');
      expect(servers.single.isDownloadOnly, isFalse);
    });
  });

  group('Nexdrive pages', () {
    test('embed redirectors are treated as mirrors and decoded', () {
      const embedUrl =
          'https://zee-dl.lol/embed.php?download=VlE8HjcmvV9byFjjtApxrk1EY';
      expect(NexdriveExtractor.isEmbedRedirectUrl(embedUrl), isTrue);
      expect(
        NexdriveExtractor.isEmbedRedirectUrl('https://hubcloud.cx/drive/9'),
        isFalse,
      );

      const html = """
        <script>
          var reurl = "https://zee-dl.lol/dl.php?link=https%3A%2F%2Fvideo-downloads.googleusercontent.com%2Fabc123";
        </script>
      """;
      expect(
        NexdriveExtractor.extractRedirectTarget(html),
        'https://video-downloads.googleusercontent.com/abc123',
      );
      expect(NexdriveExtractor.extractRedirectTarget('<html></html>'), isNull);
    });

    test('collects server links by host, not by emoji label', () {
      final links = NexdriveExtractor.parseServerLinks('''
        <a href="https://vcloud.my/abc">⚡ V-Cloud [Resumable]</a>
        <a href="https://gofile.io/d/xyz">Gofile</a>
        <a href="https://example.com/about">About us</a>
        <a href="https://hubcloud.cx/drive/9">HubCloud</a>
      ''');

      expect(links.map((l) => l.url), [
        'https://vcloud.my/abc',
        'https://gofile.io/d/xyz',
        'https://hubcloud.cx/drive/9',
      ]);
    });

    test('labels post-page buttons with the quality printed above them', () {
      final links = NexdriveExtractor.parseEpisodeLinks(_postPage);

      expect(links, hasLength(3));
      expect(links.first.title, '1080p');
      expect(links[1].title, '720p');
      expect(links[2].title, '480p');
      expect(links.first.url, 'https://nexdrive.beer/abc1080/');
    });

    test('falls back to plain nexdrive anchors when there is no button', () {
      final links = NexdriveExtractor.parseEpisodeLinks(
        '<h5>Movie 720p</h5><a href="https://nexdrive.beer/plain720/">Mirror</a>',
      );
      expect(links.single.title, '720p');
    });
  });

  group('RogMovies provider', () {
    test('searches through the site Typesense proxy', () async {
      final provider = RogMoviesProvider(
        client: _client(),
        baseUrl: 'https://rogmovies.example',
      );

      final items = await provider.search('sample');

      expect(items.single.title, 'Sample Movie (2026) 1080p');
      expect(items.single.id, 'https://rogmovies.example/sample-movie-2026/');
    });

    test(
      'resolves the post page through nexdrive and vcloud to the CDN',
      () async {
        final provider = RogMoviesProvider(
          client: _client(),
          baseUrl: 'https://rogmovies.example',
        );

        final streams = await provider.getStreams(
          subjectId: 'https://rogmovies.example/sample-movie-2026/',
        );

        expect(streams, isNotEmpty);
        final top = streams.first;
        expect(top.server, 'R2 CDN');
        expect(top.quality, '1080p');
        expect(top.providerId, 'rogmovies');
        expect(top.url, contains('r2.dev'));
        expect(
          streams.map((s) => s.quality).toSet(),
          containsAll(<String>['1080p', '720p', '480p']),
        );
      },
    );

    test('skips a mirror page that exposes no supported server', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('ts-search')) {
          return http.Response('{}', 200);
        }
        if (request.url.host.contains('nexdrive')) {
          // A timer/rotation page with nothing fetchable.
          return http.Response('<html><body>Please wait…</body></html>', 200);
        }
        return http.Response(_postPage, 200);
      });
      final provider = RogMoviesProvider(
        client: client,
        baseUrl: 'https://rogmovies.example',
      );

      final streams = await provider.getStreams(
        subjectId: 'https://rogmovies.example/sample-movie-2026/',
      );
      expect(streams, isEmpty);
    });
  });

  group('installation wiring', () {
    test('built-in manifest and store entry exist', () {
      expect(
        PluginService.builtInEngineManifests.containsKey('rogmovies'),
        isTrue,
      );
      expect(
        PluginService.builtInEngineFor('rogmovies://engine')?.name,
        'RogMovies',
      );
    });

    test('createPlugin builds the native provider', () {
      final plugin = createPlugin(
        ExalerePluginConfig(
          id: 'rogmovies',
          name: 'RogMovies',
          baseUrl: 'rogmovies://engine',
          addedAt: DateTime.now(),
          manifest: PluginService.builtInEngineManifests['rogmovies'],
        ),
      );
      expect(plugin, isA<RogMoviesPlugin>());
      expect(plugin.catalogs.single.title, 'Latest on RogMovies');
      expect(plugin.supportsMetadata, isFalse);
    });

    test('is not registered by default', () {
      ProviderRegistry().clearAll();
      expect(ProviderRegistry().getProvider('rogmovies'), isNull);
      expect(
        ProviderRegistry().streamProviders.any((p) => p.id == 'rogmovies'),
        isFalse,
      );
    });
  });
}
