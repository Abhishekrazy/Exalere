import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/provider_catalog_row.dart';
import '../../models/stream_source.dart';
import '../extractors/html_grid_parser.dart';
import '../media_provider_plugin.dart';
import 'hubcloud_site_scraper.dart';
import 'vega_site_config.dart';

/// Scraper for a site described by a [VegaSiteConfig].
///
/// Discovery is data-driven (URL templates + card selectors); stream resolution
/// is inherited from [HubCloudSiteScraper], because these sites all end at the
/// same HubCloud / FastDL / PixelDrain tail this app already resolves.
class VegaSiteScraper extends HubCloudSiteScraper {
  VegaSiteScraper(this.config, {super.client, super.baseUrl});

  final VegaSiteConfig config;

  @override
  String get domainKey => config.domainKey;

  @override
  String get providerId => config.id;

  @override
  String get displayName => config.displayName;

  @override
  String get fallbackBaseUrl => config.fallbackBaseUrl;

  @override
  String catalogPath(int page) => config.catalogPath(page);

  @override
  String searchPath(String encodedQuery, int page) =>
      config.searchPath(Uri.decodeComponent(encodedQuery), page);

  @override
  List<MediaItem> parseListingHtml(String html) => parseVegaCards(
    html,
    config: config,
    baseUrl: baseUrl,
    providerId: providerId,
  );

  /// Reads a listing grid using the selectors Vega uses for this site.
  static List<MediaItem> parseVegaCards(
    String html, {
    required VegaSiteConfig config,
    required String baseUrl,
    required String providerId,
  }) {
    final document = html_parser.parse(html);
    final base = Uri.parse(baseUrl);
    final cards = <GridCard>[];

    for (final element in document.querySelectorAll(config.cards.container)) {
      final linkElement = _resolveLink(element, config.cards);
      final href = linkElement?.attributes['href']?.trim();
      if (href == null || href.isEmpty) continue;

      final imageElement =
          element.querySelector(config.cards.imageSelector) ??
          element.querySelector('img');
      final rawImage =
          imageElement?.attributes['data-src'] ??
          imageElement?.attributes['data-original'] ??
          imageElement?.attributes['src'];

      final titleElement = config.cards.titleSelector == null
          ? null
          : element.querySelector(config.cards.titleSelector!);
      var title = titleElement?.text;
      title ??= linkElement?.attributes['title'];
      title ??= imageElement?.attributes['alt'];
      title = title?.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title == null || title.isEmpty) continue;

      Uri? imageUri;
      if (rawImage != null && rawImage.trim().isNotEmpty) {
        imageUri = base.resolve(rawImage.trim());
      }

      cards.add(
        GridCard(
          title: title,
          url: base.resolve(href).toString(),
          imageUrl: imageUri?.toString(),
        ),
      );
    }

    if (cards.isEmpty) {
      debugPrint('[${config.id}] no cards matched ${config.cards.container}');
    }

    return HtmlGridParser.toMediaItems(cards, providerId: providerId);
  }

  /// A card may be the anchor itself, wrap one, or sit inside one (Vega's eon
  /// cards put the link on the parent `.image-container`).
  static dom.Element? _resolveLink(dom.Element element, VegaCardSpec spec) {
    if (spec.linkSelector != null) {
      final inner = element.querySelector(spec.linkSelector!);
      if (inner != null) return inner;
    }
    if (element.localName == 'a' && element.attributes.containsKey('href')) {
      return element;
    }
    final innerAnchor = element.querySelector('a[href]');
    if (innerAnchor != null) return innerAnchor;

    dom.Element? current = element.parent;
    while (current != null) {
      if (current.localName == 'a' && current.attributes.containsKey('href')) {
        return current;
      }
      current = current.parent;
    }
    return null;
  }
}

/// Registry adapter: one plugin per ported Vega site.
class VegaSitePlugin extends MediaProviderPlugin {
  VegaSitePlugin(this.config, {VegaSiteScraper? scraper})
    : _scraper = scraper ?? VegaSiteScraper(config);

  final VegaSiteConfig config;
  final VegaSiteScraper _scraper;

  @override
  String get id => config.id;

  @override
  String get name => config.displayName;

  @override
  int get priority => config.priority;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  /// These sites scrape post pages straight to streams; claiming catalogue feeds
  /// or metadata would make the self-test report failures for capabilities the
  /// provider never had.
  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => false;

  @override
  List<ProviderCatalogRow> get catalogs => [config.homeRow];

  @override
  Future<List<MediaItem>> search(String query) => _scraper.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _scraper.getCatalog(page: page);

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    int? season,
    int? episode,
    String? imdbId,
    String? originProviderId,
    bool? isSeries,
  }) => _scraper.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    isSeries: isSeries,
  );
}
