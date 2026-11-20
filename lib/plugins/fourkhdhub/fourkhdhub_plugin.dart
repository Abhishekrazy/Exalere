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
  }) async {
    // The callers pass season/episode optimistically; the engine treats any
    // season as "series" and would look for an episode listing on a movie post.
    // Decide from the post itself instead.
    // An IMDb id is not a 4KHDHub path: passing one through built
    // `https://4khdhub.one` + `tt1160419`, a host that cannot exist. Resolve
    // the title to the site's own post first, and give up quickly when the
    // subject is ours only by accident.
    if (!isSitePath(subjectId)) {
      final path = await _pathForTitle(title, year, isSeries: isSeries);
      if (path == null) return const [];
      return _provider.getStreams(
        subjectId: path,
        title: title,
        year: year,
        originProviderId: id,
        isSeries: isSeries,
      );
    }

    final looksLikeSeries = seriesFrom(
      title: title,
      subjectId: subjectId,
      isSeries: isSeries,
    );
    final viaSeries = await _provider.getStreams(
      subjectId: subjectId,
      title: title,
      year: year,
      imdbId: imdbId,
      season: looksLikeSeries ? season : null,
      episode: looksLikeSeries ? episode : null,
      originProviderId: originProviderId ?? id,
      isSeries: looksLikeSeries,
    );
    if (viaSeries.isNotEmpty || !looksLikeSeries) return viaSeries;

    // A season post can carry the whole season as packs instead of an episode
    // listing ("Complete All Episodes"). The series walk then finds no episode
    // to follow, and the post's own links are the content.
    return _provider.getStreams(
      subjectId: subjectId,
      title: title,
      year: year,
      imdbId: imdbId,
      originProviderId: originProviderId ?? id,
      isSeries: false,
    );
  }

  /// `tt0133093` style ids come from TMDB/IMDb, not from this site.
  static bool isImdbId(String value) =>
      RegExp(r'^tt\d{5,}$').hasMatch(value.trim());

  /// Whether a subject is one of this site's own post paths.
  ///
  /// A slug from another add-on (`kisskh_demon-slayer-…`) is not, and treating
  /// it as one built `https://4khdhub.onekisskh_…` — a host that cannot exist,
  /// paid for on every resolve.
  static bool isSitePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('http') ||
        trimmed.startsWith('/') ||
        trimmed.toLowerCase().contains('4khdhub');
  }

  /// Finds the site's own post path for a title, or null when it has none.
  Future<String?> _pathForTitle(
    String? title,
    String? year, {
    bool? isSeries,
  }) async {
    final query = title?.trim();
    if (query == null || query.isEmpty) return null;
    final hits = await _provider.search(query);
    if (hits.isEmpty) return null;
    final best = MediaItem.findBestMatch(
      candidates: hits,
      title: query,
      year: year,
      isSeries: isSeries,
      requireTitleMatch: true,
    );
    // When nothing is close, walking the first hit plays a different video.
    return best?.id;
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
