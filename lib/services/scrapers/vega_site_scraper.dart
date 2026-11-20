import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/provider_catalog_row.dart';
import '../../models/stream_source.dart';
import '../extractors/html_grid_parser.dart';
import '../extractors/hubcloud_extractor.dart';
import '../extractors/nexdrive_extractor.dart';
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
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    if (!config.searchJson) return super.search(query, page: page);
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final body = await fetch('$baseUrl${searchPath(trimmed, page)}');
      if (body == null) return const [];
      return parseJsonHits(body, config, baseUrl);
    } catch (e) {
      debugPrint('[$displayName] JSON search error: $e');
      return const [];
    }
  }

  @override
  List<ScrapedLink> parseEpisodeLinks(String html) {
    // WordPress themes in this family put the quality buttons behind a
    // nexdrive mirror; combine both parsers so either shape resolves.
    final links = NexdriveExtractor.parseEpisodeLinks(html);
    final direct = HubCloudExtractor.parseEpisodeLinks(html);
    final seen = {for (final link in links) link.url};
    for (final link in direct) {
      if (seen.add(link.url)) links.add(link);
    }

    // LinkHub pages are a plain view hop in front of HubDrive/HubCloud.
    final redirectors = RegExp(
      '''href=["']([^"']*(?:linkshub|linkjust)[^"']*)["']''',
      caseSensitive: false,
    );
    for (final match in redirectors.allMatches(html)) {
      final url = (match.group(1) ?? '').trim();
      if (!url.startsWith('http')) continue;
      if (seen.add(url)) {
        links.add(ScrapedLink(title: 'Download', url: url));
      }
    }
    return links;
  }

  @override
  List<MediaItem> parseListingHtml(String html) => parseVegaCards(
    html,
    config: config,
    baseUrl: baseUrl,
    providerId: providerId,
  );

  /// Reads a listing grid using the selectors Vega uses for this site.

  /// Parses the `hits[].document` shape used by WordPress search proxies
  /// (`/api/search.php`): title/url/image under t|post_title, u|permalink, i.
  static List<MediaItem> parseJsonHits(
    String body,
    VegaSiteConfig config,
    String baseUrl,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final hits = decoded is Map ? decoded['hits'] : null;
    if (hits is! List) return const [];

    final cards = <GridCard>[];
    final seen = <String>{};
    for (final hit in hits) {
      if (hit is! Map) continue;
      final doc = hit['document'] is Map ? hit['document'] as Map : hit;
      final title = (doc['t'] ?? doc['post_title'] ?? doc['title'] ?? '')
          .toString()
          .trim();
      final href = (doc['u'] ?? doc['permalink'] ?? doc['url'] ?? '')
          .toString()
          .trim();
      final image = (doc['i'] ?? doc['post_thumbnail'] ?? doc['image'] ?? '')
          .toString()
          .trim();
      if (title.isEmpty || href.isEmpty) continue;

      final uri = Uri.tryParse(href);
      final link = uri == null
          ? href
          : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
      if (!seen.add(link)) continue;

      cards.add(GridCard(title: title, url: link, imageUrl: image));
    }
    return HtmlGridParser.toMediaItems(cards, providerId: config.id);
  }

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
  bool get supportsSearch => config.searchable;

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

  /// Whether a subject id has to be translated to one of this site's own ids.
  ///
  /// These sites key their posts by URL; an IMDb id or a bare number arrives
  /// when the item came from another add-on or from TMDB, and fetching
  /// `$baseUrl/tt1160419` only spends a request on a page that cannot exist.
  static bool subjectNeedsLookup(String subjectId) {
    final trimmed = subjectId.trim();
    if (trimmed.isEmpty) return true;
    return !(trimmed.startsWith('http') || trimmed.startsWith('/'));
  }

  /// Picks the hit that matches the request's shape.
  ///
  /// A search for a series returns movies, announcements and the series post in
  /// whatever order the site likes; taking the first hit sent the walk at a film
  /// page and produced nothing. A series request prefers a title that reads like
  /// one, a film request prefers one that does not.
  static String pickHit(List<MediaItem> hits, {bool? isSeries}) {
    if (hits.isEmpty) return '';
    if (isSeries == null) return hits.first.id;
    bool looksSeries(MediaItem item) {
      // These sites spell the kind in the path (/series/, /movie/), which is far
      // more reliable than the title: "One Piece" reads like nothing, and the
      // lookup then walked a movie page for a series request.
      final path = item.id.toLowerCase();
      if (path.contains('/series/') || path.contains('/tv/')) return true;
      if (path.contains('/movie/')) return false;
      final lower = item.title.toLowerCase();
      return lower.contains('season') ||
          lower.contains('series') ||
          RegExp(r'\bs\d{1,2}\b').hasMatch(lower) ||
          RegExp(r'\bepisode\b').hasMatch(lower);
    }

    for (final item in hits) {
      if (looksSeries(item) == isSeries) return item.id;
    }
    return hits.first.id;
  }

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
  }) async {
    var target = subjectId;
    if (subjectNeedsLookup(target)) {
      final query = title?.trim();
      if (query == null || query.isEmpty) return const [];
      // A foreign id is worth one bounded lookup, not an open-ended search on a
      // site that is already slow: without this a detail page from another
      // add-on waited out the search *and* the link walk.
      List<MediaItem> hits;
      try {
        hits = await search(query).timeout(const Duration(seconds: 8));
      } catch (_) {
        return const [];
      }
      if (hits.isEmpty) return const [];
      target = pickHit(hits, isSeries: isSeries);
    }
    return _scraper.getStreams(
      subjectId: target,
      title: title,
      year: year,
      isSeries: isSeries,
    );
  }
}
