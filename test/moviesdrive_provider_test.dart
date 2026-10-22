import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/extractors/typesense_search_parser.dart';
import 'package:exalere/services/moviesdrive_provider.dart';

/// MoviesDrive is the fourth HubCloud-tail provider but differs in two ways worth
/// pinning: search is JSON, and its listing cards are not `a[title]` anchors.
void main() {
  group('TypesenseSearchParser', () {
    const base = 'https://drive.example';

    String body() => json.encode({
      'hits': [
        {
          'document': {
            'post_title': 'Download Dune (2021) 1080p',
            'permalink': '$base/dune/',
            'post_thumbnail': 'https://i.example/dune.jpg',
          },
        },
        {
          'document': {
            'post_title': 'Breaking Bad Season 1',
            'permalink': '/bb-s1/',
            'post_thumbnail': '/img/bb.jpg',
          },
        },
      ],
    });

    test('maps hits to items', () {
      final items = TypesenseSearchParser.parse(
        body(),
        baseUrl: base,
        providerId: 'moviesdrive',
      );

      expect(items.length, 2);
      expect(items.first.title, 'Dune (2021) 1080p');
      expect(items.first.providerId, 'moviesdrive');
      expect(items.first.mediaType, MediaType.movie);
      expect(items.first.year, '2021');
    });

    test('resolves relative permalinks and thumbnails', () {
      final items = TypesenseSearchParser.parse(
        body(),
        baseUrl: base,
        providerId: 'x',
      );
      expect(items[1].id, '$base/bb-s1/');
      expect(items[1].posterUrl, '$base/img/bb.jpg');
    });

    test('detects a season pack as a series', () {
      final items = TypesenseSearchParser.parse(
        body(),
        baseUrl: base,
        providerId: 'x',
      );
      expect(items[1].mediaType, MediaType.series);
    });

    test('can keep the Download prefix when a site wants it', () {
      final items = TypesenseSearchParser.parse(
        body(),
        baseUrl: base,
        providerId: 'x',
        stripDownloadPrefix: false,
      );
      expect(items.first.title, 'Download Dune (2021) 1080p');
    });

    test('skips hits without a title or link', () {
      final malformed = json.encode({
        'hits': [
          {
            'document': {'post_title': '', 'permalink': '/x/'},
          },
          {
            'document': {'post_title': 'No Link'},
          },
        ],
      });
      expect(
        TypesenseSearchParser.parse(malformed, baseUrl: base, providerId: 'x'),
        isEmpty,
      );
    });

    test('returns empty for malformed bodies rather than throwing', () {
      for (final raw in ['', 'not json', '[]', '{}', '{"hits":"nope"}']) {
        expect(
          TypesenseSearchParser.parse(raw, baseUrl: base, providerId: 'x'),
          isEmpty,
          reason: 'body "$raw" should yield no results, not an exception',
        );
      }
    });

    test('tolerates a hit with no document map', () {
      final raw = json.encode({
        'hits': [
          {'document': null},
          {'noDocument': true},
        ],
      });
      expect(
        TypesenseSearchParser.parse(raw, baseUrl: base, providerId: 'x'),
        isEmpty,
      );
    });
  });

  group('MoviesDriveProvider.parsePosterCards', () {
    const base = 'https://drive.example';
    const html = '''
      <div class="grid">
        <a href="/dune-2021/">
          <div class="poster-card">
            <div class="poster-image"><img src="https://i.example/dune.jpg"></div>
            <div class="poster-title">Dune (2021)</div>
          </div>
        </a>
        <a href="/arrival-2016/">
          <div class="poster-card">
            <div class="poster-image"><img src="https://i.example/arrival.jpg"></div>
            <div class="poster-title">Arrival (2016)</div>
          </div>
        </a>
      </div>
    ''';

    test(
      'reads the title from the child element and link from the wrapper',
      () {
        final items = MoviesDriveProvider.parsePosterCards(
          html,
          baseUrl: base,
          providerId: 'moviesdrive',
        );

        expect(items.length, 2);
        expect(items.first.title, 'Dune (2021)');
        expect(items.first.id, '$base/dune-2021/');
        expect(items.first.posterUrl, 'https://i.example/dune.jpg');
        expect(items.first.providerId, 'moviesdrive');
      },
    );

    test('derives year and type', () {
      final items = MoviesDriveProvider.parsePosterCards(
        html,
        baseUrl: base,
        providerId: 'x',
      );
      expect(items.first.year, '2021');
      expect(items.first.mediaType, MediaType.movie);
    });

    test('skips a card with no title', () {
      const bad = '''
        <a href="/x/">
          <div class="poster-card">
            <div class="poster-image"><img src="a.jpg"></div>
          </div>
        </a>
      ''';
      expect(
        MoviesDriveProvider.parsePosterCards(
          bad,
          baseUrl: base,
          providerId: 'x',
        ),
        isEmpty,
      );
    });

    test('skips a card with no wrapping anchor', () {
      const orphan = '''
        <div class="poster-card">
          <div class="poster-image"><img src="a.jpg"></div>
          <div class="poster-title">Orphan</div>
        </div>
      ''';
      expect(
        MoviesDriveProvider.parsePosterCards(
          orphan,
          baseUrl: base,
          providerId: 'x',
        ),
        isEmpty,
      );
    });

    test('returns nothing for a page with no cards', () {
      expect(
        MoviesDriveProvider.parsePosterCards(
          '<html></html>',
          baseUrl: base,
          providerId: 'x',
        ),
        isEmpty,
      );
    });
  });

  group('MoviesDriveProvider identity', () {
    test('is distinct from the other HubCloud sites', () {
      final provider = MoviesDriveProvider();
      expect(provider.providerId, 'moviesdrive');
      expect(provider.displayName, 'MoviesDrive');
      expect(provider.domainKey, 'drive');
    });

    test('inherits the shared gate policy', () {
      expect(MoviesDriveProvider.isShortlinkGated('https://x/?sid=1'), isTrue);
      expect(
        MoviesDriveProvider.isShortlinkGated('https://hubcloud.xyz/drive/a'),
        isFalse,
      );
    });
  });
}
