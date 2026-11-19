/// One server button on a Cineverse/Modiplay embed page.
class CineverseServer {
  const CineverseServer({
    required this.platform,
    required this.name,
    required this.code,
    required this.embedUrl,
  });

  final String platform;
  final String name;
  final String code;

  /// Absolute player URL when the page gave one, else empty.
  final String embedUrl;
}

/// Resolves Cineverse (Modiplay) embed pages into HLS playlists.
///
/// The hub renders a player iframe and a row of `.srv-item` buttons. Each button
/// either points at an external player or at the hub's own `proxy.php`, which
/// answers with an HTML page holding `var src="/stream_proxy.php?url=…m3u8…"`.
/// That relay is itself the playlist (it forwards the CDN stream with the right
/// referer), so it is returned as the stream URL.
class CineverseExtractor {
  const CineverseExtractor._();

  static const String refererHub = 'https://multimovies.garden/';

  static const String mobileUa =
      'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36';

  static bool isCineverseUrl(String url) =>
      url.toLowerCase().contains('modiplay.xyz');

  /// Embed URLs a post page prints (`src`, `href` or `data-url`).
  static List<String> collectEmbedUrls(String html) {
    final found = <String>[];
    final seen = <String>{};
    final pattern = RegExp(
      '''(?:src|href|data-url)\\s*=\\s*["']([^"']*modiplay\\.xyz[^"']*)["']''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final url = (match.group(1) ?? '').trim();
      if (url.isEmpty || !url.startsWith('http')) continue;
      if (seen.add(url)) found.add(url);
    }
    return found;
  }

  /// Server buttons on an embed page, in page order.
  static List<CineverseServer> parseServers(String html) {
    final servers = <CineverseServer>[];
    final seen = <String>{};
    final tagPattern = RegExp(
      '<[^>]+data-platform\\s*=\\s*["\']([^"\']+)["\'][^>]*>',
      caseSensitive: false,
    );
    String attr(String tag, String name) {
      final match = RegExp(
        '$name\\s*=\\s*["\']([^"\']*)["\']',
        caseSensitive: false,
      ).firstMatch(tag);
      return (match?.group(1) ?? '').trim();
    }

    for (final match in tagPattern.allMatches(html)) {
      final tag = match.group(0) ?? '';
      final platform = (match.group(1) ?? '').trim();
      if (platform.isEmpty) continue;
      final code = attr(tag, 'data-code');
      final name = attr(tag, 'data-pname');
      final embedUrl = attr(tag, 'data-url');
      final key = '$platform|$code|$embedUrl';
      if (!seen.add(key)) continue;
      servers.add(
        CineverseServer(
          platform: platform,
          name: name.isEmpty ? platform : name,
          code: code,
          embedUrl: embedUrl,
        ),
      );
    }
    return servers;
  }

  /// Playlist URL hidden in a proxy page.
  ///
  /// Handles the four shapes the hub emits: `var directSrc="…m3u8"`, a
  /// `stream_proxy.php?url=` relay, any absolute `.m3u8`, and a bare
  /// `/hls/…/master.m3u8`.
  static String? extractM3u8(String html, String hub) {
    final decoded = html.replaceAll(RegExp(r'\\+/'), '/');

    // The relay comes first on purpose: `directSrc` is the bare CDN playlist,
    // which answers 403 without the hub's token. The relay carries that token.
    var match = RegExp(
      '["\']((?:/|https?://)[^"\'\\s<>]*stream_proxy\\.php\\?url=[^"\'\\s<>]+)["\']',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (match != null) {
      var relay = match.group(1)!.trim();
      if (!relay.startsWith('http')) {
        relay = '$hub${relay.startsWith('/') ? '' : '/'}$relay';
      }
      if (!relay.contains('seg=')) relay = '$relay&seg=direct';
      return relay;
    }

    match = RegExp(
      'var\\s+directSrc\\s*=\\s*["\']([^"\']+\\.m3u8[^"\']*)["\']',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (match != null && match.group(1)!.startsWith('http')) {
      return match.group(1)!.trim();
    }

    match = RegExp(
      'https?://[^"\'\\s<>\\\\]+\\.m3u8[^"\'\\s<>\\\\]*',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (match != null) return match.group(0)!.trim();

    match = RegExp(
      '["\'](/hls/[^"\'\\s]+master\\.m3u8[^"\'\\s]*)["\']',
      caseSensitive: false,
    ).firstMatch(decoded);
    if (match != null) return '$hub${match.group(1)!.trim()}';

    return null;
  }

  /// Builds the proxy URL the hub uses to play one of its own servers.
  static String proxyUrl(String hub, CineverseServer server, String title) {
    final query = Uri(
      queryParameters: {
        'p': server.platform,
        'c': server.code,
        'title': title,
        'site_ref': refererHub,
        'noredirect': '1',
      },
    ).query;
    return '$hub/proxy.php?$query';
  }

  /// Resolves an embed page to playable URLs.
  static Future<List<String>> resolve(
    String embedUrl, {
    required Future<String?> Function(String url, Map<String, String> headers)
    fetchPage,
  }) async {
    final mapHeaders = {
      'User-Agent': mobileUa,
      'Referer': refererHub,
      'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
    };

    final uri = Uri.tryParse(embedUrl);
    if (uri == null) return const [];
    final hub = uri.origin;

    final html = await fetchPage(embedUrl, mapHeaders);
    if (html == null || html.isEmpty) return const [];

    final servers = parseServers(html);
    if (servers.isEmpty) return const [];

    final streams = <String>[];
    final seen = <String>{};
    for (final server in servers.take(4)) {
      final url = server.embedUrl.isNotEmpty
          ? (server.embedUrl.startsWith('http')
                ? server.embedUrl
                : '$hub${server.embedUrl.startsWith('/') ? '' : '/'}'
                      '${server.embedUrl}')
          : proxyUrl(hub, server, '');
      final page = await fetchPage(url, mapHeaders);
      if (page == null) continue;
      final playlist = extractM3u8(page, hub);
      if (playlist == null) continue;
      if (seen.add(playlist)) streams.add(playlist);
    }
    return streams;
  }
}
