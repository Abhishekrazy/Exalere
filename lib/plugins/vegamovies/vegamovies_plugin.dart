import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/provider_catalog_row.dart';
import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import '../../services/vegamovies_provider.dart';

/// Registry adapter for the VegaMovies engine.
class VegaMoviesPlugin extends MediaProviderPlugin {
  VegaMoviesPlugin({this.config, VegaMoviesProvider? provider})
    : _provider = provider ?? VegaMoviesProvider();

  final ExalerePluginConfig? config;
  final VegaMoviesProvider _provider;

  @override
  String get id => config?.id ?? 'vegamovies';

  @override
  String get name => config?.name ?? 'VegaMovies';

  @override
  int get priority => 74;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  /// These sites resolve a post page straight to a stream; claiming metadata
  /// would make the self-test fail for a capability the provider never had.
  @override
  bool get supportsMetadata => false;

  @override
  bool get supportsStreams => true;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest on VegaMovies'),
  ];

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _provider.getCatalog(page: page);

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

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
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async {
    // These posts are keyed by URL; an IMDb id arrives when the item came from
    // TMDB or from another add-on, and the site has no such page.
    var target = subjectId;
    if (!(target.startsWith('http') || target.startsWith('/'))) {
      final query = title?.trim();
      if (query == null || query.isEmpty) return const [];
      List<MediaItem> hits;
      try {
        // Same rule as the config-driven add-ons: one bounded lookup, then the
        // walk — a foreign id must not cost the search *and* the full budget.
        hits = await _provider
            .search(query)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        return const [];
      }
      if (hits.isEmpty) return const [];
      target = pickHit(hits, isSeries: isSeries);
    }
    return _provider.getStreams(subjectId: target);
  }
}
