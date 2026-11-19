import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_extractors.dart';

/// Reads the `nexdrive` hop these WordPress themes put in front of their files.
///
/// A post page does not link to a file. It links to a nexdrive mirror page, and
/// that page lists the real servers (V-Cloud, G-Direct, V-Drive, Gofile). The
/// hop is plain HTML on both sides — no captcha, no timer — so it is safe to
/// follow, unlike the shortlink gates this project deliberately leaves alone.
class NexdriveExtractor {
  const NexdriveExtractor._();

  /// Hosts a post page links to instead of the file itself.
  static bool isNexdriveUrl(String url) =>
      url.toLowerCase().contains('nexdrive');

  /// Mirrors a nexdrive page offers, in page order.
  ///
  /// Anchors are matched by the server they point at rather than by their label:
  /// the labels are emoji-decorated ("⚡ V-Cloud [Resumable]") and change, while
  /// the host is what the resolver actually needs.
  static List<ScrapedLink> parseServerLinks(String html) {
    final links = <ScrapedLink>[];
    final seen = <String>{};
    final pattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final text = RegExp(r'>([^<>]+)<');

    for (final match in pattern.allMatches(html)) {
      final url = (match.group(1) ?? '').trim();
      final lower = url.toLowerCase();
      if (!url.startsWith('http')) continue;

      final isServer =
          lower.contains('vcloud.') ||
          lower.contains('hubcloud') ||
          lower.contains('fastdl') ||
          lower.contains('vegadrive') ||
          lower.contains('gofile.io') ||
          lower.contains('pixeldrain') ||
          isEmbedRedirectUrl(url);
      if (!isServer) continue;
      if (!seen.add(url)) continue;

      final rawLabel = text.firstMatch(match.group(2) ?? '')?.group(1) ?? '';
      final label = rawLabel.replaceAll(RegExp(r'\s+'), ' ').trim();
      links.add(
        ScrapedLink(
          title: label.isEmpty ? 'Mirror ${links.length + 1}' : label,
          url: url,
        ),
      );
    }
    return links;
  }

  /// Some nexdrive themes (ZeeFliz, Vega-City) move the final URL behind an
  /// embed redirector instead of linking the host page directly.
  static bool isEmbedRedirectUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('zee-dl.') || lower.contains('/embed.php?download=');
  }

  /// Reads the media URL the embed page keeps in `var reurl = "..."`.
  ///
  /// The value is a redirector (`/dl.php?link=<encoded final url>`); the
  /// `link` parameter is the stream itself.
  static String? extractRedirectTarget(String html) {
    final match = RegExp(
      r'''var\s+reurl\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) return null;

    final redirect = match.group(1)!.trim();
    Uri? uri;
    try {
      uri = Uri.parse(redirect);
    } catch (_) {
      return null;
    }
    final link = uri.queryParameters['link'];
    final candidate = (link ?? redirect).trim();
    if (!candidate.startsWith('http')) return null;
    return candidate;
  }

  /// Download buttons on a post page, labelled with the quality above each one.
  ///
  /// These themes print the release line as an `<h5>` and put the button in the
  /// paragraph after it:
  /// `<h5>… 1080p …</h5><p><a href="…"><button class="dwd-button">Download</button></a></p>`.
  /// The quality therefore comes from the window of text before the anchor.
  static List<ScrapedLink> parseEpisodeLinks(String html) {
    final links = <ScrapedLink>[];
    final seen = <String>{};

    void add(String url, String quality) {
      final cleaned = url.trim();
      if (!cleaned.startsWith('http')) return;
      if (!seen.add(cleaned)) return;
      links.add(
        ScrapedLink(
          title: quality == 'Auto' ? 'Download' : quality,
          url: cleaned,
        ),
      );
    }

    // Buttons first: they are the current theme.
    final buttonPattern = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["'][^>]*>\s*<button[^>]*class=["'][^"']*dwd-button''',
      caseSensitive: false,
    );
    for (final match in buttonPattern.allMatches(html)) {
      final url = match.group(1) ?? '';
      final start = match.start - 800 < 0 ? 0 : match.start - 800;
      add(
        url,
        StreamExtractors.guessQuality(html.substring(start, match.start)),
      );
    }

    if (links.isEmpty) {
      // Older posts link the mirror page directly with no button.
      final anchorPattern = RegExp(
        r'''<a\s+[^>]*href=["']([^"']*nexdrive[^"']*)["']''',
        caseSensitive: false,
      );
      for (final match in anchorPattern.allMatches(html)) {
        final url = match.group(1) ?? '';
        final start = match.start - 800 < 0 ? 0 : match.start - 800;
        add(
          url,
          StreamExtractors.guessQuality(html.substring(start, match.start)),
        );
      }
    }

    links.sort(
      (a, b) => HubCloudExtractor.qualityRank(
        b.title,
      ).compareTo(HubCloudExtractor.qualityRank(a.title)),
    );
    return links;
  }
}
