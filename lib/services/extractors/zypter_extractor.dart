import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resolves a "Zypter"/ZephyrFlick player (`ravok.buzz`, `zephyrix.org`, …).
///
/// The player page is a packed JS bundle, but its data endpoint is plain JSON:
/// `POST /player/index.php?data=<hash>&do=getVideo` with `hash=<hash>&r=<origin>`
/// answers `{videoSource, securedLink}` where `videoSource` is the signed HLS
/// playlist. No eval and no captcha.
class ZypterExtractor {
  const ZypterExtractor._();

  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Player hashes embedded in a page (`/video/<hash>`).
  static List<String> videoHashes(String html) {
    final hashes = <String>[];
    final pattern = RegExp(
      r'''/video/([A-Za-z0-9_-]{12,})''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final hash = match.group(1)!;
      if (!hashes.contains(hash)) hashes.add(hash);
    }
    return hashes;
  }

  /// Hosts that answer the Zypter data endpoint.
  static bool isZypterHost(String url) {
    final lower = url.toLowerCase();
    return lower.contains('ravok.') ||
        lower.contains('zephyrix.') ||
        lower.contains('zephyr');
  }

  /// Playlist URL from the endpoint's JSON.
  static String? parseResponse(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    for (final key in const ['videoSource', 'securedLink']) {
      final value = (decoded[key] ?? '').toString().trim();
      if (value.startsWith('http')) return value.replaceAll(r'\/', '/');
    }
    return null;
  }

  /// One playlist from a player page URL (`https://host/video/<hash>`).
  static Future<String?> resolveUrl(
    String playerUrl, {
    http.Client? client,
  }) async {
    final uri = Uri.tryParse(playerUrl);
    if (uri == null) return null;
    final match = RegExp(r'/video/([A-Za-z0-9_-]{12,})').firstMatch(uri.path);
    final hash = match?.group(1);
    if (hash == null) return null;
    return resolveHash(uri.origin, hash, playerUrl: playerUrl, client: client);
  }

  static Future<String?> resolveHash(
    String origin,
    String hash, {
    String? playerUrl,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final api = Uri.parse('$origin/player/index.php?data=$hash&do=getVideo');
    try {
      final response = await httpClient
          .post(
            api,
            headers: {
              'User-Agent': userAgent,
              'Accept': '*/*',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Origin': origin,
              'Referer': playerUrl ?? '$origin/video/$hash',
              'X-Requested-With': 'XMLHttpRequest',
            },
            body: 'hash=$hash&r=${Uri.encodeComponent(origin)}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return parseResponse(response.body);
    } catch (_) {
      return null;
    }
  }
}
