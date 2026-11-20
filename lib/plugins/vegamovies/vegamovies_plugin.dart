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
      final hits = await _provider.search(query);
      if (hits.isEmpty) return const [];
      target = hits.first.id;
    }
    return _provider.getStreams(subjectId: target);
  }
}
