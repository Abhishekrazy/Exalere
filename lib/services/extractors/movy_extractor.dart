import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Movy (api.wecollege.net) stream extractor, ported from Vega's `movy`.
///
/// Two requests and one custom cipher: `/seed?mediaId=` returns a short-lived
/// seed, `/<server>/sources?…&seed=` returns a base64url payload encrypted with
/// a keystream derived from that seed and the media id (XOR, prefixed `mvm1`).
/// The keystream is a 32-bit mixer (FNV-1a seed hash, then a rotate/xor state
/// machine) — reproduced here byte for byte so no JS engine is needed.
class MovyExtractor {
  const MovyExtractor._();

  static const String apiBase = 'https://api.wecollege.net';
  static const String origin = 'https://www.movy.sx';

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  static const List<int> magicPrefix = [109, 118, 109, 49]; // "mvm1"

  /// Servers worth trying, in order; the first that answers wins.
  static const List<String> servers = [
    'miami',
    'boise',
    'atlanta',
    'phoenix',
    'austin',
    'tampa',
    'orlando',
    'vegas',
  ];

  static const List<int> _dConstants = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  ];

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  static int _rotR(int value, int shift) {
    final e = value & 0xFFFFFFFF;
    final a = shift & 31;
    if (a == 0) return e;
    return ((e << a) | (e >> (32 - a))) & 0xFFFFFFFF;
  }

  static int _scramble(int value) {
    var e = value & 0xFFFFFFFF;
    e ^= e >> 16;
    e = _imul(e, 0x85ebca6b);
    e ^= e >> 13;
    e = _imul(e, 0xc2b2ae35);
    e ^= e >> 16;
    return e & 0xFFFFFFFF;
  }

  /// The XOR keystream for a payload of [length] bytes.
  static Uint8List keyStream(String seed, String mediaId, int length) {
    final state = List<int?>.filled(61, null);

    var seedAcc = 0x811c9dc5;
    for (final code in seed.codeUnits) {
      seedAcc = _imul(seedAcc ^ code, 0x1000193);
    }

    var n = _scramble(
      _scramble(seedAcc) ^
          _scramble(((int.tryParse(mediaId) ?? 0) & 0xFFFFFFFF) ^ 0x9e3779b9),
    );

    for (var e = 0; e < 8; e++) {
      if (((e * (e + 1)) & 1) == 0) {
        final a = n % 61;
        n = _rotR((n + 0x9e3779b9) & 0xFFFFFFFF, 7 + (7 & e));
        state[a] = (n ^ _scramble(n)) & 0xFFFFFFFF;
        n = _scramble((n + a) & 0xFFFFFFFF);
      } else {
        state[e] = _dConstants[15 & e];
      }
    }

    var acc = _scramble(0xa5a5a5a5 ^ n);
    final stream = Uint8List(length);
    var counter = 0;
    var cursor = 0;

    while (cursor < length) {
      final sD = acc % 61;
      final present = state[sD] != null;
      final sR = state[sD] ?? 0;
      final sC = _imul(0x9e3779b9, counter + 1);
      final mixed = (sR ^ sC) & 0xFFFFFFFF;
      var sB = (acc ^ mixed) & 0xFFFFFFFF;
      if (present) {
        sB = (sB | (acc & mixed & 0xFFFFFFFF)) & 0xFFFFFFFF;
      }
      sB =
          (_rotR((sB + acc) & 0xFFFFFFFF, 31 & sD) ^
              _rotR(acc, 31 & _imul(sD, 7))) &
          0xFFFFFFFF;
      acc = _scramble((sB + 0x9e3779b9) & 0xFFFFFFFF);
      state[sD] = acc;
      counter++;

      stream[cursor++] = 255 & acc;
      if (cursor < length) stream[cursor++] = (acc >> 8) & 255;
      if (cursor < length) stream[cursor++] = (acc >> 16) & 255;
      if (cursor < length) stream[cursor++] = (acc >> 24) & 255;
    }
    return stream;
  }

  /// Decrypts a sources payload to its JSON string, or null when it is not one.
  static String? decodePayload(String ciphertext, String seed, String mediaId) {
    Uint8List raw;
    try {
      var clean = ciphertext.replaceAll('-', '+').replaceAll('_', '/');
      while (clean.length % 4 != 0) {
        clean += '=';
      }
      raw = base64Decode(clean);
    } catch (_) {
      return null;
    }
    if (raw.length < magicPrefix.length + 2) return null;

    final stream = keyStream(seed, mediaId, raw.length);
    final clear = Uint8List(raw.length);
    for (var i = 0; i < raw.length; i++) {
      clear[i] = raw[i] ^ stream[i];
    }
    for (var i = 0; i < magicPrefix.length; i++) {
      if (clear[i] != magicPrefix[i]) return null;
    }
    return utf8.decode(clear.sublist(magicPrefix.length), allowMalformed: true);
  }

  static Map<String, String> headers() => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Referer': '$origin/',
    'Origin': origin,
  };

  /// Seed for one media id; the API answers `{seed, ttlMs}`.
  static Future<String?> fetchSeed(
    String mediaId, {
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse('$apiBase/seed?mediaId=$mediaId'), headers: headers())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final seed = decoded is Map ? (decoded['seed'] ?? '').toString() : '';
      return seed.isEmpty ? null : seed;
    } catch (_) {
      return null;
    }
  }

  /// One server's payload, already decrypted to JSON text.
  static Future<String?> fetchSourcesJson({
    required String server,
    required String tmdbId,
    required String title,
    required String year,
    required String mediaType,
    required String seed,
    String? imdbId,
    int? season,
    int? episode,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final query = <String, String>{
      'title': title,
      'mediaType': mediaType,
      'year': year,
      'tmdbId': tmdbId,
      'enc': '2',
      'seed': seed,
      if (imdbId != null && imdbId.isNotEmpty) 'imdbId': imdbId,
      if (mediaType != 'movie') 'seasonId': '${season ?? 1}',
      if (mediaType != 'movie') 'episodeId': '${episode ?? 1}',
    };
    final uri = Uri.parse(
      '$apiBase/$server/sources',
    ).replace(queryParameters: query);
    try {
      final response = await httpClient
          .get(uri, headers: headers())
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return decodePayload(response.body, seed, tmdbId);
    } catch (_) {
      return null;
    }
  }

  /// First working `{playlist, subtitles}` across [servers].
  ///
  /// A seed is spent by the request that uses it, so every server gets a fresh
  /// one: firing four servers with a shared seed left whichever answered second
  /// with a 401 and lost the title. Each attempt is bounded, and the whole call
  /// stops at [budget] so a slow title cannot hold a detail page.
  static Future<MovyStream?> resolve({
    required String tmdbId,
    required String title,
    required String year,
    required String mediaType,
    String? imdbId,
    int? season,
    int? episode,
    http.Client? client,
    Duration budget = const Duration(seconds: 16),
  }) async {
    final deadline = DateTime.now().add(budget);

    for (final server in servers) {
      if (DateTime.now().isAfter(deadline)) break;

      final seed = await fetchSeed(tmdbId, client: client);
      if (seed == null) continue;

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      String? json;
      try {
        json =
            await fetchSourcesJson(
              server: server,
              tmdbId: tmdbId,
              title: title,
              year: year,
              mediaType: mediaType,
              seed: seed,
              imdbId: imdbId,
              season: season,
              episode: episode,
              client: client,
            ).timeout(
              remaining < const Duration(seconds: 6)
                  ? remaining
                  : const Duration(seconds: 6),
            );
      } catch (_) {
        json = null;
      }
      if (json == null) continue;

      final stream = _streamFromJson(json, server);
      if (stream != null) return stream;
    }
    return null;
  }

  static MovyStream? _streamFromJson(String json, String server) {
    dynamic decoded;
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final playlist = (decoded['playlist'] ?? '').toString();
    if (!playlist.startsWith('http')) return null;
    return MovyStream(
      playlist: playlist,
      server: server,
      subtitles: [
        for (final entry in (decoded['subtitles'] as List? ?? const []))
          if (entry is Map)
            MovySubtitle(
              url: (entry['url'] ?? entry['file'] ?? entry['src'] ?? '')
                  .toString(),
              language:
                  (entry['language'] ??
                          entry['lang'] ??
                          entry['label'] ??
                          entry['name'] ??
                          'en')
                      .toString(),
            ),
      ],
    );
  }
}

/// One resolved Movy playlist.
class MovyStream {
  const MovyStream({
    required this.playlist,
    required this.server,
    required this.subtitles,
  });

  final String playlist;
  final String server;
  final List<MovySubtitle> subtitles;
}

/// One subtitle track from the payload.
class MovySubtitle {
  const MovySubtitle({required this.url, required this.language});

  final String url;
  final String language;
}
