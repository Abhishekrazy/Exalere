import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../models/exalere_plugin.dart';
import 'media_provider_plugin.dart';
import 'tmdb_service.dart';

/// Adapter that exposes a remote Exalere / Stremio-protocol plugin as a native
/// [MediaProviderPlugin].
///
/// Implements the three endpoints the protocol defines for a browsable source:
/// `/catalog/` for discovery rows, `/meta/` for details and episode lists, and
/// `/stream/` for playable links. Supporting catalogs is what lets a community
/// addon power the home screen directly, so every row it serves is playable
/// instead of being metadata the app cannot resolve.
class ExalerePluginAdapter extends MediaProviderPlugin {
  final ExalerePluginConfig config;
  final http.Client _client;

  ExalerePluginAdapter({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  /// Stremio catalogs do not advertise a page size; 100 is the de-facto value.
  static const int _catalogPageSize = 100;

  static const Duration _requestTimeout = Duration(seconds: 12);

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  int get priority => 20; // User-installed plugins take priority over legacy defaults

  @override
  bool get isEnabled => config.isEnabled;

  @override
  bool get supportsMovies => config.manifest?.supportsMovies ?? true;

  @override
  bool get supportsSeries => config.manifest?.supportsSeries ?? true;

  /// Metadata-only addons (e.g. Cinemeta) must never be treated as stream
  /// sources, otherwise a metadata match would be mistaken for watchability.
  @override
  bool get supportsStreams => config.manifest?.supportsStreams ?? true;

  /// Thousands of community addons declare a catalog resource but never
  /// implement search. Advertising search is harmless there — the request
  /// simply returns nothing — while it lets the availability checker use the
  /// cheap index lookup for addons that do support it.
  @override
  bool get supportsSearch => _catalogs.isNotEmpty;

  @override
  bool get supportsCatalogFeeds => _catalogs.isNotEmpty;

  List<ExalerePluginCatalog> get _catalogs =>
      config.manifest?.catalogs ?? const <ExalerePluginCatalog>[];

  @override
  Future<void> init() async {
    // Initialized from config
  }

  String get _baseUrl => _cleanBaseUrl(config.baseUrl);

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  /// Picks the catalog descriptor that best matches Exalere's shelf categories.
  ExalerePluginCatalog? _selectCatalog(String? category) {
    if (_catalogs.isEmpty) return null;

    bool isSeriesCatalog(ExalerePluginCatalog c) =>
        c.type == 'series' || c.type == 'tv' || c.type == 'anime';

    switch (category) {
      case 'movies':
        for (final c in _catalogs) {
          if (!isSeriesCatalog(c)) return c;
        }
        break;
      case 'series':
        for (final c in _catalogs) {
          if (isSeriesCatalog(c)) return c;
        }
        break;
      case 'featured':
        return _catalogs.first;
    }
    return _catalogs.first;
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    if (!isEnabled) return [];

    final catalog = _selectCatalog(category);
    if (catalog == null) return [];

    final skip = page > 1 ? (page - 1) * _catalogPageSize : 0;
    final uri = Uri.parse(
      '$_baseUrl/catalog/${catalog.type}/${catalog.id}.json',
    ).replace(queryParameters: skip > 0 ? {'skip': '$skip'} : null);

    final metas = await _fetchMetas(uri, fallbackType: catalog.type);
    return _metasToItems(metas, catalog.type);
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    if (!isEnabled) return [];
    final trimmed = query.trim();
    if (trimmed.isEmpty || _catalogs.isEmpty) return [];

    // Limit fan-out: most addons expose several catalogs but only one or two
    // are worth searching.
    final targets = _catalogs.take(3).toList(growable: false);

    final results = await Future.wait(
      targets.map((catalog) async {
        final uri = Uri.parse(
          '$_baseUrl/catalog/${catalog.type}/${catalog.id}/'
          'search=${Uri.encodeComponent(trimmed)}.json',
        );
        final metas = await _fetchMetas(uri, fallbackType: catalog.type);
        return _metasToItems(metas, catalog.type);
      }),
    );

    final merged = <MediaItem>[];
    final seen = <String>{};
    for (final list in results) {
      for (final item in list) {
        if (seen.add(item.id)) merged.add(item);
      }
    }
    return merged;
  }

  // ---------------------------------------------------------------------------
  // Metadata
  // ---------------------------------------------------------------------------

  @override
  Future<MediaDetails?> getDetails(String id) async {
    if (!isEnabled || id.trim().isEmpty) return null;

    // The protocol does not encode the media type in a bare id, so try the
    // series form first when the addon only serves series.
    final preferSeries =
        _catalogs.isNotEmpty && _catalogs.every((c) => c.type == 'series');
    final types = preferSeries
        ? const ['series', 'movie']
        : const ['movie', 'series'];

    for (final type in types) {
      final uri = Uri.parse(
        '$_baseUrl/meta/$type/${Uri.encodeComponent(id)}.json',
      );
      final meta = await _fetchMeta(uri);
      if (meta == null) continue;
      return _metaToDetails(meta, type);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

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
    if (!isEnabled) return [];

    final effectiveIsSeries = isSeries ?? (season != null && season > 0);

    final contentId = await _resolveContentId(
      subjectId: subjectId,
      imdbId: imdbId,
      title: title,
      year: year,
      isSeries: effectiveIsSeries,
    );

    if (contentId == null) {
      debugPrint(
        '[ExalerePluginAdapter] ${config.name} cannot address "$subjectId": '
        'no id accepted by this addon was resolved.',
      );
      return [];
    }

    final type = effectiveIsSeries ? 'series' : 'movie';
    final queryId = effectiveIsSeries && season != null
        ? '$contentId:$season:${episode ?? 1}'
        : contentId;
    final streamUrl = Uri.parse('$_baseUrl/stream/$type/$queryId.json');

    try {
      debugPrint(
        '[ExalerePluginAdapter] Querying ${config.name} at: $streamUrl',
      );
      final response = await _client
          .get(
            streamUrl,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Exalere-Plugin-Client)',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[ExalerePluginAdapter] ${config.name} returned HTTP ${response.statusCode}',
        );
        return [];
      }

      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawStreams = data['streams'] as List<dynamic>? ?? const [];

      final streams = <StreamSource>[];
      for (final raw in rawStreams) {
        if (raw is Map<String, dynamic>) {
          try {
            final stream = ExalerePluginStream.fromJson(raw);
            if (stream.url.isNotEmpty &&
                (stream.url.startsWith('http://') ||
                    stream.url.startsWith('https://') ||
                    stream.url.startsWith('magnet:')) &&
                !stream.url.contains('youtube.com/watch') &&
                !stream.url.contains('youtu.be/')) {
              streams.add(
                stream.toStreamSource(
                  fallbackName: config.name,
                  providerId: config.id,
                ),
              );
            }
          } catch (e) {
            debugPrint('[ExalerePluginAdapter] Error parsing stream item: $e');
          }
        }
      }

      debugPrint(
        '[ExalerePluginAdapter] Resolved ${streams.length} stream(s) from ${config.name}',
      );
      return streams;
    } on TimeoutException {
      debugPrint(
        '[ExalerePluginAdapter] Timeout querying ${config.name} ($streamUrl)',
      );
      return [];
    } catch (e) {
      debugPrint('[ExalerePluginAdapter] Error querying ${config.name}: $e');
      return [];
    }
  }

  /// Resolves an id the addon will accept for [subjectId].
  ///
  /// Stremio addons key their content by IMDb id (`tt1234567`). Exalere catalog
  /// items often carry a TMDB numeric id instead, so a numeric id is upgraded to
  /// an IMDb id through TMDB enrichment before being used as a last resort.
  Future<String?> _resolveContentId({
    required String subjectId,
    String? imdbId,
    String? title,
    String? year,
    required bool isSeries,
  }) async {
    final prefixes = config.manifest?.idPrefixes ?? const <String>[];
    bool accepts(String value) {
      if (value.isEmpty) return false;
      if (prefixes.isEmpty) return true;
      final lower = value.toLowerCase();
      return prefixes.any((p) => lower.startsWith(p.toLowerCase()));
    }

    // 1. Any IMDb id already in hand is exactly what the protocol wants.
    if (subjectId.startsWith('tt') && accepts(subjectId)) return subjectId;
    if (imdbId != null && imdbId.startsWith('tt') && accepts(imdbId)) {
      return imdbId;
    }

    // 2. A non-numeric slug (e.g. `kitsu:1234`) is already addon-native.
    final numeric = int.tryParse(subjectId.trim());
    if (numeric == null && accepts(subjectId)) return subjectId;

    // 3. Upgrade a numeric/TMDB id to an IMDb id before falling back to it,
    //    because addons such as Torrentio only understand `tt` ids.
    if (title != null && title.trim().isNotEmpty) {
      try {
        final tmdb = await TmdbService().getEnrichedDetails(
          title: title,
          year: year,
          isSeries: isSeries,
          tmdbId: numeric,
        );
        final resolved = tmdb?.imdbId;
        if (resolved != null &&
            resolved.startsWith('tt') &&
            accepts(resolved)) {
          return resolved;
        }
      } catch (e) {
        debugPrint(
          '[ExalerePluginAdapter] TMDB id resolution failed for "$title": $e',
        );
      }
    }

    // 4. Last resort: whatever we were given, if the addon will take it.
    return accepts(subjectId) ? subjectId : null;
  }

  // ---------------------------------------------------------------------------
  // Subtitles
  // ---------------------------------------------------------------------------

  @override
  bool get supportsSubtitles =>
      config.manifest?.resources.contains('subtitles') ?? false;

  @override
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    if (!isEnabled || !supportsSubtitles) return [];

    final effectiveIsSeries = season != null && season > 0;
    final contentId = await _resolveContentId(
      subjectId: resourceId?.isNotEmpty == true ? resourceId! : subjectId,
      imdbId: imdbId,
      title: title,
      year: year,
      isSeries: effectiveIsSeries,
    );
    if (contentId == null) return [];

    final type = effectiveIsSeries ? 'series' : 'movie';
    final queryId = effectiveIsSeries
        ? '$contentId:$season:${episode ?? 1}'
        : contentId;
    final uri = Uri.parse('$_baseUrl/subtitles/$type/$queryId.json');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Exalere-Plugin-Client)',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return [];

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return [];
      final rawSubs = decoded['subtitles'];
      if (rawSubs is! List) return [];

