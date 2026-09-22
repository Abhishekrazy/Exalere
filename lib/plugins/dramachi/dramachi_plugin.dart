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

  @override
  String get id => 'dramachi';

  @override
  String get name => 'Dramachi';

  @override
  int get priority => 40;

  @override
  bool get isEnabled => true;

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
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    imdbId: imdbId,
    season: season,
    episode: episode,
  );
}
