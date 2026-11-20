import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/fourkhdhub_provider.dart';
import '../../services/media_provider_plugin.dart';

/// Registry adapter for the 4KHDHub engine.
///
/// The engine has no category listing (its catalogue is a search over the
/// site's own index), so this add-on advertises search + metadata + streams and
/// declares no Home rows rather than inventing one.
class FourKHdHubPlugin extends MediaProviderPlugin {
  FourKHdHubPlugin({this.config, FourKHdHubProvider? provider})
    : _provider = provider ?? FourKHdHubProvider();

  final ExalerePluginConfig? config;
  final FourKHdHubProvider _provider;

  @override
  String get id => config?.id ?? 'fourkhdhub';

  @override
  String get name => config?.name ?? '4KHDHub';

  @override
  int get priority => 72;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsMetadata => true;

  @override
  bool get supportsStreams => true;

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
  }) {
    // The callers pass season/episode optimistically; the engine treats any
    // season as "series" and would look for an episode listing on a movie post.
    // Decide from the post itself instead.
    final looksLikeSeries = seriesFrom(
      title: title,
      subjectId: subjectId,
      isSeries: isSeries,
    );
    return _provider.getStreams(
      subjectId: subjectId,
      title: title,
      year: year,
      imdbId: imdbId,
      season: looksLikeSeries ? season : null,
      episode: looksLikeSeries ? episode : null,
      originProviderId: originProviderId ?? id,
      isSeries: looksLikeSeries,
    );
  }

  /// Whether a post is a series, from an explicit hint or the post itself.
  ///
  /// Pure so the rule can be tested: callers pass season/episode optimistically,
  /// and the engine treats any season as "series".
  static bool seriesFrom({
    String? title,
    required String subjectId,
    bool? isSeries,
  }) =>
      isSeries ??
      _seriesPattern.hasMatch('${title ?? ''} ${subjectId.toLowerCase()}');

  static final RegExp _seriesPattern = RegExp(
    r'season|episode|series|complete',
    caseSensitive: false,
  );
}
