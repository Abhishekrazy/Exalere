import 'dart:convert';

import '../models/media_item.dart';
import 'extractors/hubcloud_extractor.dart';
import 'extractors/nexdrive_extractor.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// VegaMovies, ported against its WordPress REST API.
///
/// The home page is a hero slider of partner links, so scraping the listing
/// yields no cards — but `/wp-json/wp/v2/posts` serves the same catalogue as
/// JSON, with a poster (`fifu_image_url`) and a real search route
/// (`?search=`). That is why this site is not catalogue-only like GokuHD.
class VegaMoviesProvider extends HubCloudSiteScraper {
  VegaMoviesProvider({super.client, super.baseUrl});

  @override
  String get domainKey => 'vega';

  @override
  String get providerId => 'vegamovies';

  @override
  String get displayName => 'VegaMovies';

  @override
  String get fallbackBaseUrl => 'https://vegamovies.latino';

  /// Its posts carry a handful of mirrors that answer quickly; the default walk
  /// only added dead ones and pushed a foreign-title resolve past ten seconds.
  @override
  Duration get streamBudget => const Duration(seconds: 9);

  @override
  String searchPath(String encodedQuery, int page) =>
      '/wp-json/wp/v2/posts?search=$encodedQuery&per_page=20&page=$page';

  @override
  String catalogPath(int page) => '/wp-json/wp/v2/posts?per_page=20&page=$page';

  @override
  Map<String, String> get headers => {
    ...super.headers,
    'Accept': 'application/json,text/html,*/*',
  };

  /// Post pages carry `nexdrive` mirrors; the HubCloud extractor covers the
  /// occasional direct link.
  @override
  List<ScrapedLink> parseEpisodeLinks(String html) => [
    ...NexdriveExtractor.parseEpisodeLinks(html),
    ...HubCloudExtractor.parseEpisodeLinks(html),
  ];

  @override
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    return _fetchJson(searchPath(Uri.encodeComponent(trimmed), page));
  }

  @override
  Future<List<MediaItem>> getCatalog({int page = 1}) async =>
      _fetchJson(catalogPath(page));

  /// One retry: the REST route occasionally answers with an empty body under
  /// load (a cached 429 page, in effect), which would blank the Home row.
  Future<List<MediaItem>> _fetchJson(String path) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final items = parseListingJson(await fetch('$baseUrl$path'));
      if (items.isNotEmpty) return items;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return const [];
  }

  /// Turns a `/wp-json/wp/v2/posts` payload into cards.
  ///
  /// Kept static and pure so the parser is tested against a recorded payload
  /// instead of the live site.
  static List<MediaItem> parseListingJson(String? body) {
    if (body == null || body.trim().isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];

    final items = <MediaItem>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final link = (entry['link'] as String?)?.trim();
      if (link == null || link.isEmpty) continue;

      final title = cleanTitle(
        (entry['title'] as Map?)?['rendered'] as String? ?? '',
      );
      if (title.isEmpty) continue;

      items.add(
        MediaItem(
          id: link,
          title: title,
          posterUrl: posterFor(entry),
          year: yearFrom(title),
          mediaType: looksLikeSeries(title)
              ? MediaType.series
              : MediaType.movie,
          providerId: 'vegamovies',
        ),
      );
    }
    return items;
  }

  /// Poster from the `fifu` plugin, falling back to Yoast's og:image.
  static String posterFor(Map<Object?, Object?> entry) {
    final direct = (entry['fifu_image_url'] as String?)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final yoast = entry['yoast_head_json'];
    if (yoast is Map) {
      final images = yoast['og_image'];
      if (images is List) {
        for (final image in images) {
          if (image is Map && image['url'] is String) {
            return image['url'] as String;
          }
        }
      }
    }
    return '';
  }

  /// Strips tags, entities and the `Download ` prefix these titles all carry.
  static String cleanTitle(String raw) {
    final text = raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&#0?39;|&quot;|&#8220;|&#8221;'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.startsWith('Download ') ? text.substring(9).trim() : text;
  }

  static String? yearFrom(String title) =>
      RegExp(r'\((\d{4})\)').firstMatch(title)?.group(1);

  static bool looksLikeSeries(String title) {
    final lowered = title.toLowerCase();
    return lowered.contains('season') ||
        lowered.contains('series') ||
        lowered.contains('episode');
  }
}
