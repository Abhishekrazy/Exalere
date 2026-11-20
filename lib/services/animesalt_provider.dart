import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/extractors/zypter_extractor.dart';
import '../services/media_provider_plugin.dart';

/// AnimeSalt — Hindi-dubbed anime, ported from Vega's `animesalt` provider.
///
/// The site is server-rendered: series cards link `/series/<slug>`, a series
/// page lists `/episode/<slug>` pages, and an episode page embeds a
/// Zypter/ZephyrFlick player whose data endpoint answers with the signed HLS
/// playlist (see [ZypterExtractor]).
class AnimeSaltProvider extends MediaProviderPlugin {
  AnimeSaltProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://animesalt.in';

  static const String _ua =
      'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/154.0.0.0 Mobile Safari/537.36';

  @override
  String get id => 'animesalt';

  @override
  String get name => providerNameOverride ?? 'AnimeSalt';

  @override
  int get priority => 59;

  @override
  bool get supportsMovies => false;

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
    ProviderCatalogRow(id: 'latest', title: 'Latest on AnimeSalt'),
  ];

  /// Series cards (`/series/<slug>`) with the nearest image as their poster.
  static List<MediaItem> parseSeries(String html, {String? query}) {
    final document = html_parser.parse(html);
    final items = <MediaItem>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href*="/series/"]')) {
      final href = anchor.attributes['href'] ?? '';
      final uri = Uri.tryParse(href);
      if (uri == null) continue;
      final slug = uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (slug.isEmpty || !seen.add(slug)) continue;

      // The card's image is a sibling of the play anchor, so look up to three
      // ancestors for the poster instead of inside the anchor only.
      dom.Element? container = anchor;
      dom.Element? imageElement;
      for (var depth = 0; depth < 3 && container != null; depth++) {
        imageElement = container.querySelector('img');
        if (imageElement != null) break;
        final parent = container.parent;
        if (parent == null) break;
        // Stop before a shared grid: it would lend this card a neighbour's
        // poster.
        final anchors = parent.querySelectorAll('a[href*="/series/"]');
        if (anchors.length > 1) break;
        container = parent;
      }
      final image = imageElement?.attributes['src'];
      final alt = imageElement?.attributes['alt'] ?? '';
      var title = anchor.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      title = title
          .replaceFirst(RegExp(r'PLAY\s*NOW$', caseSensitive: false), '')
          .trim();
      if (title.isEmpty) title = alt;
      if (title.isEmpty) title = slug.replaceAll('-', ' ');

      items.add(
        MediaItem(
          id: '${uri.pathSegments.firstWhere((s) => s.isNotEmpty)}/$slug',
          title: title,
          mediaType: MediaType.series,
          posterUrl: image == null || image.isEmpty ? null : image,
          providerId: 'animesalt',
        ),
      );
    }
    return items;
  }

  /// Episode slugs from a series page, ordered as printed.
  static List<String> parseEpisodeSlugs(String html) {
    final document = html_parser.parse(html);
    final slugs = <String>[];
    for (final anchor in document.querySelectorAll('a[href*="/episode/"]')) {
      final href = anchor.attributes['href'] ?? '';
      final uri = Uri.tryParse(href);
      if (uri == null) continue;
      final slug = uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (slug.isNotEmpty && !slugs.contains(slug)) slugs.add(slug);
    }
    return slugs;
  }

  static String? parseSeriesTitle(String html) {
    final document = html_parser.parse(html);
    for (final selector in ['h1', 'h2', '.title', '.anime-title']) {
      final text = document.querySelector(selector)?.text;
      final cleaned = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  static List<String> parseIframes(String html) {
    final document = html_parser.parse(html);
    final urls = <String>[];
    for (final frame in document.querySelectorAll('iframe')) {
      final src = frame.attributes['data-src'] ?? frame.attributes['src'] ?? '';
      if (src.startsWith('http') && !urls.contains(src)) urls.add(src);
    }
    return urls;
  }

  Future<String?> _get(String url) async {
    // The site drops a small share of requests; one retry turns an empty Home
    // row into a populated one.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _client
            .get(
              Uri.parse(url),
              headers: {
                'User-Agent': _ua,
                'Accept': 'text/html,application/xhtml+xml',
                'Referer': '$baseUrl/',
              },
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 200) return response.body;
      } catch (_) {
        // fall through to the retry
      }
      // Back off between attempts: the site throttles bursts.
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    return null;
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final html = await _get('$baseUrl/?s=${Uri.encodeQueryComponent(trimmed)}');
    if (html == null) return const [];
    return parseSeries(html, query: trimmed);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final html = await _get(page > 1 ? '$baseUrl/page/$page/' : '$baseUrl/');
    if (html == null) return const [];
    return parseSeries(html);
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final slug = id.split('/').last;
    final html = await _get('$baseUrl/series/$slug');
    if (html == null) return null;

    final episodeSlugs = parseEpisodeSlugs(html);
    final title = parseSeriesTitle(html) ?? slug.replaceAll('-', ' ');
    return MediaDetails(
      id: id,
      title: title,
      mediaType: MediaType.series,
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: episodeSlugs.length,
          episodes: [
            for (final episode in episodeSlugs)
              Episode(
                season: 1,
                episode: episodeSlugs.indexOf(episode) + 1,
                title: _episodeTitle(episode),
              ),
          ],
        ),
      ],
    );
  }

  /// `one-piece-1x12` → `Episode 12`.
  static String _episodeTitle(String slug) {
    final match = RegExp(r'(\d+)x(\d+)$').firstMatch(slug);
    if (match == null) return slug;
    return 'Episode ${match.group(2)}';
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
    final slug = subjectId.split('/').last;
    final seriesHtml = await _get('$baseUrl/series/$slug');
    if (seriesHtml == null) return const [];

    final episodeSlugs = parseEpisodeSlugs(seriesHtml);
    if (episodeSlugs.isEmpty) return const [];
    final wanted = episode ?? 1;
    final episodeSlug = episodeSlugs.length >= wanted
        ? episodeSlugs[wanted - 1]
        : episodeSlugs.first;

    final episodeHtml = await _get('$baseUrl/episode/$episodeSlug');
    if (episodeHtml == null) return const [];

    final results = <StreamSource>[];
    // The site throttles bursts; a second pass turns a dropped player request
    // into a working episode instead of an empty sheet.
    for (var pass = 0; pass < 2 && results.isEmpty; pass++) {
      if (pass > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      for (final frame in parseIframes(episodeHtml)) {
        if (!ZypterExtractor.isZypterHost(frame)) continue;
        final playlist = await ZypterExtractor.resolveUrl(
          frame,
          client: _client,
        );
        if (playlist == null) continue;
        final origin = Uri.tryParse(frame)?.origin ?? baseUrl;
        results.add(
          StreamSource(
            quality: 'Auto',
            resolution: '',
            format: playlist.contains('.m3u8') || playlist.contains('/hls/')
                ? 'HLS'
                : 'MP4',
            url: playlist,
            headers: {
              'User-Agent': ZypterExtractor.userAgent,
              'Referer': origin,
              'Origin': origin,
            },
            server: 'AnimeSalt',
            providerId: 'animesalt',
            providerName: name,
          ),
        );
      }
    }
    return results;
  }
}
