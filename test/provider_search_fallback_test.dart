import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/services/hdhub4u_provider.dart';
import 'package:exalere/services/moviesdrive_provider.dart';

/// The scrapers depend on third-party search indexes and on site markup I cannot
/// verify live. These tests pin the recovery paths that keep a provider usable
/// when either assumption fails.
void main() {
  group('HDHub4u search fallback', () {
    const listingHtml = '''
      <div class="recent-movies">
        <article>
          <a href="/dune-2021/">
            <figure><img src="https://i.example/dune.jpg" alt="Download Dune (2021)"></figure>
          </a>
        </article>
      </div>
    ''';

    test(
      'falls back to the site search when the JSON index is empty',
      () async {
        final requested = <String>[];
        final client = MockClient((request) async {
          requested.add(request.url.toString());
          if (request.url.host.contains('pingora')) {
            // Index answers, but knows nothing about this query.
            return http.Response(json.encode({'hits': []}), 200);
          }
          return http.Response(listingHtml, 200);
        });

        final provider = HDHub4uProvider(
          client: client,
          baseUrl: 'https://site.example',
        );
        final items = await provider.search('Dune');

        expect(
          items,
          isNotEmpty,
          reason: 'the HTML fallback should recover results',
        );
        expect(items.first.title, 'Dune (2021)');
        expect(
          requested.any((u) => u.contains('s=Dune')),
          isTrue,
          reason: 'the site search page should have been tried',
        );
      },
    );

    test('does not touch the site search when the index has results', () async {
      var siteHits = 0;
      final client = MockClient((request) async {
        if (request.url.host.contains('pingora')) {
          return http.Response(
            json.encode({
              'hits': [
                {
                  'document': {
                    'post_title': 'Dune (2021)',
                    'permalink': '/dune/',
                    'post_thumbnail': 'https://i.example/d.jpg',
                  },
                },
              ],
            }),
            200,
          );
        }
        siteHits++;
        return http.Response(listingHtml, 200);
      });

      final provider = HDHub4uProvider(
        client: client,
        baseUrl: 'https://site.example',
      );
      final items = await provider.search('Dune');

      expect(items.single.title, 'Dune (2021)');
      expect(siteHits, 0, reason: 'the fallback must not run needlessly');
    });

    test('falls back when the index errors out', () async {
      final client = MockClient((request) async {
        if (request.url.host.contains('pingora')) {
          return http.Response('upstream down', 503);
        }
        return http.Response(listingHtml, 200);
      });

      final provider = HDHub4uProvider(
        client: client,
        baseUrl: 'https://site.example',
      );
      final items = await provider.search('Dune');
      expect(items, isNotEmpty);
    });

    test('returns empty rather than throwing when everything fails', () async {
      final client = MockClient((_) async => http.Response('nope', 500));
      final provider = HDHub4uProvider(
        client: client,
        baseUrl: 'https://site.example',
      );
      expect(await provider.search('Dune'), isEmpty);
    });

    test('an empty query never hits the network', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('', 200);
      });
      final provider = HDHub4uProvider(
        client: client,
        baseUrl: 'https://site.example',
      );
      expect(await provider.search('   '), isEmpty);
      expect(calls, 0);
    });
  });

  group('MoviesDrive search fallback', () {
    const genericCards = '''
      <a title="Dune (2021)" href="/dune/"><img src="https://i.example/d.jpg"></a>
    ''';

    test(
      'falls back to the site search when the JSON index is empty',
      () async {
        final client = MockClient((request) async {
          if (request.url.path.contains('search.php')) {
            return http.Response(json.encode({'hits': []}), 200);
          }
          return http.Response(genericCards, 200);
        });

        final provider = MoviesDriveProvider(
          client: client,
          baseUrl: 'https://drive.example',
        );
        final items = await provider.search('Dune');

        expect(items, isNotEmpty);
        expect(items.first.title, 'Dune (2021)');
      },
    );

    test('returns empty when both sources fail', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      final provider = MoviesDriveProvider(
        client: client,
        baseUrl: 'https://drive.example',
      );
      expect(await provider.search('Dune'), isEmpty);
    });
  });

  group('listing parser resilience', () {
    test('recovers generic cards when the site-specific parser finds none', () {
      // MoviesDrive expects `.poster-card`; this markup has plain a[title] cards,
      // which is what a theme change would look like.
      final provider = MoviesDriveProvider(baseUrl: 'https://drive.example');
      final items = provider.parseListingResilient(
        '<a title="Arrival (2016)" href="/arrival/"><img src="a.jpg"></a>',
      );

      expect(items, isNotEmpty, reason: 'the generic parser should recover');
      expect(items.single.title, 'Arrival (2016)');
    });

    test('prefers the site-specific parser when it works', () {
      final provider = MoviesDriveProvider(baseUrl: 'https://drive.example');
      final items = provider.parseListingResilient('''
        <a href="/dune/">
          <div class="poster-card">
            <div class="poster-image"><img src="d.jpg"></div>
            <div class="poster-title">Dune (2021)</div>
          </div>
        </a>
      ''');

      expect(items.single.title, 'Dune (2021)');
    });

    test('returns empty when neither parser finds anything', () {
      final provider = MoviesDriveProvider(baseUrl: 'https://drive.example');
      expect(provider.parseListingResilient('<html></html>'), isEmpty);
    });
  });
}
