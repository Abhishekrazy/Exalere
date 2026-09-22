import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/dramachi_provider.dart';
import '../../services/media_provider_plugin.dart';

/// Modular Dramachi streaming and Asian drama catalog plugin for Exalere.
///
/// Implements [MediaProviderPlugin] with high-speed CDN direct MKV/MP4 stream resolution.
class DramachiPlugin extends MediaProviderPlugin {
  final DramachiProvider _provider = DramachiProvider();
  final ExalerePluginConfig? config;

  DramachiPlugin({this.config});

  @override
  String get id => config?.id ?? 'dramachi';

  @override
  String get name => config?.name ?? 'Dramachi Engine';

  @override
  int get priority => 40;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

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
