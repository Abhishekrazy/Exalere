import 'package:flutter/foundation.dart';

import 'stream_extractors.dart';

/// A drive/direct link found on a post page, with quality inferred from the
/// text around it.
class HubCloudQualityLink {
  const HubCloudQualityLink({required this.quality, required this.url});

  final String quality;
  final String url;
}

/// A final downloadable/playable link found on a HubCloud page.
class HubCloudServerLink {
  const HubCloudServerLink({
    required this.server,
    required this.url,
    this.isDownloadOnly = false,
  });

  final String server;
  final String url;

  /// Google Drive links cannot be streamed directly, only downloaded.
  final bool isDownloadOnly;
}

/// A labelled link on a post page, used to pick an episode or a file.
class ScrapedLink {
  const ScrapedLink({required this.title, required this.url});

  final String title;
  final String url;
}

/// Resolution helpers shared by every site that ends at HubCloud.
///
/// Several of these sites use the same tail end: a post page lists drive links,
/// one is chosen, and the HubCloud page behind it exposes the real hosts. Only
/// the discovery half differs per site, so that half lives in each provider and
/// this half is shared and tested once.
class HubCloudExtractor {
  const HubCloudExtractor._();

  /// Collects hubcloud/hubdrive drive links, best quality first.
  ///
  /// Without a DOM the quality is inferred from a window of text around each
  /// anchor, which is how these pages label links ("… 1080p …").
  static List<HubCloudQualityLink> parseDriveLinks(String html) {
    final links = <HubCloudQualityLink>[];
    final pattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']*(?:hubcloud|hubdrive)[^"']*/?(?:drive)?[^"']*)["']''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final url = match.group(1);
      if (url == null || !url.contains('/drive/')) continue;

      final start = match.start - 300 < 0 ? 0 : match.start - 300;
      final context = html.substring(start, match.end).toLowerCase();
      final quality = StreamExtractors.guessQuality(context);

      links.add(HubCloudQualityLink(quality: quality, url: url));
    }

