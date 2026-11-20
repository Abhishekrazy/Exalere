import 'package:flutter/foundation.dart';

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import 'extractors/hubcloud_extractor.dart';
import 'extractors/nexdrive_extractor.dart';
import 'extractors/typesense_search_parser.dart';
import 'media_provider_plugin.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// Native provider for RogMovies.
///
/// Two things differ from the rest of the HubCloud family:
///  * the poster grid and the search page are drawn in the browser from a
///    Typesense proxy (`/ts-search.php`), so catalogue and search read JSON
///    instead of HTML — there is no markup to break;
///  * the download buttons point at a `nexdrive` mirror page, which lists the
///    V-Cloud server the real CDN link hides behind.
class RogMoviesProvider extends HubCloudSiteScraper {
  RogMoviesProvider({super.client, super.baseUrl});

  static const String providerIdValue = 'rogmovies';
  static const String fallbackBaseUrlValue = 'https://rogmovies.cyou';

  /// The shared domain map calls this site `lux`, the name Vega's provider list
  /// uses for RogMovies; reusing the key keeps one remote map for both.
  @override
  String get domainKey => 'lux';

  @override
  String get providerId => providerIdValue;

  @override
  String get displayName => 'RogMovies';

  @override
  String get fallbackBaseUrl => fallbackBaseUrlValue;

  @override
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    final hits = await _queryIndex(trimmed, page: page);
    // The Typesense proxy is fuzzy — "dune" answered with "Dude", "Dunki" and
    // "Dus June Ki Raat" — and walking any of those plays a different video.
    if (trimmed.isEmpty || trimmed == '*') return hits;
    return hits.where((hit) => MediaItem.matchesQuery(hit, trimmed)).toList();
  }

  @override
  Future<List<MediaItem>> getCatalog({int page = 1}) =>
      _queryIndex('*', page: page);

  /// Queries the Typesense proxy that backs the site's own poster grid.
  ///
  /// `q=*` is its "everything" query, which is what the home grid sends when no
  /// search term is active.
  Future<List<MediaItem>> _queryIndex(String query, {int page = 1}) async {
    if (query.isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$baseUrl/ts-search.php',
      ).replace(queryParameters: {'q': query, 'page': '$page'});
      final body = await fetch(uri.toString());
      if (body == null) return [];
      return TypesenseSearchParser.parse(
        body,
        baseUrl: baseUrl,
        providerId: providerId,
      );
    } catch (e) {
      debugPrint('[$displayName] index query failed: $e');
      return [];
    }
  }

  /// Download buttons live under an `<h5>` release line and point at nexdrive.
  @override
  List<ScrapedLink> parseEpisodeLinks(String html) =>
      NexdriveExtractor.parseEpisodeLinks(html);

  /// Forwarding statics so tests keep a site-scoped entry point.
  static bool isShortlinkGated(String url) =>
      HubCloudSiteScraper.isShortlinkGated(url);
}

/// Registry adapter so the scraper behaves like any other provider.
class RogMoviesPlugin extends MediaProviderPlugin {
  RogMoviesPlugin({RogMoviesProvider? provider})
    : _provider = provider ?? RogMoviesProvider();

  final RogMoviesProvider _provider;

  @override
  String get id => RogMoviesProvider.providerIdValue;

  @override
  String get name => 'RogMovies';

  /// Below the other scrapers: its search index is third-party and flaky.
  @override
  int get priority => 58;

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
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest on RogMovies'),
  ];

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
