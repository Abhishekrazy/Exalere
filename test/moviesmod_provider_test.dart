import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/extractors/hubcloud_extractor.dart';
import 'package:exalere/services/moviesmod_provider.dart';

/// MoviesMod shares its resolution tail with HDHub4u, so only the site-specific
/// parsing is asserted here; the shared HubCloud logic has its own coverage.
void main() {
  group('MoviesMod.parseListing', () {
    const base = 'https://moviesmod.uk.com';
    const html =
        '''
      <div class="post-cards">
        <article>
          <a title="Download Dune (2021) 1080p" href="/dune-2021/">
            <img src="https://img.example/dune.jpg">
          </a>
        </article>
        <article>
          <a title="Download Breaking Bad Season 2" href="$base/bb-s2/">
            <img src="https://img.example/bb.jpg">
          </a>
        </article>
      </div>
    ''';

    test('extracts cards from the post grid', () {
      final items = MoviesModProvider.parseListing(html, baseUrl: base);

      expect(items.length, 2);
      // The shared grid parser strips the site's Download prefix, which is
      // noise in the UI.
      expect(items.first.title, 'Dune (2021) 1080p');
      expect(items.first.id, '$base/dune-2021/');
      expect(items.first.posterUrl, 'https://img.example/dune.jpg');
      expect(items.first.providerId, MoviesModProvider.providerIdValue);
    });

    test('resolves absolute hrefs unchanged', () {
      final items = MoviesModProvider.parseListing(html, baseUrl: base);
      expect(items[1].id, '$base/bb-s2/');
    });

    test('derives year and media type', () {
      final items = MoviesModProvider.parseListing(html, baseUrl: base);
      expect(items.first.year, '2021');
      expect(items.first.mediaType, MediaType.movie);
      expect(items[1].mediaType, MediaType.series);
    });

    test('skips articles with no title or no link', () {
      const bad = '''
        <article><a href="/no-title/"><img src="x.jpg"></a></article>
        <article><a title="No Link"><img src="x.jpg"></a></article>
      ''';
      expect(MoviesModProvider.parseListing(bad, baseUrl: base), isEmpty);
    });

    test('de-duplicates repeated cards', () {
      const dup = '''
        <article><a title="A" href="/a/"><img src="a.jpg"></a></article>
        <article><a title="A again" href="/a/"><img src="a.jpg"></a></article>
      ''';
      expect(MoviesModProvider.parseListing(dup, baseUrl: base).length, 1);
    });

    test('tolerates a page with no grid', () {
      expect(
        MoviesModProvider.parseListing('<html></html>', baseUrl: base),
        isEmpty,
      );
    });
  });

  group('MoviesMod.isShortlinkGated', () {
    test('flags the gates this provider does not solve', () {
      for (final url in [
        'https://en.thenaukriadda.in/abc',
        'https://x.example/?sid=123',
        'https://driveseed.org/file/abc',
        'https://driveleech.org/file/abc',
        'https://gdflix.example/x',
        'https://appdrive.example/x',
      ]) {
        expect(
          MoviesModProvider.isShortlinkGated(url),
          isTrue,
          reason: '$url should be treated as gated',
        );
      }
    });

    test('does not flag resolvable links', () {
      for (final url in [
        'https://hubcloud.xyz/drive/abc',
        'https://pixeldrain.com/u/abc',
        'https://cdn.example/movie.mkv',
      ]) {
        expect(MoviesModProvider.isShortlinkGated(url), isFalse);
      }
    });
  });

  group('HubCloudExtractor.parseEpisodeLinks', () {
    test('reads heading anchors', () {
      const html = '''
        <h3><a href="https://hubcloud.xyz/drive/one">1080p WEB-DL</a></h3>
        <h4><a href="https://hubcloud.xyz/drive/two">720p</a></h4>
      ''';
      final links = HubCloudExtractor.parseEpisodeLinks(html);

      expect(links.length, 2);
      expect(links.first.title, '1080p WEB-DL');
      expect(links.first.url, 'https://hubcloud.xyz/drive/one');
    });

    test('reads maxbutton anchors', () {
      const html =
          '<a class="maxbutton btn" href="https://hubcloud.xyz/drive/btn">'
          '<span>480p</span></a>';
      final links = HubCloudExtractor.parseEpisodeLinks(html);

      expect(links.length, 1);
      expect(links.first.title, '480p');
    });

    test('skips placeholders and non-http links', () {
      const html = '''
        <h3><a href="#">Broken</a></h3>
        <h3><a href="/relative/path">Relative</a></h3>
      ''';
      expect(HubCloudExtractor.parseEpisodeLinks(html), isEmpty);
    });

    test('de-duplicates the same target', () {
      const html = '''
        <h3><a href="https://hubcloud.xyz/drive/same">A</a></h3>
        <a class="maxbutton" href="https://hubcloud.xyz/drive/same"><span>B</span></a>
      ''';
      expect(HubCloudExtractor.parseEpisodeLinks(html).length, 1);
    });

    test('falls back to a generic label when the anchor has no text', () {
      const html = '<h3><a href="https://hubcloud.xyz/drive/x"></a></h3>';
      final links = HubCloudExtractor.parseEpisodeLinks(html);
      expect(links.single.title, 'Download');
    });
  });

  group('shared helpers', () {
    test('recognises direct media files', () {
      expect(HubCloudExtractor.isDirectMedia('https://x/a.mkv'), isTrue);
      expect(HubCloudExtractor.isDirectMedia('https://x/a.mp4?t=1'), isTrue);
      expect(HubCloudExtractor.isDirectMedia('https://x/a.m3u8'), isTrue);
      expect(HubCloudExtractor.isDirectMedia('https://x/page.html'), isFalse);
    });

    test('ranks qualities in order', () {
      expect(
        HubCloudExtractor.qualityRank('2160p'),
        greaterThan(HubCloudExtractor.qualityRank('1080p')),
      );
      expect(
        HubCloudExtractor.qualityRank('720p'),
        greaterThan(HubCloudExtractor.qualityRank('480p')),
      );
      expect(HubCloudExtractor.qualityRank('Auto'), 0);
    });
  });
}