    links.sort(
      (a, b) => qualityRank(b.quality).compareTo(qualityRank(a.quality)),
    );
    return links;
  }

  /// Final links on a HubCloud page, named by the host that serves them.
  static List<HubCloudServerLink> parseServers(String html) {
    final servers = <HubCloudServerLink>[];
    final pattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["']''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final url = raw.trim();
      if (url.isEmpty || url.startsWith('#') || url.startsWith('javascript:')) {
        continue;
      }

      final lower = url.toLowerCase();
      HubCloudServerLink? link;

      if (lower.contains('pixeldrain') || lower.contains('pixeld')) {
        final api = StreamExtractors.pixeldrainApiUrl(url);
        if (api != null) {
          link = HubCloudServerLink(server: 'PixelDrain', url: api);
        }
      } else if (lower.contains('cloudflarestorage')) {
        link = HubCloudServerLink(server: 'CF Storage', url: url);
      } else if (lower.contains('hubcdn')) {
        link = HubCloudServerLink(server: 'HubCDN', url: url);
      } else if (lower.contains('fastdl') || lower.contains('fsl.')) {
        link = HubCloudServerLink(server: 'FastDL', url: url);
      } else if (lower.contains('gofile.io')) {
        link = HubCloudServerLink(server: 'Gofile', url: url);
      } else if (lower.contains('hubcloud')) {
        // Google Drive behind hubcloud: download only, never streamable.
        final drive = url.split('?link=').last;
        link = HubCloudServerLink(
          server: 'GDrive',
          url: drive,
          isDownloadOnly: true,
        );
      } else if (lower.endsWith('.mkv') || lower.endsWith('.mp4')) {
        link = HubCloudServerLink(server: 'Direct', url: url);
      }

      if (link != null && !servers.any((s) => s.url == link!.url)) {
        servers.add(link);
      }
    }
    return servers;
  }

  /// Orders servers so the most useful source is tried first.
  ///
  /// Streaming prefers hosts that support range requests and do not need the
  /// whole file first. Google Drive is pushed last because it cannot be streamed
  /// at all and is flagged [HubCloudServerLink.isDownloadOnly].
  static List<HubCloudServerLink> sortServers(
    List<HubCloudServerLink> servers, {
    bool forDownload = false,
  }) {
    int priority(HubCloudServerLink server) {
      final name = server.server.toLowerCase();
      if (forDownload) {
        if (name.contains('storage')) return 1;
        if (name.contains('gdrive')) return 2;
        if (name.contains('pixeldrain')) return 3;
        if (name.contains('gofile')) return 4;
        if (name.contains('fastdl')) return 5;
        if (name.contains('hubcdn')) return 6;
        return 8;
      }
      if (name.contains('storage')) return 1;
      if (name.contains('hubcdn')) return 3;
      if (name.contains('direct')) return 4;
      if (name.contains('pixeldrain')) return 5;
      if (name.contains('fastdl')) return 6;
      if (name.contains('gofile')) return 7;
      if (name.contains('gdrive')) return 9;
      return 8;
    }

    final sorted = [...servers];
    sorted.sort((a, b) {
      if (!forDownload) {
        if (a.isDownloadOnly != b.isDownloadOnly) {
          return a.isDownloadOnly ? 1 : -1;
        }
      }
      return priority(a).compareTo(priority(b));
    });
    return sorted;
  }

  /// Extracts labelled download links from a WordPress-style post page.
  ///
  /// These sites wrap each quality/episode in a heading anchor or a
  /// `.maxbutton` span, so both shapes are read. Unlabelled anchors and `#`
  /// placeholders are dropped rather than surfaced as broken entries.
  static List<ScrapedLink> parseEpisodeLinks(String html) {
    final links = <ScrapedLink>[];
    final seen = <String>{};

    void add(String? title, String? url) {
      if (url == null) return;
      final trimmed = url.trim();
      if (trimmed.isEmpty || trimmed == '#' || !trimmed.startsWith('http')) {
        return;
      }
      if (!seen.add(trimmed)) return;
      final label = (title ?? '').trim();
      links.add(
        ScrapedLink(title: label.isEmpty ? 'Download' : label, url: trimmed),
      );
    }

    // Heading anchors: <h3><a href="…">1080p</a></h3>
    final headingPattern = RegExp(
      r'''<h[34][^>]*>([\s\S]*?)</h[34]>''',
      caseSensitive: false,
    );
    final hrefPattern = RegExp(
      r'''href=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final textPattern = RegExp(r'>([^<>]+)<');

    for (final heading in headingPattern.allMatches(html)) {
      final inner = heading.group(1) ?? '';
      final href = hrefPattern.firstMatch(inner)?.group(1);
      if (href == null) continue;
      final label = textPattern.firstMatch(inner)?.group(1);
      add(label, href);
    }

    // Button anchors: <a class="maxbutton" href="…"><span>720p</span></a>
    final buttonPattern = RegExp(
      r'''<a\s+[^>]*class=["'][^"']*maxbutton[^"']*["'][^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    for (final match in buttonPattern.allMatches(html)) {
      final url = match.group(1);
      final inner = match.group(2) ?? '';
      final label = textPattern.firstMatch(inner)?.group(1);
      add(label, url);
    }

    if (links.isEmpty) {
      debugPrint('[HubCloudExtractor] No labelled links found on post page.');
    }
    return links;
  }

  /// A direct media URL needs no further resolution.
  static bool isDirectMedia(String url) {
    return RegExp(
      r'''\.(?:mp4|mkv|m3u8|avi|webm)($|\?)''',
      caseSensitive: false,
    ).hasMatch(url);
  }

  /// Ranking used to prefer the highest quality source.
  static int qualityRank(String quality) {
    switch (quality) {
      case '2160p':
        return 6;
      case '1440p':
        return 5;
      case '1080p':
        return 4;
      case '720p':
        return 3;
      case '480p':
        return 2;
      case '360p':
        return 1;
      default:
        return 0;
    }
  }
}
