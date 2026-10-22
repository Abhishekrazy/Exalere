import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'media_provider_plugin.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// Native provider for UHDMovies.
///
/// Same resolution tail as MoviesMod — both end at HubCloud — so only the paths
/// differ. Page 1 of the listing lives at the site root rather than `/page/1/`.
class UhdMoviesProvider extends HubCloudSiteScraper {
  UhdMoviesProvider({super.client, super.baseUrl});

  static const String providerIdValue = 'uhdmovies';
  static const String fallbackBaseUrlValue = 'https://uhdmovies.us.org';

  @override
  String get domainKey => 'UhdMovies';

  @override
  String get providerId => providerIdValue;

  @override
  String get displayName => 'UHDMovies';

  @override
  String get fallbackBaseUrl => fallbackBaseUrlValue;

  /// The first listing page is the site root, not `/page/1/`.
  @override
  String catalogPath(int page) => page <= 1 ? '/' : '/page/$page/';

  static List<MediaItem> parseListing(String html, {required String baseUrl}) =>
      HubCloudSiteScraper.parseListing(
        html,
        baseUrl: baseUrl,
        providerId: providerIdValue,
      );

  static bool isShortlinkGated(String url) =>
      HubCloudSiteScraper.isShortlinkGated(url);
}

/// Registry adapter so the scraper behaves like any other provider.
class UhdMoviesPlugin extends MediaProviderPlugin {
  UhdMoviesPlugin({UhdMoviesProvider? provider})
    : _provider = provider ?? UhdMoviesProvider();

  final UhdMoviesProvider _provider;

  @override
  String get id => UhdMoviesProvider.providerIdValue;

  @override
  String get name => 'UHDMovies';

  @override
  int get priority => 61;

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
