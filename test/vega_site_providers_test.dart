import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/scrapers/vega_site_config.dart';
import 'package:exalere/services/scrapers/vega_site_scraper.dart';

void main() {
  group('VegaSiteConfig', () {
    test('ids are unique and resolvable', () {
      final ids = VegaSiteConfig.ids;
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(VegaSiteConfig.byId(id), isNotNull);
        expect(VegaSiteConfig.isVegaSite(id), isTrue);
      }
      expect(VegaSiteConfig.byId('not-a-site'), isNull);
    });

    test('path templates substitute page, query and filter', () {
      final zeefliz = VegaSiteConfig.byId('zeefliz')!;
      expect(zeefliz.catalogPath(2), '/page/2/');
      expect(zeefliz.searchPath('spider man', 3), '/?s=spider%20man&paged=3');

      final multimovies = VegaSiteConfig.byId('multimovies')!;
      expect(multimovies.catalogPath(1), '/trending');
      expect(multimovies.catalogPath(2), '/trending/page/2/');
      expect(multimovies.searchPath('leo', 1), '/search?q=leo');
    });

    test('every site declares one Home row and sane tags', () {
      for (final config in VegaSiteConfig.all) {
        expect(config.homeRow.title, isNotEmpty);
        expect(config.tags, isNotEmpty);
        expect(config.fallbackBaseUrl, startsWith('https://'));
      }
    });
  });

  group('VegaSiteScraper.parseVegaCards', () {
    VegaSiteConfig configFor(String id) => VegaSiteConfig.byId(id)!;

    test('reads ZeeFliz site-main article.post cards', () {
      const html = '''
        <section class="site-main">
          <article class="post">
            <a href="/download-film-a/"><img src="/img/a.webp" alt="Film A"></a>
            <h3 class="entry-title"><a href="/download-film-a/">Film A (2024)</a></h3>
          </article>
          <article class="post">
            <a href="/download-film-b/"><img src="/img/b.webp" alt="Film B"></a>
            <h3 class="entry-title"><a href="/download-film-b/">Film B Season 1</a></h3>
          </article>
        </section>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('zeefliz'),
        baseUrl: 'https://zeefliz1.xyz',
        providerId: 'zeefliz',
      );

      expect(items, hasLength(2));
      expect(items.first.title, contains('Film A'));
      expect(items.first.id, 'https://zeefliz1.xyz/download-film-a/');
      expect(items.first.posterUrl, 'https://zeefliz1.xyz/img/a.webp');
    });

    test('reads MultiMovies poster cards with caption links', () {
      const html = '''
        <article class="poster-card">
          <a class="poster-art" href="/movie/film-a">
            <img data-src="/img/a.jpg" alt="Film A">
          </a>
          <div class="poster-caption"><a href="/movie/film-a">Film A</a></div>
        </article>
        <article class="poster-card">
          <a class="poster-art" href="/movie/film-b">
            <img data-src="/img/b.jpg" alt="Film B">
          </a>
          <div class="poster-caption"><a href="/movie/film-b">Film B</a></div>
        </article>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('multimovies'),
        baseUrl: 'https://m1.multimovies.courses',
        providerId: 'multimovies',
      );

      expect(items, hasLength(2));
      expect(items.first.title, 'Film A');
      expect(items.first.id, 'https://m1.multimovies.courses/movie/film-a');
    });
  });

  group('JSON search payloads', () {
    test('parses hits[].document into media items', () {
      const body = '''
        {"hits":[
          {"document":{"t":"Avatar Aang (2026)","u":"/avatar-aang/","i":"https://img/x.jpg"}},
          {"document":{"post_title":"Second Title","permalink":"/second/","post_thumbnail":""}}
        ]}
      ''';
      final items = VegaSiteScraper.parseJsonHits(
        body,
        VegaSiteConfig.byId('multimovies')!,
        'https://m1.multimovies.courses',
      );

      expect(items, hasLength(2));
      expect(items.first.title, contains('Avatar Aang'));
      expect(items.first.id, contains('/avatar-aang/'));
      expect(items.last.title, 'Second Title');
    });

    test('malformed payloads yield no items', () {
      expect(
        VegaSiteScraper.parseJsonHits(
          'not json',
          VegaSiteConfig.byId('multimovies')!,
          'https://x',
        ),
        isEmpty,
      );
    });
  });

  test('registry adapter reports a streams-only Vega site', () {
    final plugin = VegaSitePlugin(VegaSiteConfig.byId('zeefliz')!);

    expect(plugin.id, 'zeefliz');
    expect(plugin.supportsStreams, isTrue);
    expect(plugin.supportsMetadata, isFalse);
    expect(plugin.catalogs, hasLength(1));
  });
}
