import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// AnimeStream (anime.uniquestream.net) — ported from Vega's `uniquestream`.
///
/// A public JSON API end to end: `/api/v1/videos/<row>` lists shows,
/// `/api/v1/search` searches, `/api/v1/series/<id>` + `/api/v1/season/<id>/episodes`
/// enumerate episodes, and `/api/v1/episode/<id>/media/dash/<locale>` answers
/// with an `hls.playlist` URL (signed m3u8, with subtitles).
class AnimeStreamProvider extends MediaProviderPlugin {
  AnimeStreamProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://anime.uniquestream.net';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  String get id => 'animestream';

  @override
  String get name => providerNameOverride ?? 'AnimeStream';

  @override
  int get priority => 57;

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
    ProviderCatalogRow(id: 'trending', title: 'Trending anime (AnimeStream)'),
  ];

  static Uri listingUri({
    String row = 'trending',
    int page = 1,
    int limit = 20,
  }) =>
      Uri.parse('$baseUrl/api/v1/videos/$row?page=$page&limit=$limit&type=all');

  // The API ignores `q=` and answers {series: []}; the parameter is `query`.
  static Uri searchUri(String query) => Uri.parse(
    '$baseUrl/api/v1/search?query=${Uri.encodeQueryComponent(query)}',
  );

  static Uri seriesUri(String id) => Uri.parse('$baseUrl/api/v1/series/$id');

  // The API rejects limit > 20 with HTTP 422; long seasons paginate.
  static Uri seasonUri(String seasonId, {int page = 1, int limit = 20}) =>
      Uri.parse(
        '$baseUrl/api/v1/season/$seasonId/episodes'
        '?page=$page&limit=$limit&order_by=asc',
      );

  static Uri mediaUri(String episodeContentId, String locale) =>
      Uri.parse('$baseUrl/api/v1/episode/$episodeContentId/media/dash/$locale');

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static List<dynamic> _list(dynamic decoded, {String? key}) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      if (key != null && decoded[key] is List) return decoded[key] as List;
      if (decoded['data'] is List) return decoded['data'] as List;
    }
    return const [];
  }

  static List<MediaItem> parseListing(String body) {
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final entry in _list(_decode(body))) {
      if (entry is! Map) continue;
      final contentId = (entry['content_id'] ?? '').toString().trim();
      final title = (entry['title'] ?? '').toString().trim();
      if (contentId.isEmpty || title.isEmpty || !seen.add(contentId)) continue;
      final image = (entry['image'] ?? '').toString();
      items.add(
        MediaItem(
          id: contentId,
          title: title,
          mediaType: MediaType.series,
          posterUrl: image.isEmpty ? null : image,
          providerId: 'animestream',
        ),
      );
    }
    return items;
  }

  /// Search answers `{series: [...], movies: [...]}`; both are shown.
  static List<MediaItem> parseSearch(String body) {
    final decoded = _decode(body);
    if (decoded is! Map) return const [];
    final merged = [
      ..._list(decoded['series'] is List ? decoded['series'] : const []),
      ..._list(decoded['movies'] is List ? decoded['movies'] : const []),
    ];

    final items = <MediaItem>[];
    final seen = <String>{};
    for (final entry in merged) {
      if (entry is! Map) continue;
      final contentId = (entry['content_id'] ?? '').toString().trim();
      final title = (entry['title'] ?? '').toString().trim();
      if (contentId.isEmpty || title.isEmpty || !seen.add(contentId)) continue;
      final image = (entry['image'] ?? '').toString();
      items.add(
        MediaItem(
          id: contentId,
          title: title,
          mediaType: MediaType.series,
          posterUrl: image.isEmpty ? null : image,
          providerId: 'animestream',
        ),
      );
    }
    return items;
  }

  /// `{seasons: [{content_id, season_number, episodes}]}`.
  static List<AnimeStreamSeason> parseSeasons(String body) {
    final decoded = _decode(body);
    if (decoded is! Map) return const [];
    final seasons = _list(decoded, key: 'seasons');
    final parsed = <AnimeStreamSeason>[];
    for (var index = 0; index < seasons.length; index++) {
      final entry = seasons[index];
      if (entry is! Map) continue;
      final id = (entry['content_id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      final number = entry['season_number'];
      parsed.add(
        AnimeStreamSeason(
          contentId: id,
          number: number is num
              ? number.toInt()
              : int.tryParse('$number') ?? index + 1,
        ),
      );
    }
    return parsed;
  }

  static List<AnimeStreamEpisode> parseEpisodes(String body) {
    final episodes = <AnimeStreamEpisode>[];
    for (final entry in _list(_decode(body))) {
      if (entry is! Map) continue;
      final contentId = (entry['content_id'] ?? '').toString().trim();
      if (contentId.isEmpty) continue;
      final number = entry['episode_number'];
      episodes.add(
        AnimeStreamEpisode(
          contentId: contentId,
          number: number is num ? number.toInt() : episodes.length + 1,
          title: (entry['title'] ?? '').toString(),
        ),
      );
    }
    return episodes;
  }

  /// The signed HLS playlist from a media payload.
  static String? parsePlaylist(String body) {
    final decoded = _decode(body);
    if (decoded is! Map) return null;
    final hls = decoded['hls'];
    if (hls is Map) {
      final playlist = (hls['playlist'] ?? '').toString().trim();
      if (playlist.startsWith('http')) return playlist;
    }
    final dash = decoded['dash'];
    if (dash is Map) {
      final playlist = (dash['playlist'] ?? dash['url'] ?? '').toString();
      if (playlist.startsWith('http')) return playlist;
    }
    return null;
  }

  Future<http.Response?> _get(Uri uri) async {
    try {
      return await _client
          .get(
            uri,
            headers: {
              'User-Agent': _ua,
              'Accept': 'application/json',
              'Referer': '$baseUrl/',
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final response = await _get(searchUri(trimmed));
    if (response == null || response.statusCode != 200) return const [];
    return parseSearch(response.body);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final response = await _get(listingUri(page: page));
    if (response == null || response.statusCode != 200) return const [];
    return parseListing(response.body);
  }

  Future<List<AnimeStreamSeason>> _seasons(String seriesId) async {
    final response = await _get(seriesUri(seriesId));
    if (response == null || response.statusCode != 200) return const [];
    return parseSeasons(response.body);
  }

  Future<List<AnimeStreamEpisode>> _episodes(String seasonId) async {
    final all = <AnimeStreamEpisode>[];
    for (var page = 1; page <= 3; page++) {
      final response = await _get(seasonUri(seasonId, page: page));
      if (response == null || response.statusCode != 200) break;
      final batch = parseEpisodes(response.body);
      if (batch.isEmpty) break;
      all.addAll(batch);
      if (batch.length < 20) break;
    }
    return all;
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final response = await _get(seriesUri(id));
    if (response == null || response.statusCode != 200) return null;

    final decoded = _decode(response.body);
    final show = decoded is Map ? decoded : const <String, dynamic>{};
    final seasons = await _seasons(id);

    final details = <Season>[];
    for (final season in seasons) {
      final episodes = await _episodes(season.contentId);
      details.add(
        Season(
          seasonNumber: season.number,
          episodeCount: episodes.length,
          episodes: [
            for (final episode in episodes)
              Episode(
                season: season.number,
                episode: episode.number,
                title: episode.title.isEmpty
                    ? 'Episode ${episode.number}'
                    : episode.title,
              ),
          ],
        ),
      );
    }

    return MediaDetails(
      id: id,
      title: (show['title'] ?? '').toString(),
      mediaType: MediaType.series,
      description: (show['description'] ?? '').toString(),
      posterUrl: (show['image'] ?? '').toString(),
      seasons: details,
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
    // A subject from another add-on is an IMDb id, which these sites cannot
    // resolve: their content is keyed by their own ids. Look the title up
    // instead of spending a request on a page that cannot exist.
    var target = subjectId.trim();
    if (RegExp(r'^tt\d{5,}$').hasMatch(target)) {
      final query = title?.trim();
      if (query == null || query.isEmpty) return const [];
      final hits = await search(query);
      if (hits.isEmpty) return const [];
      target = hits.first.id;
    }
    final seriesId = target;
    if (seriesId.isEmpty) return const [];

    final seasons = await _seasons(seriesId);
    if (seasons.isEmpty) return const [];

    final wantedSeason = season ?? seasons.first.number;
    final chosenSeason = seasons.firstWhere(
      (entry) => entry.number == wantedSeason,
      orElse: () => seasons.first,
    );

    final episodes = await _episodes(chosenSeason.contentId);
    if (episodes.isEmpty) return const [];

    final wantedEpisode = episode ?? 1;
    final chosenEpisode = episodes.firstWhere(
      (entry) => entry.number == wantedEpisode,
      orElse: () => episodes.first,
    );

    final media = await _get(mediaUri(chosenEpisode.contentId, 'ja-JP'));
    if (media == null || media.statusCode != 200) return const [];
    final playlist = parsePlaylist(media.body);
    if (playlist == null) return const [];

    return [
      StreamSource(
        quality: 'Auto',
        resolution: '',
        format: 'HLS',
        url: playlist,
        headers: const {'User-Agent': _ua, 'Referer': '$baseUrl/'},
        server: 'AnimeStream',
        providerId: 'animestream',
        providerName: name,
      ),
    ];
  }
}

/// One season entry from AnimeStream's series payload.
class AnimeStreamSeason {
  const AnimeStreamSeason({required this.contentId, required this.number});

  final String contentId;
  final int number;
}

/// One episode entry from AnimeStream's season payload.
class AnimeStreamEpisode {
  const AnimeStreamEpisode({
    required this.contentId,
    required this.number,
    required this.title,
  });

  final String contentId;
  final int number;
  final String title;
}
