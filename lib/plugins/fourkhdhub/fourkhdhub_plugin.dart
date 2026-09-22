import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/fourkhdhub_provider.dart';
import '../../services/media_provider_plugin.dart';

/// Modular 4K HD Hub streaming and catalog plugin for Exalere.
///
/// Implements [MediaProviderPlugin] to provide direct high-bitrate 4K, 1080p,
/// and MKV/MP4 stream resolution with mirror failover and preflight validation.
class FourKHdHubPlugin extends MediaProviderPlugin {
  final FourKHdHubProvider _hub = FourKHdHubProvider();
  final ExalerePluginConfig? config;

  FourKHdHubPlugin({this.config});

  @override
  String get id => config?.id ?? 'fourkhdhub';

  @override
  String get name => config?.name ?? '4K HD Hub';

  @override
  int get priority => 50; // Direct high-speed 4K/1080p source provider

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<List<MediaItem>> search(String query) => _hub.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _hub.getDetails(id);

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
  }) => _hub.getStreams(
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
