import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/extractors/movy_extractor.dart';
import '../services/media_provider_plugin.dart';

/// AutoEmbed — ported from Vega's `autoEmbed`.
///
/// Catalogue and metadata come from Cinemeta (a public Stremio add-on), and the
/// stream comes from Movy: Cinemeta gives the TMDb id, Movy turns it into an HLS
/// playlist through [MovyExtractor]. Vega also fans out to Cinejoy and Vidstuck;
/// Movy alone resolves, so those stay out until they earn their own port.
class AutoEmbedProvider extends MediaProviderPlugin {
  AutoEmbedProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String cinemeta = 'https://v3-cinemeta.strem.io';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  String get id => 'autoembed';

  @override
  String get name => providerNameOverride ?? 'AutoEmbed';

  @override
  int get priority => 53;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => true;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'top', title: 'Top on AutoEmbed'),
  ];

  static Uri searchUri(String query) => Uri.parse(
    '$cinemeta/catalog/movie/top/search=${Uri.encodeComponent(query)}.json',
  );

  static Uri seriesSearchUri(String query) => Uri.parse(
    '$cinemeta/catalog/series/top/search=${Uri.encodeComponent(query)}.json',
  );

  static Uri catalogUri({String type = 'movie'}) =>
      Uri.parse('$cinemeta/catalog/$type/top.json');

  static Uri metaUri(String type, String imdbId) =>
      Uri.parse('$cinemeta/meta/$type/$imdbId.json');

  /// `metas[]` from a Cinemeta catalogue payload.
  static List<MediaItem> parseCatalog(String body, {String? type}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];
    final metas = decoded['metas'];
    if (metas is! List) return const [];

    final items = <MediaItem>[];
    final seen = <String>{};
    for (final entry in metas) {
      if (entry is! Map) continue;
      final id = (entry['imdb_id'] ?? entry['id'] ?? '').toString();
      final name = (entry['name'] ?? '').toString().trim();
      if (id.isEmpty || name.isEmpty || !seen.add(id)) continue;
      final isSeries =
          (entry['type'] ?? type ?? 'movie').toString() == 'series';
      final poster = (entry['poster'] ?? '').toString();
      items.add(
        MediaItem(
          id: id,
          title: name,
          mediaType: isSeries ? MediaType.series : MediaType.movie,
          posterUrl: poster.isEmpty ? null : poster,
          providerId: 'autoembed',
        ),
      );
    }
    return items;
  }

  /// TMDb id, title and year from a Cinemeta meta payload.
  static ({String? tmdbId, String title, String year})? parseMeta(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final meta = decoded['meta'];
    if (meta is! Map) return null;
    final tmdb = (meta['moviedb_id'] ?? '').toString();
    final title = (meta['name'] ?? '').toString();
    final year = (meta['year'] ?? meta['releaseInfo'] ?? '')
        .toString()
        .split('-')
        .first;
    return (tmdbId: tmdb.isEmpty ? null : tmdb, title: title, year: year);
  }

  Future<String?> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _ua, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return response.body;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final movies = await _get(searchUri(trimmed));
    final series = await _get(seriesSearchUri(trimmed));
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final body in [movies, series]) {
      if (body == null) continue;
      for (final item in parseCatalog(body)) {
        if (seen.add(item.id)) items.add(item);
      }
    }
    return items;
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    if (page > 1) return const [];
    final body = await _get(catalogUri());
    if (body == null) return const [];
    return parseCatalog(body);
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final parts = id.split(':');
    final imdb = parts.first;
    final type = parts.length > 1 ? parts[1] : 'movie';
    final body = await _get(metaUri(type, imdb));
    if (body == null) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    final meta = decoded is Map ? decoded['meta'] : null;
    if (meta is! Map) return null;

    final videos = meta['videos'];
    final episodes = <MediaItem>[];
    if (videos is List) {
      for (final entry in videos) {
        if (entry is! Map) continue;
        final season = entry['season'];
        final number = entry['number'];
        if (season is! num || number is! num) continue;
        episodes.add(
          MediaItem(
            id: '$imdb:series:$season:$number',
            title: (entry['name'] ?? 'Episode $number').toString(),
            mediaType: MediaType.series,
            providerId: 'autoembed',
          ),
        );
      }
    }

    return MediaDetails(
      id: id,
      title: (meta['name'] ?? '').toString(),
      mediaType: episodes.isEmpty ? MediaType.movie : MediaType.series,
      description: (meta['description'] ?? '').toString(),
      posterUrl: (meta['poster'] ?? '').toString(),
      seasons: episodes.isEmpty
          ? const []
          : [
              Season(
                seasonNumber: 1,
                episodeCount: episodes.length,
                episodes: [
                  for (var index = 0; index < episodes.length; index++)
                    Episode(
                      season: 1,
                      episode: index + 1,
                      title: episodes[index].title,
                    ),
                ],
              ),
            ],
    );
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
    final parts = subjectId.split(':');
    final imdb = parts.first;
    if (!imdb.startsWith('tt')) return const [];

    // `tt123:series:2:5` carries its own season/episode. Otherwise the caller
    // only knows an id: a movie call often passes season/episode 1 anyway, so
    // the Cinemeta type is decided by which meta answers, not by those hints.
    var seriesType = 'movie';
    var wantedSeason = season;
    var wantedEpisode = episode;
    if (parts.length >= 4) {
      seriesType = 'series';
      wantedSeason = int.tryParse(parts[2]) ?? wantedSeason;
      wantedEpisode = int.tryParse(parts[3]) ?? wantedEpisode;
    } else if (isSeries == true) {
      seriesType = 'series';
    }

    var metaBody = await _get(metaUri(seriesType, imdb));
    if (metaBody == null || parseMeta(metaBody)?.tmdbId == null) {
      final otherType = seriesType == 'movie' ? 'series' : 'movie';
      final other = await _get(metaUri(otherType, imdb));
      if (other != null && parseMeta(other)?.tmdbId != null) {
        metaBody = other;
        seriesType = otherType;
      }
    }
    if (metaBody == null) return const [];
    final meta = parseMeta(metaBody);
    if (meta == null || meta.tmdbId == null) return const [];

    // Movy's seed is single-use and a title can be missing from one server, so
    // one retry with fresh seeds is the difference between a working add-on and
    // a coin flip.
    MovyStream? stream;
    for (var attempt = 0; attempt < 2 && stream == null; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      stream = await MovyExtractor.resolve(
        tmdbId: meta.tmdbId!,
        title: title?.isNotEmpty == true ? title! : meta.title,
        year: year?.isNotEmpty == true ? year! : meta.year,
        mediaType: seriesType == 'series' ? 'tv' : 'movie',
        imdbId: imdb,
        season: wantedSeason ?? 1,
        episode: wantedEpisode ?? 1,
        client: _client,
      );
    }
    if (stream == null) return const [];

    return [
      StreamSource(
        quality: stream.playlist.contains('2160') ? '2160p' : '1080p',
        resolution: '',
        format: stream.playlist.contains('.m3u8') ? 'HLS' : 'MP4',
        url: stream.playlist,
        headers: {
          'User-Agent': MovyExtractor.userAgent,
          'Referer': '${MovyExtractor.origin}/',
          'Origin': MovyExtractor.origin,
        },
        server: 'Movy - ${stream.server}',
        providerId: 'autoembed',
        providerName: name,
      ),
    ];
  }
}
