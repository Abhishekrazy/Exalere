import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/bdix_provider.dart';
import '../../services/media_provider_plugin.dart';

/// Modular CircleFTP (BDIX) high-speed local network streaming plugin for Exalere.
///
/// Implements [MediaProviderPlugin] with fast BDIX peering stream resolution.
class CircleFtpPlugin extends MediaProviderPlugin {
  final BdixCircleFtpProvider _provider = BdixCircleFtpProvider();
  final ExalerePluginConfig? config;

  CircleFtpPlugin({this.config});

  @override
  String get id => config?.id ?? 'circleftp';

  @override
  String get name => config?.name ?? 'CircleFTP (BDIX)';

  @override
  int get priority => 30;

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
