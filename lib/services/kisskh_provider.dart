import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// KissKh — Asian dramas and movies, ported from Vega's `kissKh` provider.
///
/// The site's player API (`/api/DramaList/Episode/<id>.png`) refuses requests
/// without a `kkey`. That key is the hex of AES-128-CBC over a fixed pipe-joined
/// string (episode id, app version, guid, platform, app name) with the site's
/// built-in key/IV and PKCS7 padding — no server round-trip and no captcha.
/// `generateKey` reproduces it byte-for-byte; the test suite pins it against
/// vectors produced from Vega's original implementation.
class KissKhProvider extends MediaProviderPlugin {
  KissKhProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://kisskh.is';

  /// Key material baked into the web bundle (Vega ships the same defaults and
  /// refreshes them from `runtime.*.js` when the site rotates them).
  static const String viGuid = '62f176f3bb1b5b8e70e39932ad34a0c7';
  static const String appVer = '2.8.10';
  static const int platformVer = 4830201;
  static const String appName = 'kisskh';

  /// First four AES round keys, big-endian: the AES-128 key itself.
  static final Uint8List _aesKey = Uint8List.fromList([
    0x4f, 0x6b, 0xda, 0xa3, 0x9e, 0x2f, 0x8c, 0xb0, //
    0x7f, 0x5e, 0x72, 0x2d, 0x9e, 0xde, 0xf3, 0x14,
  ]);

  /// Fixed IV of the first encrypted block; later blocks chain the previous
  /// ciphertext block, which is CBC.
  static final Uint8List _iv = Uint8List.fromList([
    0x01, 0x50, 0x4a, 0xf3, 0x56, 0xe6, 0x19, 0xcf, //
    0x2e, 0x42, 0xbb, 0xa6, 0x8c, 0x3f, 0x70, 0xf9,
  ]);

  @override
  String get id => 'kisskh';

  @override
  String get name => providerNameOverride ?? 'KissKh';

