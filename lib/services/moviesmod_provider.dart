import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'media_provider_plugin.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// Native provider for MoviesMod.
///
/// All discovery and resolution lives in [HubCloudSiteScraper]; this class only
/// supplies the site's identity and paths. Shortlink-gated links are detected and
/// skipped rather than faked — see the base class for why.
class MoviesModProvider extends HubCloudSiteScraper {
  MoviesModProvider({super.client, super.baseUrl});

  static const String providerIdValue = 'moviesmod';
  static const String fallbackBaseUrlValue = 'https://moviesmod.uk.com';

  @override
  String get domainKey => 'Moviesmod';

  @override
  String get providerId => providerIdValue;

  @override
  String get displayName => 'MoviesMod';

  @override
  String get fallbackBaseUrl => fallbackBaseUrlValue;

  /// Forwarding statics so callers and tests keep a site-scoped entry point.
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
class MoviesModPlugin extends MediaProviderPlugin {
  MoviesModPlugin({MoviesModProvider? provider})
    : _provider = provider ?? MoviesModProvider();

  final MoviesModProvider _provider;

  @override
  String get id => MoviesModProvider.providerIdValue;

  @override
  String get name => 'MoviesMod';

  @override
  int get priority => 62;

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
