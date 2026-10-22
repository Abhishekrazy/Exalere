import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Shared stream-extraction helpers used by HTML-scraping providers.
///
/// These lived inside a single provider, so every other site had to either
/// duplicate them or go without — and none of it was reachable from a test. They
/// are pure string functions, so they belong here: one implementation, reused by
/// every scraper, and directly testable.
///
/// Each resolver takes page text and returns a URL or null. Nothing here performs
/// I/O; fetching the page is the caller's job.
class StreamExtractors {
  const StreamExtractors._();

  /// Rotates letters by 13 places. Used as one layer of some payload encodings.
  static String rot13(String input) {
    final buffer = StringBuffer();
    for (final code in input.codeUnits) {
      if (code >= 65 && code <= 90) {
        buffer.writeCharCode((code - 65 + 13) % 26 + 65);
      } else if (code >= 97 && code <= 122) {
        buffer.writeCharCode((code - 97 + 13) % 26 + 97);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  // -------------------------------------------------------------------
  // Greenmotors / packed payloads
  // -------------------------------------------------------------------

  /// Pulls the packed payload out of a `s('o', '<payload>')` call.
  static String? extractGreenmotorsPayload(String html) {
    final regex = RegExp(r"""s\(\s*['"]o['"]\s*,\s*['"]([^'"]+)['"]""");
    return regex.firstMatch(html)?.group(1);
  }

  /// Unpacks the nested base64 + rot13 payload to the real target URL.
  ///
  /// The chain is: base64 → base64 → rot13 → base64 → JSON, whose `o` field is
  /// itself base64 for the URL. Any single bad layer returns null rather than
  /// throwing, because a page layout change must not crash a provider.
  static String? decodeGreenmotorsPayload(String payload) {
    try {
      final step1 = utf8.decode(base64.decode(payload.trim()));
      final step2 = utf8.decode(base64.decode(step1.trim()));
      final rotated = rot13(step2);
      final step4 = utf8.decode(base64.decode(rotated.trim()));

      final decoded = json.decode(step4);
      if (decoded is! Map) return null;
      final target = decoded['o'];
      if (target is! String || target.isEmpty) return null;

      final url = utf8.decode(base64.decode(target.trim()));
      return url.trim();
    } catch (e) {
      debugPrint('[StreamExtractors] Payload decode failed: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------
  // HubCloud / HubDrive
  // -------------------------------------------------------------------

  /// Finds a `hubcloud.*/drive/...` link, which is the intermediate page that
  /// ultimately yields the file link.
  static String? extractHubcloudDriveUrl(String html) {
    final regex = RegExp(
      r'''href=["'](https://[^"']*hubcloud\.[^"']*/drive/[^"']*)["']''',
      caseSensitive: false,
    );
    return regex.firstMatch(html)?.group(1);
  }

  /// Finds the final download anchor on a hubcloud resolver page.
  static String? extractHubcloudResolverUrl(String html) {
    final regex = RegExp(
      r'''<a\s+[^>]*href=["']([^"']*(?:gamerxyt\.com|hubcloud\.php|/download/)[^"']*)["']''',
      caseSensitive: false,
    );
    final url = regex.firstMatch(html)?.group(1);
    if (url != null && url.startsWith('http')) return url;
    return null;
  }

  // -------------------------------------------------------------------
  // PixelDrain
  // -------------------------------------------------------------------

  /// Converts any PixelDrain page/API URL into a direct downloadable file URL.
  static String? pixeldrainApiUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.host.contains('pixeldrain.')) return null;

    String? id;
    if (uri.path.startsWith('/u/')) {
      id = uri.path.substring(3).replaceAll('/', '');
    } else if (uri.path.startsWith('/api/file/')) {
      id = uri.path.substring(10).replaceAll('/', '');
    }
    if (id == null || id.isEmpty) return null;
    return 'https://pixeldrain.com/api/file/$id?download';
  }

  /// Collects every PixelDrain link referenced anywhere in a page, including
  /// inside inline scripts, normalised to direct file URLs.
  ///
  /// Results follow document order, not grouped by host, so the first entry is
  /// the source the page itself listed first — which is the site's own
  /// preference and the sensible one to try initially.
  static List<String> extractScriptPixeldrainUrls(String html) {
    final urls = <String>[];
    final pattern = RegExp(
      r'''https?://pixeldrain\.(?:com|dev)/(?:u|api/file)/[^\s"'<>\\]+''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final api = pixeldrainApiUrl(match.group(0)!);
      if (api != null && !urls.contains(api)) urls.add(api);
    }
    return urls;
  }

  // -------------------------------------------------------------------
  // pages.dev wrappers
  // -------------------------------------------------------------------

  /// Unwraps a `*.pages.dev?u=<base64 url>` redirector to its real target.
  static String? unwrapWatchOnlineUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.host.contains('pages.dev')) return null;

    final param = uri.queryParameters['u'];
    if (param == null || param.isEmpty) return null;

    try {
      final decoded = utf8.decode(base64.decode(param));
      if (decoded.startsWith('https://') || decoded.startsWith('http://')) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  // -------------------------------------------------------------------
  // Generic scanning
  // -------------------------------------------------------------------

  /// Direct media and manifest URLs, most specific extension first so that a
  /// `.m3u8` inside a player config is not missed behind an `.mp4` fallback.
  static final RegExp _mediaUrlPattern = RegExp(
    r'''https?://[^\s"'<>()\\]+?\.(?:m3u8|mpd|mp4|mkv|webm)(?:\?[^\s"'<>()\\]*)?''',
    caseSensitive: false,
  );

  /// Finds playable URLs embedded anywhere in page text or script.
  ///
  /// Handles the two things that most commonly hide them: JSON-escaped slashes
  /// (`https:\/\/…`) and `\u002F` escapes. Results are de-duplicated but keep
  /// document order, so the first entry is the site's preferred source.
  static List<String> findMediaUrls(String text) {
    if (text.isEmpty) return const [];

    final normalized = text
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u002f', '/');

    final found = <String>[];
    for (final match in _mediaUrlPattern.allMatches(normalized)) {
      final url = match.group(0);
      if (url != null && !found.contains(url)) found.add(url);
    }
    return found;
  }

  /// Classify a URL into the format label the player expects.
  static String guessFormat(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'HLS';
    if (lower.contains('.mpd')) return 'DASH';
    return 'MP4';
  }

  /// Infer a quality label from a URL or surrounding text.
  ///
  /// Returns 'Auto' when nothing recognisable is present — better than claiming
  /// 1080p for an unknown source.
  static String guessQuality(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('2160') || lower.contains('4k')) return '2160p';
    if (lower.contains('1440')) return '1440p';
    if (lower.contains('1080')) return '1080p';
    if (lower.contains('720')) return '720p';
    if (lower.contains('480')) return '480p';
    if (lower.contains('360')) return '360p';
    return 'Auto';
  }

  /// Resolution label matching [guessQuality], for the player's metadata row.
  static String resolutionForQuality(String quality) {
    switch (quality) {
      case '2160p':
        return '3840x2160';
      case '1440p':
        return '2560x1440';
      case '1080p':
        return '1920x1080';
      case '720p':
        return '1280x720';
      case '480p':
        return '854x480';
      case '360p':
        return '640x360';
      default:
        return 'Unknown';
    }
  }
}
