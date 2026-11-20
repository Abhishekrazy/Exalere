import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// Castle TV — ported from Vega's `castle` provider.
///
/// The film backend (`api.hlowb.com`) encrypts every response. A security key is
/// fetched once (`/v0.1/system/getSecurityKey/1`), expanded to an AES-128 key by
/// appending `T!BgJB` to its base64-decoded bytes, and used as both key and IV
/// for AES-128-CBC/PKCS7. Home rows, search, details and the play URL all come
/// through that envelope.
class CastleProvider extends MediaProviderPlugin {
  CastleProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://api.hlowb.com';
  static const String _ua = 'okhttp/4.9.0';
  static const String channel = 'IndiaA';
  static const String clientType = '1';
  static const String lang = 'en-US';
  static const String mode = '1';
  static const String packageName = 'com.external.castle';
  static const String locationId = '1001';
  static const String apkSignKey = 'ED0955EB04E67A1D9F3305B95454FED485261475';
  static const String androidVersion = '13';
  static const String appMarket = 'GuanWang';

  /// Key suffix; the derived key is base64(key) + these bytes, cut to 16.
  static const String keySuffix = 'T!BgJB';

  /// Movie types that are series rather than single films.
  static const Set<String> seriesTypes = {'1', '3', '5'};

  Uint8List? _key;
  DateTime? _keyAt;

  @override
  String get id => 'castle';

  @override
  String get name => providerNameOverride ?? 'Castle TV';

