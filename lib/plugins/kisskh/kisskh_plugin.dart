import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/provider_catalog_row.dart';
import '../../models/stream_source.dart';
import '../../services/kisskh_provider.dart';
import '../../services/media_provider_plugin.dart';

/// Registry adapter for the KissKh engine.
class KissKhPlugin extends MediaProviderPlugin {
  KissKhPlugin({this.config, KissKhProvider? provider})
    : _provider =
          provider ?? KissKhProvider(providerNameOverride: config?.name);

  final ExalerePluginConfig? config;
  final KissKhProvider _provider;

  @override
  String get id => config?.id ?? _provider.id;

  @override
  String get name => config?.name ?? _provider.name;

  @override
  int get priority => _provider.priority;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => _provider.supportsMovies;

  @override
  bool get supportsSeries => _provider.supportsSeries;

  @override
  bool get supportsSearch => _provider.supportsSearch;

  @override
  bool get supportsCatalogFeeds => _provider.supportsCatalogFeeds;

  @override
  bool get supportsStreams => _provider.supportsStreams;

  @override
  bool get supportsMetadata => _provider.supportsMetadata;

  @override
  List<ProviderCatalogRow> get catalogs => _provider.catalogs;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _provider.getCatalogFeed(category: category, page: page);

  @override
  Future<MediaDetails?> getDetails(String id) => _provider.getDetails(id);

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
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    imdbId: imdbId,
    season: season,
    episode: episode,
    originProviderId: originProviderId,
    isSeries: isSeries,
  );
}
