import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';

/// Representation of a parsed release from 4KHDHub.
class FourKRelease {
  final String filename;
  final String quality;
  final String resolution;
  final String? codec;
  final int? sizeBytes;
  final int? season;
  final int? episode;
  final List<({String label, String url})> mirrors;

  const FourKRelease({
    required this.filename,
    required this.quality,
    required this.resolution,
    this.codec,
    this.sizeBytes,
    this.season,
    this.episode,
    required this.mirrors,
  });
}

class FourKHdHubProvider {
  static const String defaultBaseUrl = 'https://4khdhub.one';
  static const String browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client;

  FourKHdHubProvider({http.Client? client}) : _client = client ?? http.Client();

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$defaultBaseUrl/')
          .replace(queryParameters: {'s': query.trim()});
      final resp = await _client
          .get(
            uri,
            headers: {
              'User-Agent': browserUa,
              'Accept': 'text/html,application/xhtml+xml,application/xml',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return [];

      return parseSearchResults(resp.body);
    } catch (e) {
      debugPrint('4KHDHub search error: $e');
      return [];
    }
  }

  List<MediaItem> parseSearchResults(String html) {
    final List<MediaItem> items = [];
    final cardTagRegex = RegExp(
      r'''<a\s+([^>]*class=["'][^"']*movie-card[^"']*["'][^>]*)>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final hrefRegex = RegExp(
      r'''href=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final titleRegex = RegExp(
      r'''<[^>]*class=["'][^"']*movie-card-title[^"']*["'][^>]*>([^<]+)<''',
      caseSensitive: false,
    );
    final imgRegex = RegExp(
      r'''<img\s+[^>]*src=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final metaRegex = RegExp(
      r'''<[^>]*class=["'][^"']*movie-card-meta[^"']*["'][^>]*>([^<]+)<''',
      caseSensitive: false,
    );

    for (final match in cardTagRegex.allMatches(html)) {
      final attrs = match.group(1) ?? '';
      final cardHtml = match.group(2) ?? '';

      final hrefMatch = hrefRegex.firstMatch(attrs);
      final href = hrefMatch?.group(1);
      if (href == null || href.isEmpty) continue;

      final titleMatch = titleRegex.firstMatch(cardHtml);
      final title = titleMatch?.group(1)?.trim();
      if (title == null || title.isEmpty) continue;

      final imgMatch = imgRegex.firstMatch(cardHtml);
      final posterUrl = imgMatch?.group(1);

      final metaMatch = metaRegex.firstMatch(cardHtml);
      final metaText = metaMatch?.group(1)?.trim();
      String? year;
      if (metaText != null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(metaText);
        year = yMatch?.group(0);
      }

      final isSeries = href.contains('-series-');

      items.add(
        MediaItem(
          id: href,
          title: title,
          mediaType: isSeries ? MediaType.series : MediaType.movie,
          year: year,
          posterUrl: posterUrl,
          provider: ProviderType.fourKHdHub,
          providerId: 'fourkhdhub',
        ),
      );
    }

    return items;
  }

  Future<MediaDetails?> getDetails(String path) async {
    try {
      final url = path.startsWith('http') ? path : '$defaultBaseUrl$path';
      final resp = await _client
          .get(Uri.parse(url), headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;
      final html = resp.body;

      final h1Match = RegExp(
        r'<h1[^>]*>([^<]+)<\/h1>',
        caseSensitive: false,
      ).firstMatch(html);
      final title = h1Match?.group(1)?.trim() ?? 'Untitled';

      final descMatch = RegExp(
        r'<div\s+[^>]*class="[^"]*content-section[^"]*"[^>]*>[\s\S]*?<p[^>]*>([^<]+)<\/p>',
        caseSensitive: false,
      ).firstMatch(html);
      final desc = descMatch?.group(1)?.trim();

      final imdbMatch = RegExp(
        r'<[^>]*class="[^"]*imdb-score[^"]*"[^>]*>([^<]+)<',
        caseSensitive: false,
      ).firstMatch(html);
      final imdb = imdbMatch?.group(1)?.trim();

      final imgMatch = RegExp(
        r'<div\s+[^>]*class="[^"]*movie-poster[^"]*"[^>]*>[\s\S]*?<img\s+[^>]*src="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      final poster = imgMatch?.group(1);

      return MediaDetails(
        id: path,
        title: title,
        mediaType: path.contains('-series-')
            ? MediaType.series
            : MediaType.movie,
        description: desc,
        imdbRating: imdb,
        posterUrl: poster,
        provider: ProviderType.fourKHdHub,
      );
    } catch (e) {
      debugPrint('4KHDHub details error: $e');
      return null;
    }
  }

  /// Primary multi-provider stream resolver method.
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    String? targetPath;

    if (subjectId.startsWith('/') || subjectId.startsWith('http')) {
      targetPath = subjectId;
    } else if (title != null && title.trim().isNotEmpty) {
      final results = await search(title.trim());
      if (results.isNotEmpty) {
        final isSeries = season != null && season > 0;
        final best = results.firstWhere(
          (m) => isSeries ? m.isSeries : !m.isSeries,
          orElse: () => results.first,
        );
        targetPath = best.id;
      }
    }

    if (targetPath == null || targetPath.isEmpty) return [];

    return getStreamsForPath(targetPath, season: season, episode: episode);
  }

  /// Resolve streams for a specific 4KHDHub path/URL.
  Future<List<StreamSource>> getStreamsForPath(
    String path, {
    int? season,
    int? episode,
  }) async {
    try {
      final url = path.startsWith('http') ? path : '$defaultBaseUrl$path';
      final resp = await _client
          .get(Uri.parse(url), headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return [];
      final html = resp.body;

      final releases = parseReleases(html, season: season, episode: episode);
      if (releases.isEmpty) {
        // Fallback: check direct links on the page if no release blocks matched
        return _fallbackDirectLinks(html);
      }

      final streamSources = <StreamSource>[];
      final seenUrls = <String>{};

      // Process releases in parallel with bounded concurrency
      final releaseFutures = releases.map((release) async {
        final mirrorStreams = <StreamSource>[];

        // 1. Collect all candidate URLs across mirrors for this release
        final candidateItems = <({String url, String label, int score})>[];

        for (final mirror in release.mirrors) {
          final candidates = await resolveMirror(mirror.url);
          for (final candUrl in candidates) {
            if (candUrl.isEmpty || seenUrls.contains(candUrl)) continue;
            seenUrls.add(candUrl);
            final score = scoreCandidate(candUrl, label: mirror.label);
            candidateItems.add((
              url: candUrl,
              label: mirror.label,
              score: score,
            ));
          }
        }

        // 2. Sort candidates so top servers (Cloudflare R2, Google Storage) are tried first
        candidateItems.sort((a, b) => a.score.compareTo(b.score));

        // 3. Preflight probe candidates in parallel to eliminate 404s and TLS resets
        final verifiedCandidates = <({String url, String label, int score})>[];
        final preflightFutures = candidateItems.map((cand) async {
          final isPlayable = await preflightUrl(cand.url);
          return (cand: cand, playable: isPlayable);
        });

        final preflightResults = await Future.wait(preflightFutures);
        for (final res in preflightResults) {
          if (res.playable) {
            verifiedCandidates.add(res.cand);
          }
        }

        // Fallback to unprobed candidates if preflight fails for all (e.g. offline/mocked tests)
        final finalCandidates = verifiedCandidates.isNotEmpty
            ? verifiedCandidates
            : candidateItems;

        // Keep up to 3 highest-ranked working candidates per release
        for (final cand in finalCandidates.take(3)) {
          final format = cand.url.toLowerCase().contains('.mkv')
              ? 'MKV'
              : 'MP4';
          final qualityLabel = '${release.quality} • ${cand.label}';

          mirrorStreams.add(
            StreamSource(
              quality: '${release.quality} (${format.toUpperCase()})',
              resolution: release.resolution,
              format: format,
              url: cand.url,
              headers: getHeadersForUrl(cand.url),
              codec: release.codec,
              sizeBytes: release.sizeBytes,
              server: '4K HD Hub ($qualityLabel)',
              providerId: 'fourkhdhub',
              providerName: '4K HD Hub',
            ),
          );
        }

        return mirrorStreams;
      });

      final results = await Future.wait(releaseFutures);
      for (final list in results) {
        streamSources.addAll(list);
      }

      return streamSources;
    } catch (e) {
      debugPrint('4KHDHub getStreamsForPath error: $e');
      return [];
    }
  }

  /// Parse downloadable releases and episode items from page HTML.
  static List<FourKRelease> parseReleases(
    String html, {
    int? season,
    int? episode,
  }) {
    final releases = <FourKRelease>[];

    final blockRegex = RegExp(
      r'<div\s+[^>]*class="[^"]*(?:episode-download-item|download-item)[^"]*"[^>]*>([\s\S]*?)(?=<div\s+[^>]*class="[^"]*(?:episode-download-item|download-item)|$)',
      caseSensitive: false,
    );

    final titleRegex = RegExp(
      r'<div\s+[^>]*class="[^"]*(?:episode-file-title|file-title)[^"]*"[^>]*>([\s\S]*?)<\/div>',
      caseSensitive: false,
    );

    final sizeRegex = RegExp(
      r'<span\s+[^>]*class="[^"]*(?:badge-size|badge)[^"]*"[^>]*>([^<]+)<\/span>',
      caseSensitive: false,
    );

    final linkRegex = RegExp(
      r'<a\s+[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>',
      caseSensitive: false,
    );

    for (final blockMatch in blockRegex.allMatches(html)) {
      final blockHtml = blockMatch.group(1) ?? '';
      final titleMatch = titleRegex.firstMatch(blockHtml);
      if (titleMatch == null) continue;
      final filename =
          titleMatch.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim() ?? '';
      if (filename.isEmpty || filename.toLowerCase().endsWith('.zip')) continue;

      final se = parseSeasonEpisode(filename);
      if (season != null && season > 0) {
        if (se == null || se.$1 != season || se.$2 != (episode ?? 1)) {
          continue;
        }
      }

      int? sizeBytes;
      for (final sm in sizeRegex.allMatches(blockHtml)) {
        final sText = sm.group(1)?.trim() ?? '';
        final parsed = parseSizeBytes(sText);
        if (parsed != null) {
          sizeBytes = parsed;
          break;
        }
      }

      final mirrors = <({String label, String url})>[];
      for (final lm in linkRegex.allMatches(blockHtml)) {
        final href = lm.group(1)?.trim() ?? '';
        if (!href.startsWith('https://') && !href.startsWith('http://')) {
          continue;
        }
        if (href.contains('logout') || href.contains('login.php')) {
          continue;
        }

        final rawLabel =
            lm
                .group(2)
                ?.replaceAll(RegExp(r'<[^>]+>'), '')
                .replaceAll('&nbsp;', ' ')
                .trim() ??
            'Mirror';
        final cleanLabel = rawLabel.replaceFirst('Download ', '').trim();
        mirrors.add((
          label: cleanLabel.isNotEmpty ? cleanLabel : 'Mirror',
          url: href,
        ));
      }

      if (mirrors.isEmpty) continue;

      final quality = detectQuality(filename);
      releases.add(
        FourKRelease(
          filename: filename,
          quality: quality,
          resolution: detectResolution(quality),
          codec: detectCodec(filename),
          sizeBytes: sizeBytes,
          season: se?.$1,
          episode: se?.$2,
          mirrors: mirrors,
        ),
      );
    }

    return releases;
  }

  /// Resolve a mirror link (GreenMotors mediator, HubDrive, HubCloud) to direct stream URLs.
  Future<List<String>> resolveMirror(String mirrorUrl) async {
    final results = <String>[];
    try {
      String targetUrl = mirrorUrl;

      // 1. Mediator Unpacking (greenmotors.club, greenmountmotors.)
      if (targetUrl.contains('greenmotors.') ||
          targetUrl.contains('greenmountmotors.')) {
        final resp = await _client
            .get(Uri.parse(targetUrl), headers: {'User-Agent': browserUa})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return results;

        final payload = extractGreenmotorsPayload(resp.body);
        if (payload == null) return results;

        final unpacked = decodeGreenmotorsPayload(payload);
        if (unpacked == null) return results;

        targetUrl = unpacked;
      }

      // 2. HubDrive resolver (hubdrive.)
      if (targetUrl.contains('hubdrive.')) {
        final resp = await _client
            .get(Uri.parse(targetUrl), headers: {'User-Agent': browserUa})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return results;

        final hubcloudDrive = extractHubcloudDriveUrl(resp.body);
        if (hubcloudDrive == null) return results;

        targetUrl = hubcloudDrive;
      }

      // 3. HubCloud drive page resolver
      if (targetUrl.contains('hubcloud.')) {
        final resp = await _client
            .get(Uri.parse(targetUrl), headers: {'User-Agent': browserUa})
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return results;

        final resolverUrl = extractHubcloudResolverUrl(resp.body);
        if (resolverUrl == null) return results;

        targetUrl = resolverUrl;
      }

      // 4. Resolver page (gamerxyt.com, hubcloud.php, etc.)
      if (targetUrl.contains('gamerxyt.com') ||
          targetUrl.contains('hubcloud.php') ||
          targetUrl.contains('/download/')) {
        final resp = await _client
            .get(
              Uri.parse(targetUrl),
              headers: {'User-Agent': browserUa, 'Referer': defaultBaseUrl},
            )
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return results;

        final html = resp.body;

        // A. Script pixeldrain URLs
        for (final px in extractScriptPixeldrainUrls(html)) {
          if (!results.contains(px)) results.add(px);
        }

        // B. Link hrefs
        final linkRegex = RegExp(
          r'''<a\s+[^>]*href=["']([^"']+)["']''',
          caseSensitive: false,
        );
        for (final m in linkRegex.allMatches(html)) {
          final href = m.group(1)?.trim() ?? '';
          if (href.isEmpty) continue;

          final unwrapped = unwrapWatchOnlineUrl(href);
          if (unwrapped != null && !results.contains(unwrapped)) {
            results.add(unwrapped);
            continue;
          }

          final px = pixeldrainApiUrl(href);
          if (px != null && !results.contains(px)) {
            results.add(px);
            continue;
          }

          if (href.contains('r2.cloudflarestorage.com') ||
              href.contains('googleusercontent.com') ||
              href.contains('googlevideo.com') ||
              href.endsWith('.mkv') ||
              href.endsWith('.mp4')) {
            if (!results.contains(href)) results.add(href);
          }
        }
      } else if (targetUrl.startsWith('http://') ||
          targetUrl.startsWith('https://')) {
        results.add(targetUrl);
      }
    } catch (e) {
      debugPrint('4KHDHub resolveMirror error: $e');
    }
    return results;
  }

  /// MovieBox-Tui matching server/stream priority scoring.
  /// 0: Cloudflare R2 / Google CDN / direct streams (Fastest, cleanest)
  /// 1: Googleapis storage
  /// 2: Generic direct media
  /// 3: PixelDrain (Rate-limited, occasional TLS resets/404s)
  static int scoreCandidate(String url, {String? label}) {
    final lowerUrl = url.toLowerCase();
    final lowerLabel = (label ?? '').toLowerCase();
    if (lowerUrl.contains('r2.cloudflarestorage.com') ||
        lowerUrl.contains('cloudflarestorage.com') ||
        lowerUrl.contains('googleusercontent.com') ||
        lowerUrl.contains('googlevideo.com') ||
        lowerLabel.contains('fsl server') ||
        lowerLabel.contains('watch online')) {
      return 0;
    } else if (lowerUrl.contains('storage.googleapis.com')) {
      return 1;
    } else if (lowerUrl.contains('pixeldrain')) {
      return 3;
    } else {
      return 2;
    }
  }

  /// Get appropriate HTTP headers for playing or probing a URL.
  /// Cloudflare R2 and AWS S3 presigned URLs fail with HTTP 403 if custom Referers are injected.
  static Map<String, String> getHeadersForUrl(String url) {
    final lower = url.toLowerCase();
    final isR2orAmz =
        lower.contains('r2.cloudflarestorage.com') ||
        lower.contains('cloudflarestorage.com') ||
        lower.contains('x-amz-');
    if (isR2orAmz) {
      return {'User-Agent': browserUa};
    }
    return {'User-Agent': browserUa, 'Referer': defaultBaseUrl};
  }

  /// Preflight check verifying HTTP 200/206 and live video stream.
  Future<bool> preflightUrl(String url) async {
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = browserUa;
      req.headers['Range'] = 'bytes=0-8191';
      final lower = url.toLowerCase();
      final isR2orAmz =
          lower.contains('r2.cloudflarestorage.com') ||
          lower.contains('cloudflarestorage.com') ||
          lower.contains('x-amz-');
      if (!isR2orAmz) {
        req.headers['Referer'] = defaultBaseUrl;
      }

      final streamed = await _client
          .send(req)
          .timeout(const Duration(milliseconds: 3500));
      if (streamed.statusCode == 200 || streamed.statusCode == 206) {
        final ctype = (streamed.headers['content-type'] ?? '').toLowerCase();
        if (ctype.contains('text/html') ||
            ctype.contains('text/plain') ||
            ctype.contains('application/zip')) {
          return false;
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<StreamSource> _fallbackDirectLinks(String html) {
    final List<StreamSource> sources = [];
    final linkRegex = RegExp(
      r'href="([^"]*(?:hubcloud|hubdrive|drive|stream)[^"]*)"',
      caseSensitive: false,
    );
    for (final match in linkRegex.allMatches(html)) {
      final link = match.group(1);
      if (link != null && link.startsWith('http')) {
        sources.add(
          StreamSource(
            quality: 'HD Stream',
            resolution: '1080p',
            format: 'MP4',
            url: link,
            headers: getHeadersForUrl(link),
            server: '4K HD Hub',
            providerId: 'fourkhdhub',
            providerName: '4K HD Hub',
          ),
        );
      }
    }
    return sources;
  }

  // --- Decoding & Parsing Utilities ---

  static (int season, int episode)? parseSeasonEpisode(String filename) {
    final match = RegExp(r'[sS](\d+)[\. -]?[eE](\d+)').firstMatch(filename);
    if (match != null) {
      final s = int.tryParse(match.group(1)!);
      final e = int.tryParse(match.group(2)!);
      if (s != null && e != null) return (s, e);
    }
    return null;
  }

  static int? parseSizeBytes(String text) {
    final match = RegExp(
      r'([\d\.]+)\s*(GB|MB|KB)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final val = double.tryParse(match.group(1)!);
    if (val == null) return null;
    final unit = match.group(2)!.toUpperCase();
    if (unit == 'GB') return (val * 1024 * 1024 * 1024).toInt();
    if (unit == 'MB') return (val * 1024 * 1024).toInt();
    if (unit == 'KB') return (val * 1024).toInt();
    return null;
  }

  static String detectQuality(String filename) {
    final stripped = filename
        .replaceAll(RegExp(r'-4kHdHub\.Com', caseSensitive: false), '')
        .toLowerCase();
    if (stripped.contains('2160p') || RegExp(r'\b4k\b').hasMatch(stripped)) {
      return '4K (2160p)';
    }
    if (stripped.contains('1080p')) return '1080p (FHD)';
    if (stripped.contains('720p')) return '720p (HD)';
    if (stripped.contains('480p')) return '480p (SD)';
    return '1080p (HD)';
  }

  static String detectResolution(String quality) {
    if (quality.contains('2160p') || quality.contains('4K')) return '3840x2160';
    if (quality.contains('1080p')) return '1920x1080';
    if (quality.contains('720p')) return '1280x720';
    if (quality.contains('480p')) return '854x480';
    return '1920x1080';
  }

  static String? detectCodec(String filename) {
    final f = filename.toUpperCase();
    if (f.contains('AV1')) return 'AV1';
    if (f.contains('H.265') || f.contains('H265') || f.contains('HEVC')) {
      if (f.contains('DV') || f.contains('DOVI')) return 'HEVC • DV HDR';
      if (f.contains('HDR')) return 'HEVC • HDR';
      return 'HEVC';
    }
    if (f.contains('H.264') || f.contains('H264') || f.contains('AVC')) {
      return 'H.264';
    }
    return null;
  }

  static String rot13(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
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

  static String? extractGreenmotorsPayload(String html) {
    final regex = RegExp(r"""s\(\s*['"]o['"]\s*,\s*['"]([^'"]+)['"]""");
    final match = regex.firstMatch(html);
    return match?.group(1);
  }

  static String? decodeGreenmotorsPayload(String payload) {
    try {
      final step1Bytes = base64.decode(payload.trim());
      final step1Str = utf8.decode(step1Bytes);

      final step2Bytes = base64.decode(step1Str.trim());
      final step2Str = utf8.decode(step2Bytes);

      final step3Rot = rot13(step2Str);

      final step4Bytes = base64.decode(step3Rot.trim());
      final step4Str = utf8.decode(step4Bytes);

      final jsonMap = json.decode(step4Str) as Map<String, dynamic>;
      final targetB64 = jsonMap['o'] as String?;
      if (targetB64 == null) return null;

      final targetBytes = base64.decode(targetB64.trim());
      final targetUrl = utf8.decode(targetBytes);
      return targetUrl.trim();
    } catch (e) {
      debugPrint('4KHDHub error decoding greenmotors payload: $e');
      return null;
    }
  }

  static String? extractHubcloudDriveUrl(String html) {
    final linkRegex = RegExp(
      r'''href=["'](https://[^"']*hubcloud\.[^"']*/drive/[^"']*)["']''',
      caseSensitive: false,
    );
    final match = linkRegex.firstMatch(html);
    return match?.group(1);
  }

  static String? extractHubcloudResolverUrl(String html) {
    final downloadRegex = RegExp(
      r'''<a\s+[^>]*href=["']([^"']*(?:gamerxyt\.com|hubcloud\.php|/download/)[^"']*)["']''',
      caseSensitive: false,
    );
    final match = downloadRegex.firstMatch(html);
    if (match != null) {
      final url = match.group(1);
      if (url != null && url.startsWith('http')) return url;
    }
    return null;
  }

  static List<String> extractScriptPixeldrainUrls(String html) {
    final urls = <String>[];
    final prefixes = [
      'https://pixeldrain.dev/u/',
      'https://pixeldrain.com/u/',
      'https://pixeldrain.dev/api/file/',
      'https://pixeldrain.com/api/file/',
    ];

    for (final prefix in prefixes) {
      var remainder = html;
      while (true) {
        final idx = remainder.indexOf(prefix);
        if (idx == -1) break;
        final candidate = remainder.substring(idx);
        final endMatch = RegExp(r'''["\s'<>\\]''').firstMatch(candidate);
        final end = endMatch?.start ?? candidate.length;
        final raw = candidate.substring(0, end);
        final api = pixeldrainApiUrl(raw);
        if (api != null && !urls.contains(api)) {
          urls.add(api);
        }
        remainder = candidate.substring(end);
      }
    }
    return urls;
  }

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

  static String? unwrapWatchOnlineUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.host.contains('pages.dev')) return null;

    final uParam = uri.queryParameters['u'];
    if (uParam == null || uParam.isEmpty) return null;

    try {
      final decoded = utf8.decode(base64.decode(uParam));
      if (decoded.startsWith('https://') || decoded.startsWith('http://')) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }
}
