import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/services/extractors/hubcloud_extractor.dart';
import 'package:exalere/services/movies4u_provider.dart';

/// Movies4U is a HubCloud site with one twist: its post page buttons point at a
/// release gateway (`mdrive.cloud/mdisk/<id>`), and that page is what lists the
/// mirrors. These tests pin the whole chain against captured pages, so a theme
/// or markup change here fails loudly instead of silently emptying the provider.
String fixture(String name) =>
    File('test/fixtures/movies4u/$name').readAsStringSync();

void main() {
  group('listing', () {
    test('reads the entry-card grid', () {
      final items = Movies4UProvider.parseEntryCards(
        fixture('listing.html'),
        baseUrl: 'https://movies4u.cr',
        providerId: 'movies4u',
      );

      expect(items, isNotEmpty);
      expect(items.first.title, 'Street Fighter (2026)');
      expect(items.first.id, startsWith('https://movies4u.nf/'));
      expect(items.first.posterUrl, endsWith('.webp'));
      // Duplicate cards would render twice in the grid.
      expect(items.map((i) => i.id).toSet().length, items.length);
    });

    test('cleans release tags out of card titles', () {
      expect(
        Movies4UProvider.cleanTitle(
          'Gajab Raat (2026) WEB-DL Multi Audio [Hindi + Tamil + Telugu] '
          'Full Movie',
        ),
        'Gajab Raat (2026)',
      );
      expect(
        Movies4UProvider.cleanTitle(
          'Download Udta Teer (2026) Hindi HQ HDTC 480p | 720p | 1080p',
        ),
        'Udta Teer (2026)',
      );
      // A title that merely starts with a language word must survive.
      expect(
        Movies4UProvider.cleanTitle('Hindi Medium (2017) 1080p WEB-DL'),
        'Hindi Medium (2017)',
      );
    });
  });

  group('post page', () {
    test('extracts one gateway link per quality, best first', () {
      final links = Movies4UProvider.parseGatewayLinks(fixture('post.html'));

      expect(links, isNotEmpty);
      expect(links.every((l) => l.url.contains('mdrive.cloud')), isTrue);
      expect(links.map((l) => l.quality), contains('1080p'));
      expect(links.map((l) => l.quality), contains('480p'));
      // Sorted descending so the player offers the best source first.
      expect(links.first.quality, '1080p');
    });

    test('recognises gateway hosts and ignores ordinary links', () {
      expect(
        Movies4UProvider.isGatewayPage('https://mdrive.cloud/mdisk/1'),
        isTrue,
      );
      expect(Movies4UProvider.isGatewayPage('https://movies4u.nf/x/'), isFalse);
      // Gated links stay gated: the provider must not claim them as playable.
      expect(
        Movies4UProvider.isShortlinkGated('https://gdflix.vip/file/abc'),
        isTrue,
      );
    });
  });

  group('resolution chain', () {
    Movies4UProvider providerReturning(Map<String, String> bodies) {
      final client = MockClient((request) async {
        for (final entry in bodies.entries) {
          if (request.url.toString().contains(entry.key)) {
            // The captured pages carry typographic quotes, so the body has to be
            // handed over as UTF-8 bytes; the default latin-1 encode throws.
            return http.Response.bytes(
              utf8.encode(entry.value),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }
        }
        return http.Response('not found', 404);
      });
      return Movies4UProvider(client: client, baseUrl: 'https://movies4u.nf');
    }

    test('walks post page -> gateway -> HubCloud -> signed R2 link', () async {
      final provider = providerReturning({
        'movies4u.nf/gajab-raat': fixture('post.html'),
        'mdrive.cloud': fixture('gateway.html'),
        'hubcloud.ist': fixture('hubcloud.html'),
        'gamerxyt.com': fixture('minted.html'),
      });

      final streams = await provider.getStreams(
        subjectId:
            'https://movies4u.nf/gajab-raat-2026-web-dl-multi-audio-hindi-'
            'tamil-telugu-full-movie/',
        title: 'Gajab Raat',
      );

      expect(streams, isNotEmpty);
      expect(
        streams.every((s) => s.providerId == 'movies4u'),
        isTrue,
        reason: 'sources must be attributed to this provider',
      );
      expect(
        streams.any((s) => s.url.contains('cloudflarestorage')),
        isTrue,
        reason: 'the signed R2 URL is what actually streams',
      );
      expect(
        streams.any((s) => s.quality == '1080p'),
        isTrue,
        reason: 'the post page labelled this release 1080p',
      );
    });

    test(
      'an unreachable post page yields nothing rather than a fake',
      () async {
        final provider = providerReturning(const {});
        final streams = await provider.getStreams(
          subjectId: 'https://movies4u.nf/missing/',
        );
        expect(streams, isEmpty);
      },
    );
  });

  group('extractor', () {
    test('finds the download endpoint behind a HubCloud button', () {
      final endpoint = HubCloudExtractor.findDownloadEndpoint(
        fixture('hubcloud.html'),
      );

      expect(endpoint, isNotNull);
      expect(endpoint, contains('hubcloud.php'));
      // Escaped ampersands would break the signed request.
      expect(endpoint, isNot(contains('&amp;')));
    });

    test('reads the signed R2 file from the minted page', () {
      final servers = HubCloudExtractor.parseServers(fixture('minted.html'));

      expect(servers, isNotEmpty);
      expect(servers.first.server, 'CF Storage');
      expect(servers.first.url, contains('cloudflarestorage'));
    });
  });
}