  @override
  int get priority => 54;

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
    ProviderCatalogRow(id: 'trending', title: 'Trending on Castle TV'),
  ];

  static Uri homeUri({int page = 1, int size = 30}) => Uri.parse(
    '$baseUrl/film-api/v0.1/category/home?channel=$channel&clientType=$clientType'
    '&clientType=$clientType&lang=$lang&locationId=$locationId&mode=$mode'
    '&packageName=$packageName&page=$page&size=$size',
  );

  static Uri searchUri(String query, {int page = 1, int size = 30}) =>
      Uri.parse(
        '$baseUrl/film-api/v1.1.0/movie/searchByKeyword?channel=$channel'
        '&clientType=$clientType&clientType=$clientType'
        '&keyword=${Uri.encodeQueryComponent(query)}&lang=$lang&mode=$mode'
        '&packageName=$packageName&page=$page&size=$size',
      );

  static Uri detailUri(String movieId) => Uri.parse(
    '$baseUrl/film-api/v1.9.9/movie?channel=$channel&clientType=$clientType'
    '&clientType=$clientType&lang=$lang&movieId=$movieId&packageName=$packageName',
  );

  static Uri videoUri() => Uri.parse(
    '$baseUrl/film-api/v2.0.1/movie/getVideo2?clientType=$clientType'
    '&packageName=$packageName&channel=$channel&lang=$lang',
  );

  static Uri keyUri() => Uri.parse(
    '$baseUrl/v0.1/system/getSecurityKey/1?channel=$channel'
    '&clientType=$clientType&lang=$lang',
  );

  /// AES-128 key from the security key: base64 bytes first, then the suffix.
  static Uint8List deriveKey(String securityKeyBase64) {
    final decoded = base64Decode(securityKeyBase64);
    final suffix = utf8.encode(keySuffix);
    final key = Uint8List(16);
    var index = 0;
    for (var i = 0; i < decoded.length && index < 16; i++) {
      key[index++] = decoded[i];
    }
    for (var i = 0; i < suffix.length && index < 16; i++) {
      key[index++] = suffix[i];
    }
    return key;
  }

  /// Quotes bare numeric ids so 17-digit ids survive a round trip.
  static String quoteIds(String json) => json.replaceAllMapped(
    RegExp(r'"([A-Za-z0-9_]*Id|id)"\s*:\s*(-?\d+)'),
    (match) => '"${match.group(1)}":"${match.group(2)}"',
  );

  static dynamic decodeJson(String text) {
    final trimmed = text.trim();
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      try {
        return jsonDecode(quoteIds(trimmed));
      } catch (_) {
        return null;
      }
    }
  }

  /// One row's items from a home payload.
  static List<dynamic> rowsFrom(dynamic envelope) {
    final outer = envelope is Map ? envelope['data'] : null;
    if (outer is! Map) return const [];
    final rows = outer['rows'];
    return rows is List ? rows : const [];
  }

  /// Items inside a row (`contents`).
  static List<dynamic> contentsFrom(dynamic row) {
    if (row is! Map) return const [];
    final contents = row['contents'];
    return contents is List ? contents : const [];
  }

  static List<MediaItem> parseItems(Iterable<dynamic> items) {
    final result = <MediaItem>[];
    final seen = <String>{};
    for (final entry in items) {
      if (entry is! Map) continue;
      final id = (entry['redirectId'] ?? entry['id'] ?? '').toString();
      final title = (entry['title'] ?? entry['name'] ?? '').toString().trim();
      if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
      final poster =
          (entry['coverVerticalImage'] ??
                  entry['coverHorizontalImage'] ??
                  entry['coverImage'] ??
                  '')
              .toString();
      final isSeries = seriesTypes.contains('${entry['movieType']}');
      result.add(
        MediaItem(
          id: id,
          title: title,
          mediaType: isSeries ? MediaType.series : MediaType.movie,
          posterUrl: poster.isEmpty ? null : poster,
          providerId: 'castle',
        ),
      );
    }
    return result;
  }

  /// Search answers `{data:{data:[items]}}` or `{data:{rows:[…]}}`.
  static List<MediaItem> parseSearch(dynamic envelope) {
    final outer = envelope is Map ? envelope['data'] : null;
    if (outer is! Map) return const [];
    final inner = outer['data'];
    if (inner is List) return parseItems(inner);
    if (inner is Map) {
      final nested = inner['data'];
      if (nested is List) return parseItems(nested);
    }
    final rows = outer['rows'];
    if (rows is List) {
      return parseItems(rows.expand(contentsFrom));
    }
    final movies = outer['movies'];
    if (movies is List) return parseItems(movies);
    return const [];
  }

  /// Detail payload → title/poster/episodes with their resolutions.
  static CastleDetails? parseDetails(dynamic envelope) {
    final outer = envelope is Map ? envelope['data'] : null;
    if (outer is! Map) return null;
    final inner = outer['data'];
    final details = inner is Map ? inner : outer;
    final episodes = details['episodes'];
    if (episodes is! List) return null;

    final parsed = <CastleEpisode>[];
    for (final entry in episodes) {
      if (entry is! Map) continue;
      final episodeId = (entry['id'] ?? '').toString();
      if (episodeId.isEmpty) continue;
      final videos = entry['videos'];
      final resolutions = <String>[];
      if (videos is List) {
        for (final video in videos) {
          if (video is! Map) continue;
          final resolution = (video['resolution'] ?? '').toString();
          if (resolution.isNotEmpty && !resolutions.contains(resolution)) {
            resolutions.add(resolution);
          }
        }
      }
      parsed.add(
        CastleEpisode(
          id: episodeId,
          title: (entry['title'] ?? '').toString(),
          number: (entry['number'] is num)
              ? (entry['number'] as num).toInt()
              : parsed.length + 1,
          resolutions: resolutions,
        ),
      );
    }
    if (parsed.isEmpty) return null;
    return CastleDetails(
      title: (details['title'] ?? '').toString(),
      posterUrl:
          (details['coverVerticalImage'] ??
                  details['coverHorizontalImage'] ??
                  details['coverImage'] ??
                  '')
              .toString(),
      description:
          (details['briefIntroduction'] ?? details['description'] ?? '')
              .toString(),
      episodes: parsed,
    );
  }

  /// Playback URL from a getVideo2 envelope.
  static String? parseVideoUrl(dynamic envelope) {
    final outer = envelope is Map ? envelope['data'] : null;
    if (outer is! Map) return null;
    final inner = outer['data'];
    for (final candidate in [outer, if (inner is Map) inner]) {
      final url = (candidate['videoUrl'] ?? '').toString().trim();
      if (url.startsWith('http')) return url;
    }
    return null;
  }

  Future<Uint8List?> _securityKey() async {
    final cached = _key;
    final cachedAt = _keyAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt).inMinutes < 5) {
      return cached;
    }
    try {
      final response = await _client
          .get(keyUri(), headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = decodeJson(response.body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is! String || data.isEmpty) return null;
      final key = deriveKey(data);
      _key = key;
      _keyAt = DateTime.now();
      return key;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _decryptBody(String body, Uint8List key) async {
    final direct = decodeJson(body);
    if (direct is Map) {
      final data = direct['data'];
      if (data is Map) return direct;
      if (data is String && data.isNotEmpty) {
        final plain = await _decryptCbc(data, key);
        return plain == null ? null : decodeJson(plain);
      }
    }

    final cipher = body.trim().replaceAll(RegExp(r'^"|"$'), '');
    final plain = await _decryptCbc(cipher, key);
    return plain == null ? null : decodeJson(plain);
  }

  /// AES-128-CBC with the derived key as both key and IV, PKCS7 padding.
  Future<String?> _decryptCbc(String cipherBase64, Uint8List key) async {
    try {
      final cipherText = base64Decode(cipherBase64);
      final algorithm = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
      final box = SecretBox(cipherText, nonce: key, mac: Mac.empty);
      final clear = await algorithm.decrypt(box, secretKey: SecretKey(key));
      return utf8.decode(clear, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Exposes CBC decryption to tests (the envelope path needs the network).
  Future<String?> decryptForTest(String cipherBase64, Uint8List key) =>
      _decryptCbc(cipherBase64, key);

  Future<dynamic> _getEnvelope(Uri uri) async {
    final key = await _securityKey();
    if (key == null) return null;
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return null;
      return await _decryptBody(response.body, key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final envelope = await _getEnvelope(searchUri(trimmed));
    if (envelope == null) return const [];
    return parseSearch(envelope);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final envelope = await _getEnvelope(homeUri(page: page));
    if (envelope == null) return const [];
    final items = <MediaItem>[];
    for (final row in rowsFrom(envelope)) {
      items.addAll(parseItems(contentsFrom(row)));
      if (items.length >= 60) break;
    }
    return items;
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final envelope = await _getEnvelope(detailUri(id));
    if (envelope == null) return null;
    final details = parseDetails(envelope);
    if (details == null) return null;

    return MediaDetails(
      id: id,
      title: details.title,
      mediaType: details.episodes.length > 1
          ? MediaType.series
          : MediaType.movie,
      description: details.description,
      posterUrl: details.posterUrl,
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: details.episodes.length,
          episodes: [
            for (final episode in details.episodes)
              Episode(
                season: 1,
                episode: episode.number,
                title: episode.title.isEmpty
                    ? 'Episode ${episode.number}'
                    : episode.title,
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
    final movieId = target;
    if (movieId.isEmpty) return const [];

    final detailEnvelope = await _getEnvelope(detailUri(movieId));
    if (detailEnvelope == null) return const [];
    final details = parseDetails(detailEnvelope);
    if (details == null) return const [];

    final wantedEpisode = episode ?? 1;
    final match = details.episodes.firstWhere(
      (entry) => entry.number == wantedEpisode,
      orElse: () => details.episodes.first,
    );

    final key = await _securityKey();
    if (key == null) return const [];

    final results = <StreamSource>[];
    final resolutions = match.resolutions.isEmpty
        ? const ['3', '2', '1']
        : match.resolutions;
    for (final resolution in resolutions.take(2)) {
      final body = jsonEncode({
        'mode': mode,
        'appMarket': appMarket,
        'clientType': clientType,
        'woolUser': 'false',
        'apkSignKey': apkSignKey,
        'androidVersion': androidVersion,
        'movieId': movieId,
        'episodeId': match.id,
        'isNewUser': 'true',
        'resolution': resolution,
        'packageName': packageName,
      });
      try {
        final response = await _client
            .post(
              videoUri(),
              headers: {
                'User-Agent': _ua,
                'Content-Type': 'application/json; charset=utf-8',
              },
              body: body,
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode != 200) continue;
        final envelope = await _decryptBody(response.body, key);
        final url = parseVideoUrl(envelope);
        if (url == null) continue;
        results.add(
          StreamSource(
            quality: switch (resolution) {
              '3' => '1080p',
              '2' => '720p',
              '1' => '480p',
              _ => 'Auto',
            },
            resolution: '',
            format: url.contains('.m3u8') ? 'HLS' : 'MP4',
            url: url,
            headers: const {'User-Agent': _ua, 'Referer': '$baseUrl/'},
            server: 'Castle TV',
            providerId: 'castle',
            providerName: name,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return results;
  }
}

/// Parsed detail payload.
class CastleDetails {
  const CastleDetails({
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.episodes,
  });

  final String title;
  final String posterUrl;
  final String description;
  final List<CastleEpisode> episodes;
}

/// One episode with the resolutions it offers.
class CastleEpisode {
  const CastleEpisode({
    required this.id,
    required this.title,
    required this.number,
    required this.resolutions,
  });

  final String id;
  final String title;
  final int number;
  final List<String> resolutions;
}
