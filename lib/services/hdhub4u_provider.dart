import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'extractors/hubcloud_extractor.dart';
import 'extractors/stream_extractors.dart';
import 'extractors/typesense_search_parser.dart';
import 'media_provider_plugin.dart';
import 'provider_base_url_service.dart';

/// Quality-tagged drive link. Alias of the shared extractor type so callers
/// (and tests) keep their existing names.
typedef HdHubQualityLink = HubCloudQualityLink;

/// Final server link. Alias of the shared extractor type.
typedef HdHubServerLink = HubCloudServerLink;

/// Native provider for HDHub4u.
///
/// Two things make this port unusually tractable, and both come from reading the
/// reference implementation rather than guessing at the site:
///
///  * **Search is a JSON API** (Typesense), not HTML. That removes the most
///    fragile part of a scraper entirely.
///  * **The post page payload is the same base64 → base64 → rot13 → base64 → JSON
///    chain** already implemented and tested in [StreamExtractors], so the
///    obfuscation layer needed no new code.
///
/// The domains rotate, so the base URL comes from [ProviderBaseUrlService]
/// instead of being compiled in.
class HDHub4uProvider {
  HDHub4uProvider({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrlOverride = baseUrl;

  static const String providerId = 'hdhub4u';
  static const String providerKey = 'hdhub';

  /// Bundled fallback, used only when the domain map has no entry.
  static const String fallbackBaseUrl = 'https://new8.hdhub4u.cl';

  static const String searchEndpoint =
      'https://search.pingora.fyi/collections/post/documents/search';

  static const String browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0';

  final http.Client _client;
  final String? _baseUrlOverride;

  String get baseUrl {
    final resolved =
        _baseUrlOverride ??
        ProviderBaseUrlService.instance.baseUrlFor(
          providerKey,
          fallback: fallbackBaseUrl,
        );
    return resolved ?? fallbackBaseUrl;
  }

  Map<String, String> get _headers => {
    'Cookie': 'xla=s4t',
    'Referer': '$baseUrl/',
    'User-Agent': browserUa,
    'Accept': 'text/html,application/xhtml+xml,application/json,*/*',
  };

  // -------------------------------------------------------------------
  // Network
  // -------------------------------------------------------------------

  /// Searches via the site's Typesense index.
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(searchEndpoint).replace(
        queryParameters: {
          'q': trimmed,
          'query_by': 'post_title,category,stars,director,imdb_id',
          'query_by_weights': '4,2,2,2,4',
          'sort_by': 'sort_by_date:desc',
          'limit': '15',
          'highlight_fields': 'none',
          'use_cache': 'true',
          'page': '$page',
        },
      );

      final response = await _client
          .get(uri, headers: {..._headers, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[HDHub4u] search HTTP ${response.statusCode}');
      } else {
        final items = parseSearchResponse(
          utf8.decode(response.bodyBytes),
          baseUrl: baseUrl,
        );
        if (items.isNotEmpty) return items;
        // The JSON index is a third-party service; if it answers but knows
        // nothing, the site's own search page is the better source.
      }
    } catch (e) {
      debugPrint('[HDHub4u] search error: $e');
    }
    // Single fallback call, outside the try: an error in the HTML search should
    // surface instead of being swallowed and retried by the catch above.
    return searchViaHtml(trimmed, page: page);
  }

  /// Fallback search against the site's own `?s=` page.
  ///
  /// The primary search depends on an external index, which is the one piece of
  /// this provider that can disappear without the site changing at all.
  Future<List<MediaItem>> searchViaHtml(String query, {int page = 1}) async {
    try {
      final uri = Uri.parse('$baseUrl/').replace(queryParameters: {'s': query});
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final items = parsePostListing(response.body, baseUrl: baseUrl);
      if (items.isNotEmpty) {
        debugPrint(
          '[HDHub4u] Recovered ${items.length} results via HTML search.',
        );
      }
      return items;
    } catch (e) {
      debugPrint('[HDHub4u] HTML search fallback failed: $e');
      return [];
    }
  }

  /// Loads the site's home/listing grid.
  Future<List<MediaItem>> getCatalog({int page = 1}) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/page/$page/'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      return parsePostListing(response.body, baseUrl: baseUrl);
    } catch (e) {
      debugPrint('[HDHub4u] catalog error: $e');
      return [];
    }
  }

  /// Walks a post page through its obfuscation layers to the real links.
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    bool? isSeries,
  }) async {
    try {
      var pageUrl = subjectId.startsWith('http')
          ? subjectId
          : '$baseUrl${subjectId.startsWith('/') ? '' : '/'}$subjectId';

      var html = await _fetch(pageUrl);
      if (html == null) return [];

      // Layer 1: `var reurl = "..."` indirection.
      final reurl = parseReurlTarget(html);
      if (reurl != null) {
        final next = await _absolute(reurl, pageUrl);
        final fetched = await _fetch(next);
        if (fetched != null) {
          pageUrl = next;
          html = fetched;
        }
      }

      // Layer 2: s('o','<packed>') payload.
      final packedTarget = parsePackedPayloadTarget(html);
      if (packedTarget != null) {
        final next = await _absolute(packedTarget, pageUrl);
        final fetched = await _fetch(next);
        if (fetched != null) {
          pageUrl = next;
          html = fetched;
        }
      }

      // A direct CDN link needs no further resolution.
      final direct = parseR2DirectLink(html);
      if (direct != null) {
        return [_toStream(direct, server: 'HubCDN', quality: 'Auto')];
      }

      // Otherwise pick the best drive link and resolve it.
      final driveLinks = parseDriveLinks(html);
      if (driveLinks.isEmpty) return [];

      final best = driveLinks.first;
      final hubcloudHtml = await _fetch(await _absolute(best.url, pageUrl));
      if (hubcloudHtml == null) return [];

      final servers = sortServers(parseHubcloudServers(hubcloudHtml));
      return [
        for (final server in servers)
          _toStream(server.url, server: server.server, quality: best.quality),
      ];
    } catch (e) {
      debugPrint('[HDHub4u] getStreams error: $e');
      return [];
    }
  }

  Future<String?> _fetch(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('[HDHub4u] HTTP ${response.statusCode} for $url');
        return null;
      }
      return response.body;
    } catch (e) {
      debugPrint('[HDHub4u] fetch failed for $url: $e');
      return null;
    }
  }

  Future<String> _absolute(String maybeRelative, String pageUrl) async {
    if (maybeRelative.startsWith('http')) return maybeRelative;
    final base = Uri.tryParse(pageUrl);
    if (base == null) return maybeRelative;
    return base.resolve(maybeRelative).toString();
  }

  StreamSource _toStream(
    String url, {
    required String server,
    required String quality,
  }) {
    return StreamSource(
      quality: quality,
      resolution: StreamExtractors.resolutionForQuality(quality),
      format: StreamExtractors.guessFormat(url),
      url: url,
      headers: {'User-Agent': browserUa, 'Referer': '$baseUrl/'},
      server: server,
      providerId: providerId,
      providerName: 'HDHub4u',
    );
  }

  // -------------------------------------------------------------------
  // Pure parsers (no I/O), so they can be tested directly
  // -------------------------------------------------------------------

  /// Parses the Typesense search response.
  ///
  /// Delegates to the shared parser, which several of these sites use because
  /// they share a search backend.
  static List<MediaItem> parseSearchResponse(String body, {String? baseUrl}) {
    return TypesenseSearchParser.parse(
      body,
      baseUrl: baseUrl ?? fallbackBaseUrl,
      providerId: providerId,
    );
  }

  /// Parses the `.recent-movies` grid on listing pages.
  static List<MediaItem> parsePostListing(
    String html, {
    required String baseUrl,
  }) {
    final items = <MediaItem>[];
    final blockRegex = RegExp(
      r'''<a\s+[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );
    final imgRegex = RegExp(
      r'''<img\s+[^>]*(?:alt|src)=["']([^"']*)["'][^>]*>''',
      caseSensitive: false,
    );

    for (final match in blockRegex.allMatches(html)) {
      final href = match.group(1) ?? '';
      final inner = match.group(2) ?? '';
      final imgMatch = imgRegex.firstMatch(inner);
      if (imgMatch == null) continue;

      final alt = RegExp(
        r'''alt=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(inner)?.group(1);
      final src = RegExp(
        r'''src=["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(inner)?.group(1);
      if (alt == null || alt.trim().isEmpty) continue;

      final title = alt
          .replaceAll(RegExp('Download', caseSensitive: false), '')
          .trim();
      if (title.isEmpty) continue;

      final link = _relativeTo(baseUrl, href);
      items.add(
        MediaItem(
          id: link,
          title: title,
          mediaType: _mediaTypeFor(title),
          year: _yearFrom(title),
          posterUrl: src,
          provider: ProviderType.plugins,
          providerId: providerId,
        ),
      );
    }

    // A grid repeats each card's anchor; keep the first of each.
    final seen = <String>{};
    return items.where((item) => seen.add(item.id)).toList();
  }

  /// `var reurl = "https://..."` — an indirection to the real post URL.
  static String? parseReurlTarget(String html) {
    final match = RegExp(
      r'''var\s+reurl\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    final value = match?.group(1);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// Decodes the packed payload on a post page to the next URL.
  static String? parsePackedPayloadTarget(String html) {
    final payload = StreamExtractors.extractGreenmotorsPayload(html);
    if (payload == null) return null;
    return StreamExtractors.decodeGreenmotorsPayload(payload);
  }

  /// A direct `r2.dev` CDN link needs no further resolution.
  static String? parseR2DirectLink(String html) {
    final match = RegExp(
      r'''href=["']([^"']*r2\.dev[^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1);
  }

  /// Collects hubcloud/hubdrive drive links, best quality first.
  static List<HdHubQualityLink> parseDriveLinks(String html) =>
      HubCloudExtractor.parseDriveLinks(html);

  /// Final links on a HubCloud page, named by the host that serves them.
  static List<HdHubServerLink> parseHubcloudServers(String html) =>
      HubCloudExtractor.parseServers(html);

  /// Orders servers so the most useful source is tried first.
  static List<HdHubServerLink> sortServers(
    List<HdHubServerLink> servers, {
    bool forDownload = false,
  }) => HubCloudExtractor.sortServers(servers, forDownload: forDownload);
  static String _relativeTo(String? baseUrl, String href) {
    if (!href.startsWith('/')) return href;
    if (baseUrl == null || baseUrl.isEmpty) return href;
    return '$baseUrl$href';
  }

  static MediaType _mediaTypeFor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('season') ||
        lower.contains('series') ||
        RegExp(r'\bs\d{1,2}\b').hasMatch(lower)) {
      return MediaType.series;
    }
    return MediaType.movie;
  }

  static String? _yearFrom(String title) {
    final match = RegExp(r'\((19|20)\d{2}\)').firstMatch(title);
    if (match == null) return null;
    return match.group(0)!.replaceAll(RegExp(r'[()]'), '');
  }
}

/// Registry adapter so the scraper behaves like any other provider.
///
/// `supportsCatalogFeeds` is false on purpose: the listing grid is a
/// latest-additions page, not a category feed, and advertising it as a catalogue
/// would make Home source its shelves from a site whose order changes daily.
class HDHub4uPlugin extends MediaProviderPlugin {
  HDHub4uPlugin({HDHub4uProvider? provider})
    : _provider = provider ?? HDHub4uProvider();

  final HDHub4uProvider _provider;

  @override
  String get id => HDHub4uProvider.providerId;

  @override
  String get name => 'HDHub4u';

  /// Lower than the metadata catalogues: scraped sources are slower and can move.
  @override
  int get priority => 60;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  /// Resolves a post page straight to a stream; there is no metadata endpoint.
  @override
  bool get supportsMetadata => false;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _provider.getCatalog(page: page);

  /// Not implemented: the search index already returns everything the poster
  /// grid shows, and a second HTML parse would only add another failure point.
  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    int? season,
    int? episode,
    String? imdbId,
    String? originProviderId,
    bool? isSeries,
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    isSeries: isSeries,
  );
}
