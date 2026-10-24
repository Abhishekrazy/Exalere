import 'package:flutter/foundation.dart';

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'extractors/html_grid_parser.dart';
import 'extractors/typesense_search_parser.dart';
import 'media_provider_plugin.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// Native provider for MoviesDrive.
///
/// Two differences from the other HubCloud sites:
///  * **Search is JSON** (`/search.php?q=…`), so it bypasses HTML entirely.
///  * **Listing cards are not `a[title]`** — the anchor wraps a `.poster-card`
///    whose title lives in a child element, so the listing parser is overridden.
class MoviesDriveProvider extends HubCloudSiteScraper {
  MoviesDriveProvider({super.client, super.baseUrl});

  static const String providerIdValue = 'moviesdrive';
  static const String fallbackBaseUrlValue = 'https://new3.moviesdrive.beer';

  @override
  String get domainKey => 'drive';

  @override
  String get providerId => providerIdValue;

  @override
  String get displayName => 'MoviesDrive';

  @override
  String get fallbackBaseUrl => fallbackBaseUrlValue;

  @override
  String catalogPath(int page) => '/page/$page/';

  /// Search hits a JSON endpoint rather than a search page.
  @override
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$baseUrl/search.php',
      ).replace(queryParameters: {'q': trimmed, 'page': '$page'});
      final body = await fetch(uri.toString());
      if (body != null) {
        final items = TypesenseSearchParser.parse(
          body,
          baseUrl: baseUrl,
          providerId: providerId,
        );
        if (items.isNotEmpty) return items;
        // The JSON index is external and can vanish or know nothing; the site's
        // own search page is then the better source.
      }
    } catch (e) {
      debugPrint('[$displayName] search error: $e');
    }
    // Single fallback call, outside the try: an error in the HTML search should
    // surface instead of being swallowed and retried by the catch above.
    return super.search(query, page: page);
  }

  /// Listing cards: an anchor wrapping `.poster-card`.
  @override
  List<MediaItem> parseListingHtml(String html) =>
      parsePosterCards(html, baseUrl: baseUrl, providerId: providerId);

  /// Forwarding statics so callers and tests keep a site-scoped entry point.
  static bool isShortlinkGated(String url) =>
      HubCloudSiteScraper.isShortlinkGated(url);

  /// Parses the `.poster-card` grid.
  ///
  /// The title is a child element rather than an anchor attribute, and the link
  /// is on the wrapping anchor — found by looking back from the card, since
  /// there is no DOM to walk up.
  static List<MediaItem> parsePosterCards(
    String html, {
    required String baseUrl,
    required String providerId,
  }) {
    final items = <MediaItem>[];
    final seen = <String>{};

    // Match only the card's opening tag, then read a window after it. Matching a
    // balanced div is impossible without a DOM, and letting the pattern consume
    // the window would swallow every following card.
    final cardPattern = RegExp(
      r'''class=["'][^"']*poster-card[^"']*["'][^>]*>''',
      caseSensitive: false,
    );
    final titlePattern = RegExp(
      r'''class=["'][^"']*poster-title[^"']*["'][^>]*>([^<]+)<''',
      caseSensitive: false,
    );
    final imgPattern = RegExp(
      r'''<img\s+[^>]*src=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final anchorPattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["']''',
      caseSensitive: false,
    );

    for (final card in cardPattern.allMatches(html)) {
      final windowEnd = card.end + 1200 < html.length
          ? card.end + 1200
          : html.length;
      final inner = html.substring(card.end, windowEnd);
      final title = titlePattern.firstMatch(inner)?.group(1)?.trim();
      if (title == null || title.isEmpty) continue;

      // The link lives on the anchor that wraps this card.
      final lookbackStart = card.start - 500 < 0 ? 0 : card.start - 500;
      final lookback = html.substring(lookbackStart, card.start);
      final anchors = anchorPattern.allMatches(lookback).toList();
      if (anchors.isEmpty) continue;
      final href = anchors.last.group(1);
      if (href == null || href.isEmpty) continue;

      final absolute = href.startsWith('http')
          ? href
          : '$baseUrl${href.startsWith('/') ? '' : '/'}$href';
      if (!seen.add(absolute)) continue;

      final cleaned = title
          .replaceAll(RegExp('Download', caseSensitive: false), '')
          .trim();
      items.add(
        MediaItem(
          id: absolute,
          title: cleaned,
          mediaType: HtmlGridParser.mediaTypeFor(cleaned),
          year: HtmlGridParser.yearFrom(cleaned),
          posterUrl: imgPattern.firstMatch(inner)?.group(1),
          provider: ProviderType.plugins,
          providerId: providerId,
        ),
      );
    }
    return items;
  }
}

/// Registry adapter so the scraper behaves like any other provider.
class MoviesDrivePlugin extends MediaProviderPlugin {
  MoviesDrivePlugin({MoviesDriveProvider? provider})
    : _provider = provider ?? MoviesDriveProvider();

  final MoviesDriveProvider _provider;

  @override
  String get id => MoviesDriveProvider.providerIdValue;

  @override
  String get name => 'MoviesDrive';

  @override
  int get priority => 63;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  /// Resolves a post page straight to a stream; there is no metadata endpoint.
  @override
  bool get supportsMetadata => false;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _provider.getCatalog(page: page);

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
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    isSeries: isSeries,
  );
}
