import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/extractors/html_grid_parser.dart';
import 'package:exalere/services/uhdmovies_provider.dart';

/// The grid parser is shared by every listing-theme site, so it is tested against
/// both markup shapes those themes actually use: `<article>` cards and
/// `.layout-masonry` divs. Keying off `a[title]` rather than a container means
/// one parser survives a theme change on either site.
void main() {
  group('HtmlGridParser.parse', () {
    const base = 'https://site.example';

    test('parses article-wrapped cards', () {
      const html = '''
        <div class="post-cards">
          <article>
            <a title="Dune (2021)" href="/dune/"><img src="https://i.example/dune.jpg"></a>
          </article>
        </div>
      ''';
      final cards = HtmlGridParser.parse(html, baseUrl: base);

      expect(cards.length, 1);
      expect(cards.single.title, 'Dune (2021)');
      expect(cards.single.url, '$base/dune/');
      expect(cards.single.imageUrl, 'https://i.example/dune.jpg');
    });

    test('parses masonry-div cards from a different theme', () {
      const html = '''
        <div class="gridlove-posts">
          <div class="layout-masonry">
            <a title="Arrival (2016)" href="https://site.example/arrival/">
              <img src="https://i.example/arrival.jpg">
            </a>
          </div>
        </div>
      ''';
      final cards = HtmlGridParser.parse(html, baseUrl: base);

      expect(cards.single.title, 'Arrival (2016)');
      expect(cards.single.url, 'https://site.example/arrival/');
    });

    test('strips the Download prefix from titles', () {
      const html =
          '<a title="Download Sicario (2015)" href="/s/"><img src="x.jpg"></a>';
      expect(
        HtmlGridParser.parse(html, baseUrl: base).single.title,
        'Sicario (2015)',
      );
    });

    test('skips anchors without a title, a link, or a real target', () {
      const html = '''
        <a href="/no-title/"><img src="a.jpg"></a>
        <a title="No Link"><img src="b.jpg"></a>
        <a title="Anchor" href="#"><img src="c.jpg"></a>
        <a title="Script" href="javascript:void(0)"><img src="d.jpg"></a>
      ''';
      expect(HtmlGridParser.parse(html, baseUrl: base), isEmpty);
    });

    test('de-duplicates repeated cards', () {
      const html = '''
        <a title="A" href="/a/"><img src="a.jpg"></a>
        <a title="A again" href="/a/"><img src="a.jpg"></a>
      ''';
      expect(HtmlGridParser.parse(html, baseUrl: base).length, 1);
    });

    test('resolves relative links and leaves absolute ones alone', () {
      const html = '''
        <a title="Rel" href="/rel/"><img src="a.jpg"></a>
        <a title="Abs" href="https://cdn.example/abs/"><img src="b.jpg"></a>
      ''';
      final cards = HtmlGridParser.parse(html, baseUrl: base);
      expect(cards[0].url, '$base/rel/');
      expect(cards[1].url, 'https://cdn.example/abs/');
    });

    test('tolerates a card with no image', () {
      const html = '<a title="No Poster" href="/np/">text only</a>';
      final cards = HtmlGridParser.parse(html, baseUrl: base);
      expect(cards.single.imageUrl, isNull);
    });

    test('returns nothing for a page with no cards', () {
      expect(HtmlGridParser.parse('<html></html>', baseUrl: base), isEmpty);
    });
  });

  group('HtmlGridParser.toMediaItems', () {
    test('derives media type and year per card', () {
      final items = HtmlGridParser.toMediaItems(const [
        GridCard(title: 'Dune (2021)', url: 'https://s/dune'),
        GridCard(title: 'Breaking Bad Season 2', url: 'https://s/bb'),
      ], providerId: 'uhdmovies');

      expect(items[0].year, '2021');
      expect(items[0].mediaType, MediaType.movie);
      expect(items[1].mediaType, MediaType.series);
      expect(items[1].year, isNull);
      expect(items[0].providerId, 'uhdmovies');
      expect(items[0].provider, ProviderType.plugins);
    });
  });

  group('UhdMoviesProvider', () {
    test('uses the site root for the first listing page', () {
      final provider = UhdMoviesProvider();
      expect(provider.catalogPath(1), '/');
      expect(provider.catalogPath(2), '/page/2/');
    });

    test('identifies itself distinctly from MoviesMod', () {
      final provider = UhdMoviesProvider();
      expect(provider.providerId, 'uhdmovies');
      expect(provider.displayName, 'UHDMovies');
      expect(provider.domainKey, 'UhdMovies');
    });

    test('parses its listing through the shared parser', () {
      const html = '<a title="Dune (2021)" href="/dune/"><img src="d.jpg"></a>';
      final items = UhdMoviesProvider.parseListing(
        html,
        baseUrl: 'https://u.example',
      );
      expect(items.single.providerId, 'uhdmovies');
      expect(items.single.title, 'Dune (2021)');
    });

    test('flags the gates it will not solve', () {
      expect(UhdMoviesProvider.isShortlinkGated('https://x/?sid=abc'), isTrue);
      expect(
        UhdMoviesProvider.isShortlinkGated('https://hubcloud.xyz/drive/a'),
        isFalse,
      );
    });
  });
}