      final subtitles = <SubtitleOption>[];
      for (final raw in rawSubs) {
        if (raw is! Map) continue;
        final url = raw['url']?.toString() ?? '';
        if (url.isEmpty) continue;
        final lang = raw['lang']?.toString() ?? 'en';
        subtitles.add(
          SubtitleOption(
            language: lang,
            name: raw['name']?.toString() ?? lang.toUpperCase(),
            url: url,
          ),
        );
      }
      debugPrint(
        '[ExalerePluginAdapter] ${subtitles.length} subtitle(s) from ${config.name}',
      );
      return subtitles;
    } catch (e) {
      debugPrint('[ExalerePluginAdapter] ${config.name} subtitles error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP + parsing helpers
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> _fetchMetas(
    Uri uri, {
    required String fallbackType,
  }) async {
    try {
      debugPrint('[ExalerePluginAdapter] ${config.name} catalog: $uri');
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Exalere-Plugin-Client)',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[ExalerePluginAdapter] ${config.name} catalog HTTP ${response.statusCode}',
        );
        return const [];
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return const [];
      final metas = decoded['metas'];
      if (metas is! List) return const [];
      return metas;
    } on TimeoutException {
      debugPrint('[ExalerePluginAdapter] ${config.name} catalog timeout: $uri');
      return const [];
    } catch (e) {
      debugPrint('[ExalerePluginAdapter] ${config.name} catalog error: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> _fetchMeta(Uri uri) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Exalere-Plugin-Client)',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return null;
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final meta = decoded['meta'];
      return meta is Map<String, dynamic> ? meta : null;
    } catch (e) {
      debugPrint('[ExalerePluginAdapter] ${config.name} meta error: $e');
      return null;
    }
  }

  List<MediaItem> _metasToItems(List<dynamic> metas, String fallbackType) {
    final items = <MediaItem>[];
    for (final raw in metas) {
      if (raw is! Map) continue;
      final item = _metaToItem(Map<String, dynamic>.from(raw), fallbackType);
      if (item != null) items.add(item);
    }
    return items;
  }

  MediaItem? _metaToItem(Map<String, dynamic> meta, String fallbackType) {
    final id = meta['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final type = meta['type']?.toString() ?? fallbackType;
    final isSeries = type == 'series' || type == 'tv' || type == 'anime';

    return MediaItem(
      id: id,
      title: meta['name']?.toString() ?? id,
      mediaType: isSeries ? MediaType.series : MediaType.movie,
      year: _extractYear(meta['releaseInfo'] ?? meta['year']),
      posterUrl: MediaItem.normalizeImageUrl(meta['poster']?.toString()),
      backdropUrl: MediaItem.normalizeImageUrl(
        (meta['background'] ?? meta['backdrop'])?.toString(),
      ),
      rating: double.tryParse(meta['imdbRating']?.toString() ?? ''),
      genre: _genresToText(meta['genres'] ?? meta['genre']),
      provider: ProviderType.plugins,
      providerId: config.id,
    );
  }

  MediaDetails? _metaToDetails(Map<String, dynamic> meta, String type) {
    final id = meta['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    final isSeries = type == 'series' || type == 'tv' || type == 'anime';

    return MediaDetails(
      id: id,
      title: meta['name']?.toString() ?? id,
      mediaType: isSeries ? MediaType.series : MediaType.movie,
      year: _extractYear(meta['releaseInfo'] ?? meta['year']),
      description:
          meta['description']?.toString() ?? meta['overview']?.toString(),
      tagline: meta['tagline']?.toString(),
      imdbRating: meta['imdbRating']?.toString(),
      director: _peopleToString(meta['director']),
      stars: _peopleToString(meta['cast']),
      posterUrl: MediaItem.normalizeImageUrl(meta['poster']?.toString()),
      backdropUrl: MediaItem.normalizeImageUrl(
        (meta['background'] ?? meta['backdrop'])?.toString(),
      ),
      duration: meta['runtime']?.toString(),
      genres: _genresToList(meta['genres'] ?? meta['genre']),
      seasons: isSeries ? _seasonsFromVideos(meta['videos']) : const [],
      provider: ProviderType.plugins,
    );
  }

  List<Season> _seasonsFromVideos(dynamic videos) {
    if (videos is! List) return const [];

    final bySeason = <int, List<Episode>>{};
    for (final raw in videos) {
      if (raw is! Map) continue;
      final season = _toInt(raw['season']) ?? 1;
      final number = _toInt(raw['episode']) ?? _toInt(raw['number']) ?? 1;
      bySeason
          .putIfAbsent(season, () => <Episode>[])
          .add(
            Episode(
              season: season,
              episode: number,
              title:
                  raw['name']?.toString() ??
                  raw['title']?.toString() ??
                  'Episode $number',
              thumbnail: MediaItem.normalizeImageUrl(
                raw['thumbnail']?.toString(),
              ),
              overview:
                  raw['overview']?.toString() ?? raw['description']?.toString(),
            ),
          );
    }

    final seasons = bySeason.entries.map((entry) {
      entry.value.sort((a, b) => a.episode.compareTo(b.episode));
      return Season(
        seasonNumber: entry.key,
        episodeCount: entry.value.length,
        episodes: entry.value,
      );
    }).toList()..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    return seasons;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  /// `releaseInfo` is either a plain year or a range such as `2019-2023`.
  static String? _extractYear(dynamic releaseInfo) {
    if (releaseInfo == null) return null;
    final match = RegExp(
      r'(19\d{2}|20\d{2})',
    ).firstMatch(releaseInfo.toString());
    return match?.group(0);
  }

  static List<String> _genresToList(dynamic genres) {
    if (genres is List) {
      return genres
          .map((g) => g.toString().trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }
    if (genres is String && genres.trim().isNotEmpty) {
      return genres
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _genresToText(dynamic genres) {
    final list = _genresToList(genres);
    return list.isEmpty ? null : list.join(' • ');
  }

  static String? _peopleToString(dynamic people) {
    if (people is List && people.isNotEmpty) {
      return people.map((p) => p.toString()).join(', ');
    }
    if (people is String && people.trim().isNotEmpty) return people.trim();
    return null;
  }

  static String _cleanBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/manifest.json')) {
      cleaned = cleaned.substring(0, cleaned.length - '/manifest.json'.length);
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
