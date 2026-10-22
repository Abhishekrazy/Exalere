import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/extractors/stream_extractors.dart';
import 'package:exalere/services/hdhub4u_provider.dart';

/// The parsers are the part that breaks when a site changes, and they are the
/// only part that can be tested without the live site. Fixtures below mirror the
/// structures the reference implementation reads: a Typesense search response,
/// the `.recent-movies` grid, and HubCloud's download buttons.
void main() {
  group('parseSearchResponse', () {
    const base = 'https://new8.hdhub4u.cl';

    String typesenseBody() => json.encode({
      'hits': [
        {
          'document': {
            'post_title': 'Download Dune (2021) 1080p WEB-DL',
            'permalink': '$base/dune-2021/',
            'post_thumbnail': 'https://img.example/dune.jpg',
          },
        },
        {
          'document': {
            'post_title': 'Download Breaking Bad Season 1',
            'permalink': '/breaking-bad-season-1/',
            'post_thumbnail': 'https://img.example/bb.jpg',
          },
        },
      ],
    });

    test('maps hits to items and strips the Download prefix', () {
      final items = HDHub4uProvider.parseSearchResponse(
        typesenseBody(),
        baseUrl: base,
      );

      expect(items.length, 2);
      expect(items.first.title, 'Dune (2021) 1080p WEB-DL');
      expect(items.first.providerId, HDHub4uProvider.providerId);
      expect(items.first.posterUrl, 'https://img.example/dune.jpg');
    });

    test('resolves relative permalinks against the base URL', () {
      final items = HDHub4uProvider.parseSearchResponse(
        typesenseBody(),
        baseUrl: base,
      );
      expect(items[1].id, '$base/breaking-bad-season-1/');
    });

    test('derives year and media type from the title', () {
      final items = HDHub4uProvider.parseSearchResponse(
        typesenseBody(),
        baseUrl: base,
      );
      expect(items.first.year, '2021');
      expect(items.first.mediaType, MediaType.movie);
      expect(
        items[1].mediaType,
        MediaType.series,
        reason: 'a season pack is a series',
      );
    });

    test('skips hits with no title or no permalink', () {
      final body = json.encode({
        'hits': [
          {
            'document': {'post_title': '', 'permalink': '/x/'},
          },
          {
            'document': {'post_title': 'No Link'},
          },
        ],
      });
      expect(HDHub4uProvider.parseSearchResponse(body), isEmpty);
    });

    test('returns empty for malformed or hostile bodies', () {
      expect(HDHub4uProvider.parseSearchResponse('not json'), isEmpty);
      expect(HDHub4uProvider.parseSearchResponse('{}'), isEmpty);
      expect(HDHub4uProvider.parseSearchResponse('[]'), isEmpty);
      expect(HDHub4uProvider.parseSearchResponse('{"hits":"nope"}'), isEmpty);
    });
  });

  group('parsePostListing', () {
    const html = '''
      <div class="recent-movies">
        <article>
          <a href="/dune-2021/">
            <figure>
              <img src="https://img.example/dune.jpg" alt="Download Dune (2021)">
            </figure>
          </a>
        </article>
        <article>
          <a href="/arrival-2016/">
            <figure>
              <img src="https://img.example/arrival.jpg" alt="Download Arrival (2016)">
            </figure>
          </a>
        </article>
      </div>
    ''';

    test('extracts a card per anchor and de-duplicates', () {
      final items = HDHub4uProvider.parsePostListing(
        html,
        baseUrl: 'https://site.example',
      );

      expect(items.map((i) => i.title), ['Dune (2021)', 'Arrival (2016)']);
      expect(items.first.id, 'https://site.example/dune-2021/');
      expect(items.first.posterUrl, 'https://img.example/dune.jpg');
    });

    test('ignores anchors without an image or alt text', () {
      const bare = '<a href="/x/">No image here</a>';
      expect(
        HDHub4uProvider.parsePostListing(bare, baseUrl: 'https://s.example'),
        isEmpty,
      );
    });
  });

  group('page indirections', () {
    test('finds a var reurl target', () {
      const html =
          '<script>var reurl = "https://next.example/post/1";</script>';
      expect(
        HDHub4uProvider.parseReurlTarget(html),
        'https://next.example/post/1',
      );
    });

    test('ignores an empty or missing reurl', () {
      expect(HDHub4uProvider.parseReurlTarget('var reurl = "";'), isNull);
      expect(HDHub4uProvider.parseReurlTarget('<html></html>'), isNull);
    });

    test('decodes the packed s(o) payload to the next URL', () {
      const target = 'https://next.example/unpacked';
      final inner = base64.encode(utf8.encode(target));
      final jsonStr = json.encode({'o': inner});
      final step3 = base64.encode(utf8.encode(jsonStr));
      final step2 = StreamExtractors.rot13(step3);
      final step1Str = base64.encode(utf8.encode(step2));
      final payload = base64.encode(utf8.encode(step1Str));

      final html = "s('o','$payload',180)";
      expect(HDHub4uProvider.parsePackedPayloadTarget(html), target);
    });

    test('returns null when there is no payload', () {
      expect(HDHub4uProvider.parsePackedPayloadTarget('<html></html>'), isNull);
    });

    test('finds a direct r2.dev link', () {
      const html = '<a href="https://pub-abc.r2.dev/movie.mkv">Direct</a>';
      expect(
        HDHub4uProvider.parseR2DirectLink(html),
        'https://pub-abc.r2.dev/movie.mkv',
      );
    });
  });

  group('parseDriveLinks', () {
    test('orders drive links best quality first', () {
      const html = '''
        <p>720p HEVC</p>
        <a href="https://hubcloud.xyz/drive/seven20">720p</a>
        <p>1080p x264</p>
        <a href="https://hubcloud.xyz/drive/ten80">1080p</a>
      ''';

      final links = HDHub4uProvider.parseDriveLinks(html);

      expect(links.length, 2);
      expect(
        links.first.quality,
        '1080p',
        reason: 'the best quality must be tried first',
      );
      expect(links.first.url, contains('ten80'));
      expect(links.last.quality, '720p');
    });

    test('ignores anchors that are not drive links', () {
      const html =
          '<a href="https://hubcloud.xyz/drive/abc">ok</a>'
          '<a href="https://hubcloud.xyz/other">not a drive link</a>';
      expect(HDHub4uProvider.parseDriveLinks(html).length, 1);
    });

    test('returns empty when there are no drive links', () {
      expect(HDHub4uProvider.parseDriveLinks('<html></html>'), isEmpty);
    });
  });

  group('parseHubcloudServers', () {
    test('names each host and normalises pixeldrain', () {
      const html = '''
        <a class="btn-success" href="https://pixeldrain.com/u/abc123">PixelDrain</a>
        <a class="btn-success" href="https://hubcdn.example/movie.mkv">HubCDN</a>
        <a class="btn-danger" href="https://fastdl.example/x">FastDL</a>
        <a class="btn-secondary" href="https://abc.r2.cloudflarestorage.com/x">CF Storage</a>
      ''';

      final servers = HDHub4uProvider.parseHubcloudServers(html);
      final byName = {for (final s in servers) s.server: s.url};

      expect(
        byName['PixelDrain'],
        'https://pixeldrain.com/api/file/abc123?download',
        reason: 'a share page is not playable; the api URL is',
      );
      expect(byName['HubCDN'], 'https://hubcdn.example/movie.mkv');
      expect(byName['FastDL'], 'https://fastdl.example/x');
      expect(byName['CF Storage'], 'https://abc.r2.cloudflarestorage.com/x');
    });

    test('marks Google Drive links as download-only', () {
      const html =
          '<a href="https://hubcloud.xyz/?link=https://drive.google.com/file/d/1">G</a>';
      final servers = HDHub4uProvider.parseHubcloudServers(html);

      expect(servers.length, 1);
      expect(servers.first.server, 'GDrive');
      expect(servers.first.isDownloadOnly, isTrue);
    });

    test('skips empty, anchor-only and javascript hrefs', () {
      const html =
          '<a href="#">x</a><a href="javascript:void(0)">y</a>'
          '<a>no href</a>';
      expect(HDHub4uProvider.parseHubcloudServers(html), isEmpty);
    });

    test('de-duplicates repeated links', () {
      const html =
          '<a href="https://hubcdn.example/a.mkv">1</a>'
          '<a href="https://hubcdn.example/a.mkv">2</a>';
      expect(HDHub4uProvider.parseHubcloudServers(html).length, 1);
    });
  });

  group('sortServers', () {
    const servers = [
      HdHubServerLink(server: 'GDrive', url: 'g', isDownloadOnly: true),
      HdHubServerLink(server: 'HubCDN', url: 'h'),
      HdHubServerLink(server: 'CF Storage', url: 's'),
      HdHubServerLink(server: 'PixelDrain', url: 'p'),
    ];

    test('streaming puts a streamable source first', () {
      final sorted = HDHub4uProvider.sortServers(servers);
      expect(
        sorted.first.isDownloadOnly,
        isFalse,
        reason: 'a download-only host must never be offered for playback first',
      );
      expect(sorted.last.server, 'GDrive');
    });

    test('download mode ranks Google Drive ahead of Pixeldrain', () {
      final sorted = HDHub4uProvider.sortServers(servers, forDownload: true);
      final names = sorted.map((s) => s.server).toList();
      expect(names.indexOf('GDrive'), lessThan(names.indexOf('PixelDrain')));
    });

    test('does not mutate the input list', () {
      final input = [...servers];
      HDHub4uProvider.sortServers(input);
      expect(
        input.map((s) => s.server).toList(),
        servers.map((s) => s.server).toList(),
      );
    });
  });
}
