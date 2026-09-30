import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import '../plugins/vidsrc/vidsrc_plugin.dart';
import 'media_provider_plugin.dart';

/// VidSrc media provider plugin providing redundant fallback streams,
/// catalog feeds, and verified search availability.
class VidSrcProvider extends MediaProviderPlugin {
  static final VidSrcProvider _instance = VidSrcProvider._internal();
  factory VidSrcProvider() => _instance;
  VidSrcProvider._internal();

  final VidSrcPlugin _plugin = VidSrcPlugin();

  @override
  String get id => _plugin.id;

  @override
  String get name => _plugin.name;

  @override
  int get priority => _plugin.priority;

  @override
  bool get isEnabled => _plugin.isEnabled;

  @override
  bool get supportsMovies => _plugin.supportsMovies;

  @override
  bool get supportsSeries => _plugin.supportsSeries;

  @override
  bool get supportsSearch => _plugin.supportsSearch;

  @override
  bool get supportsCatalogFeeds => _plugin.supportsCatalogFeeds;

  @override
  Future<void> init() => _plugin.init();

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _plugin.getCatalogFeed(category: category, page: page);

  @override
  Future<List<MediaItem>> search(String query) => _plugin.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _plugin.getDetails(id);

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
  }) => _plugin.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    season: season,
    episode: episode,
    imdbId: imdbId,
    originProviderId: originProviderId,
    isSeries: isSeries,
  );
}
