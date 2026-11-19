/// Declarative descriptions of the sites ported from Vega's provider bundle.
///
/// Every Vega provider is a small TypeScript module: a base domain, a search URL
/// and a card selector set, with the actual stream resolution happening through
/// the same HubCloud/FastDL/CDN tail this app already handles. Keeping that shape
/// as data means a port is a few lines instead of a new scraper class, and the
/// next batch of sites cannot drift from the pattern.
library;

import '../../models/provider_catalog_row.dart';

/// Selectors for one card in a listing grid.
class VegaCardSpec {
  const VegaCardSpec({
    required this.container,
    this.titleSelector,
    this.linkSelector,
    this.imageSelector = 'img',
  });

  /// CSS selector for each card, e.g. `.movie-card`.
  final String container;

  /// Selector for the title text inside a card. When null the title comes from
  /// the card anchor's `title`, then the poster `alt`.
  final String? titleSelector;

  /// Selector for the card anchor. When null the card itself is the anchor, or
  /// the nearest ancestor anchor is used.
  final String? linkSelector;

  /// Selector for the poster image.
  final String imageSelector;
}

/// One ported site.
class VegaSiteConfig {
  const VegaSiteConfig({
    required this.id,
    required this.displayName,
    required this.domainKey,
    required this.fallbackBaseUrl,
    required this.catalogPathTemplate,
    required this.searchPathTemplate,
    required this.cards,
    required this.rowTitle,
    this.catalogFilter = '',
    this.priority = 70,
    this.tags = const [],
  });

  final String id;
  final String displayName;

  /// Key in the shared domain map (`ProviderBaseUrlService`), which is fed by
  /// Vega's own `urls.json` — the sites move hosts and that map moves with them.
  final String domainKey;
  final String fallbackBaseUrl;

  /// Path template with `{page}` and `{filter}` placeholders.
  final String catalogPathTemplate;

  /// Path template with `{q}` and `{page}` placeholders.
  final String searchPathTemplate;

  final String catalogFilter;
  final VegaCardSpec cards;

  /// Title of the Home row this provider declares.
  final String rowTitle;

  final int priority;
  final List<String> tags;

  String catalogPath(int page) => catalogPathTemplate
      .replaceAll('{page}', '$page')
      .replaceAll('{filter}', catalogFilter);

  String searchPath(String query, int page) => searchPathTemplate
      .replaceAll('{q}', Uri.encodeComponent(query))
      .replaceAll('{page}', '$page');

  ProviderCatalogRow get homeRow =>
      ProviderCatalogRow(id: 'latest', title: rowTitle);

  /// All ported sites, keyed by provider id.
  static const List<VegaSiteConfig> all = [
    VegaSiteConfig(
      id: 'cinefreak',
      displayName: 'CineFreak',
      domainKey: 'cinefreak',
      fallbackBaseUrl: 'https://cinefreak.net',
      catalogPathTemplate: '/page/{page}/',
      searchPathTemplate: '/page/{page}/?s={q}',
      cards: VegaCardSpec(
        container: '.movie-card',
        titleSelector: '.movie-card-title',
        linkSelector: 'a',
      ),
      rowTitle: 'Latest on CineFreak',
      priority: 71,
      tags: ['Direct', 'Multi-Mirror', 'Movies', 'TV'],
    ),
    VegaSiteConfig(
      id: 'cinemaluxe',
      displayName: 'CinemaLuxe',
      domainKey: 'cinemaLuxe',
      fallbackBaseUrl: 'https://cinemalux.cyou',
      catalogPathTemplate: '/page/{page}/',
      searchPathTemplate: '/page/{page}/?s={q}',
      cards: VegaCardSpec(
        container: '.item.movies, .item.tvshows, .result-item',
        linkSelector: 'a',
      ),
      rowTitle: 'Latest on CinemaLuxe',
      priority: 72,
      tags: ['Direct', 'HD', 'Movies', 'TV'],
    ),
    VegaSiteConfig(
      id: 'eonmovies',
      displayName: 'EonMovies',
      domainKey: 'eonMovies',
      fallbackBaseUrl: 'https://new4.eonmovies.click',
      catalogPathTemplate: '/?action=&page={page}&name=&category={filter}',
      searchPathTemplate: '/?action=search&page={page}&name={q}',
      cards: VegaCardSpec(
        container: '.image-container',
        titleSelector: '.card-title',
      ),
      rowTitle: 'Latest on EonMovies',
      priority: 73,
      tags: ['Direct', 'Movies', 'TV'],
    ),
    VegaSiteConfig(
      id: 'topmovies',
      displayName: 'TopMovies',
      domainKey: 'Topmovies',
      fallbackBaseUrl: 'https://moviesleech.help',
      catalogPathTemplate: '/page/{page}/',
      searchPathTemplate: '/search/{q}/page/{page}/',
      cards: VegaCardSpec(container: '.post-cards article', linkSelector: 'a'),
      rowTitle: 'Latest on TopMovies',
      priority: 74,
      tags: ['Direct', 'India', 'Movies', 'TV'],
    ),
  ];

  static VegaSiteConfig? byId(String providerId) {
    for (final config in all) {
      if (config.id == providerId) return config;
    }
    return null;
  }

  static bool isVegaSite(String providerId) => byId(providerId) != null;

  /// Provider ids that have no config yet; used by tests to keep the list honest.
  static List<String> get ids =>
      all.map((config) => config.id).toList(growable: false);
}