  @override
  int get priority => 55;

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
    ProviderCatalogRow(id: 'dramas', title: 'KissKh dramas'),
  ];

  /// JavaScript's 32-bit string hash (`hash = hash*31 + code`), returned as the
  /// signed decimal string the site interpolates into the key input.
  static String stringHash(String value) {
    // JavaScript evaluates `(hash << 5) - hash + code` as: int32 wrap of the
    // shift, then ordinary double arithmetic. The accumulator therefore leaves
    // the 32-bit range and must not be masked after the addition.
    var hash = 0;
    for (final code in value.codeUnits) {
      var shifted = (hash & 0xFFFFFFFF) << 5;
      shifted &= 0xFFFFFFFF;
      if (shifted >= 0x80000000) shifted -= 0x100000000;
      hash = shifted - hash + code;
    }
    return hash.toString();
  }

  static String _substr48(String value) =>
      value.length <= 48 ? value : value.substring(0, 48);

  /// The `kkey` query parameter for one episode.
  static Future<String> generateKey({
    required int episodeId,
    String guid = viGuid,
    String version = appVer,
    int platform = platformVer,
    String app = appName,
  }) async {
    final parts = <String>[
      '',
      episodeId.toString(),
      '', // the original joins a null here, which stringifies to ""
      'mg3c3b04ba',
      version,
      guid,
      platform.toString(),
      _substr48(app),
      _substr48(app.toLowerCase()),
      _substr48(app),
      app,
      app,
      app,
      '00',
      '',
    ];

    final initialJoin = parts.join('|');
    parts.insert(1, stringHash(initialJoin));

    final cipher = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
    final box = await cipher.encrypt(
      Uint8List.fromList(utf8.encode(parts.join('|'))),
      secretKey: SecretKey(_aesKey),
      nonce: _iv,
    );
    return box.cipherText
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static Uri searchUri(String query) => Uri.parse(
    '$baseUrl/api/DramaList/Search?q=${Uri.encodeQueryComponent(query)}&type=0',
  );

  static Uri catalogUri({int page = 1}) => Uri.parse(
    '$baseUrl/api/DramaList/List?type=0&sub=0&country=0&status=0&order=2'
    '&page=$page',
  );

  static Uri dramaUri(String id) =>
      Uri.parse('$baseUrl/api/DramaList/Drama/$id?isq=false');

  static Uri streamUri(int episodeId, String key) => Uri.parse(
    '$baseUrl/api/DramaList/Episode/$episodeId.png'
    '?err=false&ts=null&time=null&kkey=$key',
  );

  /// Search / list payload → media items (both endpoints share the shape).
  static List<MediaItem> parseShows(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    // Search answers a bare list; the drama list answers `{page, data:[…]}`.
    final List<dynamic> shows;
    if (decoded is List) {
      shows = decoded;
    } else if (decoded is Map && decoded['data'] is List) {
      shows = decoded['data'] as List<dynamic>;
    } else {
      return const [];
    }

    final items = <MediaItem>[];
    final seen = <String>{};
    for (final show in shows) {
      if (show is! Map) continue;
      final id = (show['id'] ?? '').toString();
      final title = (show['title'] ?? '').toString().trim();
      if (id.isEmpty || title.isEmpty || !seen.add(id)) continue;
      final thumb = (show['thumbnail'] ?? '').toString();
      items.add(
        MediaItem(
          id: id,
          title: title,
          mediaType: MediaType.series,
          posterUrl: thumb.isEmpty ? null : thumb,
          providerId: 'kisskh',
        ),
      );
    }
    return items;
  }

  /// Drama detail payload → episodes with their KissKh ids.
  static List<KissKhEpisode> parseEpisodes(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];
    final raw = decoded['episodes'];
    if (raw is! List) return const [];

    final episodes = <KissKhEpisode>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['id'];
      if (id is! num) continue;
      final number = entry['number'];
      episodes.add(
        KissKhEpisode(
          id: id.toInt(),
          number: number is num ? number.toInt() : episodes.length + 1,
        ),
      );
    }
    return episodes;
  }

  static String? parseVideoUrl(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final url = (decoded['Video'] ?? '').toString().trim();
    return url.startsWith('http') ? url : null;
  }

  Future<http.Response?> _get(Uri uri) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/131.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/plain, */*',
              'Referer': '$baseUrl/',
              'Origin': baseUrl,
            },
          )
          .timeout(const Duration(seconds: 20));
      return response;
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
    return parseShows(response.body);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final response = await _get(catalogUri(page: page));
    if (response == null || response.statusCode != 200) return const [];
    return parseShows(response.body);
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final response = await _get(dramaUri(id));
    if (response == null || response.statusCode != 200) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final episodes = parseEpisodes(response.body);
    return MediaDetails(
      id: id,
      title: (decoded['title'] ?? '').toString().trim(),
      mediaType: MediaType.series,
      description: (decoded['description'] ?? '').toString().trim(),
      posterUrl: (decoded['thumbnail'] ?? '').toString(),
      genres: const [],
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: episodes.length,
          episodes: [
            for (final episode in episodes)
              Episode(
                season: 1,
                episode: episode.number,
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
    final dramaId = target;
    if (dramaId.isEmpty) return const [];

    final detail = await _get(dramaUri(dramaId));
    if (detail == null || detail.statusCode != 200) return const [];
    final episodes = parseEpisodes(detail.body);
    if (episodes.isEmpty) return const [];

    final wanted = episode ?? 1;
    final match = episodes.firstWhere(
      (entry) => entry.number == wanted,
      orElse: () => episodes.first,
    );

    final key = await generateKey(episodeId: match.id);
    final response = await _get(streamUri(match.id, key));
    if (response == null || response.statusCode != 200) return const [];
    final video = parseVideoUrl(response.body);
    if (video == null) return const [];

    return [
      StreamSource(
        quality: 'Auto',
        resolution: '',
        format: video.contains('.m3u8') ? 'HLS' : 'MP4',
        url: video,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/131.0.0.0 Safari/537.36',
          'Referer': '$baseUrl/',
          'Origin': baseUrl,
        },
        server: 'KissKh',
        providerId: 'kisskh',
        providerName: name,
      ),
    ];
  }
}

/// One episode id + display number from a KissKh drama payload.
class KissKhEpisode {
  const KissKhEpisode({required this.id, required this.number});

  final int id;
  final int number;
}
