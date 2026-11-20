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
    this.searchJson = false,
    this.searchable = true,
    this.fetchTimeout = const Duration(seconds: 10),
    this.catalogPageOneTemplate,
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

  /// Some sites have no `/page/1/` route (`/trending` only). Used for page 1.
  final String? catalogPageOneTemplate;

  /// Path template with `{q}` and `{page}` placeholders.
  final String searchPathTemplate;

  final String catalogFilter;
  final VegaCardSpec cards;

  /// Searcher is a JSON endpoint (`hits[].document`) instead of an HTML page.
  final bool searchJson;

  /// Per-page fetch timeout. Raise it for sites behind a slow proxy instead of
  /// slowing every other provider down.
  final Duration fetchTimeout;

  /// Whether the site answers a server-side search. Some print their results
  /// client-side (Typesense behind a WAF); those still resolve streams from
  /// their listing, so they ship as catalogue-only instead of claiming a search
  /// that always comes back empty.
  final bool searchable;

  /// Title of the Home row this provider declares.
  final String rowTitle;

  final int priority;
  final List<String> tags;

  String catalogPath(int page) {
    final template = page == 1 && catalogPageOneTemplate != null
        ? catalogPageOneTemplate!
        : catalogPathTemplate;
    return template
        .replaceAll('{page}', '$page')
        .replaceAll('{filter}', catalogFilter);
  }

  String searchPath(String query, int page) => searchPathTemplate
      .replaceAll('{q}', Uri.encodeComponent(query))
      .replaceAll('{page}', '$page');

  ProviderCatalogRow get homeRow =>
      ProviderCatalogRow(id: 'latest', title: rowTitle);

  /// All ported sites, keyed by provider id.
  static const List<VegaSiteConfig> all = [
    VegaSiteConfig(
      id: 'zeefliz',
      displayName: 'ZeeFliz',
      domainKey: 'zeefliz',
      fallbackBaseUrl: 'https://zeefliz1.xyz',
      catalogPathTemplate: '/page/{page}/',
      searchPathTemplate: '/?s={q}&paged={page}',
      // ZeeFliz answers through a Cloudflare worker proxy that regularly takes
      // more than ten seconds; cutting it off showed up as a flaky "no search
      // hit" in the self-test.
      fetchTimeout: Duration(seconds: 16),
      cards: VegaCardSpec(
        container: 'section.site-main article.post',
        linkSelector: 'a',
      ),
      rowTitle: 'Latest on ZeeFliz',
      priority: 76,
      tags: ["Direct", "HD", "Movies", "TV"],
    ),
    VegaSiteConfig(
      id: 'gokuhd',
      displayName: 'GokuHD',
      domainKey: 'gokuHD',
      fallbackBaseUrl: 'https://gokuhd.nl',
      // GeneratePress cards; post pages carry nexdrive mirrors, which the base
      // scraper follows to V-Cloud/R2. The site's search renders client-side
      // (Typesense behind a WAF), so this one is catalogue + playback only
      // rather than a search chip that would always come back empty.
      catalogPathTemplate: '/page/{page}/',
      catalogPageOneTemplate: '/',
      searchPathTemplate: '/search/{q}/',
      searchable: false,
      cards: VegaCardSpec(
        container: 'article.post',
        titleSelector: 'h2.entry-title a',
        linkSelector: 'h2.entry-title a',
        imageSelector: 'img.wp-post-image',
      ),
      rowTitle: 'Latest on GokuHD',
      priority: 73,
      tags: ['Hindi Dub', 'HD', 'Movies', 'TV'],
    ),
    VegaSiteConfig(
      id: 'multimovies',
      displayName: 'MultiMovies',
      domainKey: 'multi',
      fallbackBaseUrl: 'https://m1.multimovies.courses',
      catalogPathTemplate: '/trending/page/{page}/',
      catalogPageOneTemplate: '/trending',
      searchPathTemplate: '/search?q={q}',
      cards: VegaCardSpec(
        container: 'article.poster-card',
        titleSelector: '.poster-caption a',
        linkSelector: 'a.poster-art',
      ),
      rowTitle: 'Trending on MultiMovies',
      priority: 80,
      tags: ['Direct', 'HD', 'Movies', 'TV'],
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
