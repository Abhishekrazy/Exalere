import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// KickAssAnime — anime catalogue and player, ported from Vega's provider.
///
/// The whole chain is open JSON plus one HTML player page: `/api/show/trending`
/// lists shows, `/api/show/<slug>/episodes` lists episodes,
/// `/api/show/<slug>/episode/ep-<n>-<slug>` lists servers, and each server's
/// player page embeds its HLS manifest as `manifest":[N,"https://…m3u8"]`.
class KickAssAnimeProvider extends MediaProviderPlugin {
  KickAssAnimeProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://kaa.lt';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  @override
  String get id => 'kickassanime';

  @override
  String get name => providerNameOverride ?? 'KickAssAnime';

  @override
  int get priority => 58;

  @override
  bool get supportsMovies => false;

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
    ProviderCatalogRow(id: 'trending', title: 'Trending anime (KickAssAnime)'),
  ];

  static Uri trendingUri(int page) =>
      Uri.parse('$baseUrl/api/show/trending?page=$page');

  static Uri searchUri() => Uri.parse('$baseUrl/api/fsearch');

  static Uri showUri(String slug) => Uri.parse('$baseUrl/api/show/$slug');

  static Uri episodesUri(String slug, {int page = 1, String lang = 'ja-JP'}) =>
      Uri.parse('$baseUrl/api/show/$slug/episodes?page=$page&lang=$lang');

  static Uri episodeUri(String slug, String number, String episodeSlug) =>
      Uri.parse('$baseUrl/api/show/$slug/episode/ep-$number-$episodeSlug');

  /// Poster URL from KAA's `{hq, sm, url}` object.
  static String? posterUrl(dynamic poster) {
    if (poster is! Map) return null;
    final hq = (poster['hq'] ?? '').toString();
    if (hq.isNotEmpty) return '$baseUrl/image/poster/$hq.webp';
    final sm = (poster['sm'] ?? '').toString();
    if (sm.isNotEmpty) return '$baseUrl/image/poster/$sm.webp';
    final url = (poster['url'] ?? '').toString();
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$baseUrl/${url.replaceFirst(RegExp(r'^/+'), '')}';
  }

  /// Shared `{result: [...]}` list parsing for trending, search and episodes.
  static List<dynamic> resultList(String body, {String key = 'result'}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final list = decoded is Map ? decoded[key] : null;
    return list is List ? list : const [];
  }

  static List<MediaItem> parseShows(String body) {
    final items = <MediaItem>[];
    final seen = <String>{};
    for (final entry in resultList(body)) {
      if (entry is! Map) continue;
      final slug = (entry['slug'] ?? '').toString().trim();
      final title = ((entry['title_en'] ?? entry['title']) ?? '')
          .toString()
          .trim();
      if (slug.isEmpty || title.isEmpty || !seen.add(slug)) continue;
      items.add(
        MediaItem(
          id: slug,
          title: title,
          mediaType: MediaType.series,
          posterUrl: posterUrl(entry['poster']),
          providerId: 'kickassanime',
        ),
      );
    }
    return items;
  }

  /// Episode number + slug pairs from an episodes payload.
  static List<KickAssAnimeEpisode> parseEpisodes(String body) {
    final episodes = <KickAssAnimeEpisode>[];
    for (final entry in resultList(body)) {
      if (entry is! Map) continue;
      final number = (entry['episode_string'] ?? entry['episode_number'] ?? '')
          .toString()
          .trim();
      final slug = (entry['slug'] ?? '').toString().trim();
      if (number.isEmpty || slug.isEmpty) continue;
      episodes.add(KickAssAnimeEpisode(number: number, slug: slug));
    }
    return episodes;
  }

  /// HLS manifest embedded in a server player page.
  static String? parseManifest(String html, String playerUrl) {
    final clean = html.replaceAll('&quot;', '"').replaceAll(r'\"', '"');
    final match = RegExp(
      r'''manifest":\[\d+,"((?:https?:)?[^"]+)"\]''',
    ).firstMatch(clean);
    if (match == null) return null;
    var raw = match.group(1)!.replaceAll(r'\', '').trim();
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) {
      final origin = Uri.tryParse(playerUrl)?.origin;
      return '${origin ?? baseUrl}$raw';
    }
    return raw.startsWith('http') ? raw : null;
  }

  /// Server player pages, preferring the real player over the ad wrapper.
  static List<String> playerUrls(String body) {
    final urls = <String>[];
    for (final entry in resultList(body, key: 'servers')) {
      if (entry is! Map) continue;
      var src = (entry['src'] ?? '').toString().trim();
      if (src.isEmpty) continue;
      src = src.replaceFirst('/cat-player/vast', '/cat-player/player');
      if (src.startsWith('//')) src = 'https:$src';
      if (src.startsWith('/')) src = '$baseUrl$src';
      if (!src.startsWith('http')) continue;
      if (!urls.contains(src)) urls.add(src);
    }
    return urls;
  }

  Future<http.Response?> _get(Uri uri, {String? referer}) async {
    try {
      return await _client
          .get(
            uri,
            headers: {
              'User-Agent': _ua,
              'Accept': 'application/json, text/plain, */*',
              'Referer': referer ?? '$baseUrl/',
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
    try {
      final response = await _client
          .post(
            searchUri(),
            headers: {
              'User-Agent': _ua,
              'Accept': 'application/json, text/plain, */*',
              'Content-Type': 'application/json',
              'Referer':
                  '$baseUrl/search?q=${Uri.encodeQueryComponent(trimmed)}',
            },
            body: jsonEncode({'page': 1, 'query': trimmed}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      return parseShows(response.body);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final response = await _get(trendingUri(page));
    if (response == null || response.statusCode != 200) return const [];
    return parseShows(response.body);
  }

  /// Collects up to [maxPages] episode pages; long shows paginate.
  Future<List<KickAssAnimeEpisode>> _episodes(String slug) async {
    final all = <KickAssAnimeEpisode>[];
    final seen = <String>{};
    for (var page = 1; page <= 3; page++) {
      final response = await _get(episodesUri(slug, page: page));
      if (response == null || response.statusCode != 200) break;
      final batch = parseEpisodes(response.body);
      if (batch.isEmpty) break;
      for (final episode in batch) {
        if (seen.add('${episode.number}:${episode.slug}')) all.add(episode);
      }
    }
    return all;
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final response = await _get(showUri(id));
    if (response == null || response.statusCode != 200) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      return null;
    }
    final show = decoded is Map ? decoded : const <String, dynamic>{};
    final episodes = await _episodes(id);

    return MediaDetails(
      id: id,
      title: ((show['title_en'] ?? show['title']) ?? '').toString(),
      mediaType: MediaType.series,
      description: (show['synopsis'] ?? '').toString(),
      posterUrl: posterUrl(show['poster']),
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: episodes.length,
          episodes: [
            for (final episode in episodes)
              Episode(
                season: 1,
                episode: int.tryParse(episode.number) ?? 1,
                title: 'Episode ${episode.number}',
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
    final slug = subjectId.trim();
    if (slug.isEmpty) return const [];

    final episodes = await _episodes(slug);
    if (episodes.isEmpty) return const [];

    final wanted = '${episode ?? 1}';
    final match = episodes.firstWhere(
      (entry) => entry.number == wanted,
      orElse: () => episodes.first,
    );

    final servers = await _get(episodeUri(slug, match.number, match.slug));
    if (servers == null || servers.statusCode != 200) return const [];

    final results = <StreamSource>[];
    // Both player pages are independent; fetching them one after the other
    // doubled this stage's latency for no benefit.
    final candidates = playerUrls(servers.body).take(2).toList();
    final players = await Future.wait(
      candidates.map(
        (playerUrl) => _get(Uri.parse(playerUrl), referer: '$baseUrl/'),
      ),
    );
    for (var index = 0; index < candidates.length; index++) {
      final playerUrl = candidates[index];
      final player = players[index];
      if (player == null || player.statusCode != 200) continue;
      final manifest = parseManifest(player.body, playerUrl);
      if (manifest == null) continue;
      final origin = Uri.tryParse(playerUrl)?.origin ?? baseUrl;
      results.add(
        StreamSource(
          quality: 'Auto',
          resolution: '',
          format: manifest.contains('.m3u8') ? 'HLS' : 'MP4',
          url: manifest,
          headers: {'User-Agent': _ua, 'Origin': origin, 'Referer': playerUrl},
          server: Uri.tryParse(playerUrl)?.host ?? 'KickAssAnime',
          providerId: 'kickassanime',
          providerName: name,
        ),
      );
    }
    return results;
  }
}

/// One episode entry from KAA's episodes payload.
class KickAssAnimeEpisode {
  const KickAssAnimeEpisode({required this.number, required this.slug});

  final String number;
  final String slug;
}
