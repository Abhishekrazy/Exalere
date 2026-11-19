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
      final cinefreak = VegaSiteConfig.byId('cinefreak')!;
      expect(cinefreak.catalogPath(2), '/page/2/');
      expect(cinefreak.searchPath('spider man', 3), '/page/3/?s=spider%20man');

      final topmovies = VegaSiteConfig.byId('topmovies')!;
      expect(topmovies.searchPath('leo', 1), '/search/leo/page/1/');
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

    test('reads CineFreak .movie-card grids', () {
      const html = '''
        <div class="movie-card">
          <a href="/movie/film-a"><img data-src="/img/a.jpg" alt="Film A"></a>
          <h3 class="movie-card-title">Film A (2024) Dual Audio</h3>
        </div>
        <div class="movie-card">
          <a href="/movie/film-b"><img data-src="/img/b.jpg" alt="Film B"></a>
          <h3 class="movie-card-title">Film B Season 1</h3>
        </div>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('cinefreak'),
        baseUrl: 'https://cinefreak.net',
        providerId: 'cinefreak',
      );

      expect(items, hasLength(2));
      expect(items.first.title, contains('Film A'));
      expect(items.first.id, 'https://cinefreak.net/movie/film-a');
      expect(items.first.posterUrl, 'https://cinefreak.net/img/a.jpg');
    });

    test('reads CinemaLuxe dooplay grids, including search result items', () {
      const html = '''
        <div class="item movies">
          <div class="poster"><a href="/movie/luxe-a">
            <img alt="Luxe A" data-src="/img/luxe-a.jpg"></a></div>
        </div>
        <div class="result-item">
          <div class="thumbnail"><a href="/movie/luxe-b">
            <img alt="Luxe B" data-src="/img/luxe-b.jpg"></a></div>
        </div>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('cinemaluxe'),
        baseUrl: 'https://cinemalux.cyou',
        providerId: 'cinemaluxe',
      );

      expect(items.map((item) => item.title), ['Luxe A', 'Luxe B']);
    });

    test('reads EonMovies cards whose link is the parent anchor', () {
      const html = '''
        <a href="/eon/movie-a">
          <div class="image-container">
            <img data-src="/img/eon-a.jpg" alt="Eon A">
            <h4 class="card-title">Eon A 2024 Hindi</h4>
          </div>
        </a>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('eonmovies'),
        baseUrl: 'https://new4.eonmovies.click',
        providerId: 'eonmovies',
      );

      expect(items, hasLength(1));
      expect(items.single.title, 'Eon A 2024 Hindi');
      expect(items.single.id, 'https://new4.eonmovies.click/eon/movie-a');
    });

    test('reads TopMovies article cards', () {
      const html = '''
        <div class="post-cards">
          <article><a href="/top/movie-a" title="Top A (2025)"><img
            data-src="/img/top-a.jpg"></a></article>
          <article><a href="/top/movie-b" title="Top B"><img
            data-src="/img/top-b.jpg"></a></article>
        </div>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('topmovies'),
        baseUrl: 'https://moviesleech.help',
        providerId: 'topmovies',
      );

      expect(items.map((item) => item.title), ['Top A (2025)', 'Top B']);
    });

    test('drops cards without a title or a link', () {
      const html = '''
        <div class="movie-card"><img src="/no-link.jpg" alt="Orphan"></div>
        <div class="movie-card"><a href="/x"></a></div>
      ''';

      final items = VegaSiteScraper.parseVegaCards(
        html,
        config: configFor('cinefreak'),
        baseUrl: 'https://cinefreak.net',
        providerId: 'cinefreak',
      );

      expect(items, isEmpty);
    });
  });

  group('VegaSitePlugin', () {
    test('declares a single Home row and no metadata capability', () {
      final plugin = VegaSitePlugin(VegaSiteConfig.byId('cinefreak')!);
      expect(plugin.id, 'cinefreak');
      expect(plugin.catalogs, hasLength(1));
      expect(plugin.supportsMetadata, isFalse);
      expect(plugin.supportsStreams, isTrue);
      expect(plugin.supportsSearch, isTrue);
    });
  });
}
