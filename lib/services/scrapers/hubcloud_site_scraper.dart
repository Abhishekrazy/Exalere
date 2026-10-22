import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../extractors/html_grid_parser.dart';
import '../extractors/hubcloud_extractor.dart';
import '../extractors/stream_extractors.dart';
import '../provider_base_url_service.dart';

/// Base for sites whose downloads end at HubCloud.
///
/// These sites differ only in their domain, search path and listing theme; the
/// resolution tail is identical. Putting the shared half here means a new site is
/// a short subclass rather than another few hundred lines, and fixes land once.
///
/// Shortlink gates (`thenaukriadda`, `_wp_http`, DriveSeed and friends) are
/// deliberately unsupported: each is a stateful multi-request exchange that
/// cannot be verified without the live site, and a guessed implementation would
/// fail silently. Gated links are detected and skipped, so the provider reports
/// honestly through the self-test instead of the app claiming a stream exists.
abstract class HubCloudSiteScraper {
  HubCloudSiteScraper({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrlOverride = baseUrl;

  final http.Client _client;
  final String? _baseUrlOverride;

  /// Key into the remote domain map.
  String get domainKey;

  /// Stable provider identifier, also used in item ids.
  String get providerId;

  /// Human-readable name shown on stream sources.
  String get displayName;

  /// Bundled fallback used only when the domain map has no entry.
  String get fallbackBaseUrl;

  /// Path for a search query. Overridden by sites with a different scheme.
  String searchPath(String encodedQuery, int page) =>
      '/search/$encodedQuery/page/$page/';

  /// Path for a listing page.
  String catalogPath(int page) => '/page/$page/';

  String get baseUrl {
    final resolved =
        _baseUrlOverride ??
        ProviderBaseUrlService.instance.baseUrlFor(
          domainKey,
          fallback: fallbackBaseUrl,
        );
    return resolved ?? fallbackBaseUrl;
  }

  Map<String, String> get headers => {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,*/*',
  };

  // -------------------------------------------------------------------
  // Discovery
  // -------------------------------------------------------------------

  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final html = await fetch(
        '$baseUrl${searchPath(Uri.encodeComponent(trimmed), page)}',
      );
      if (html == null) return [];
      return parseListingResilient(html);
    } catch (e) {
      debugPrint('[$displayName] search error: $e');
      return [];
    }
  }

  Future<List<MediaItem>> getCatalog({int page = 1}) async {
    try {
      final html = await fetch('$baseUrl${catalogPath(page)}');
      if (html == null) return [];
      return parseListingResilient(html);
    } catch (e) {
      debugPrint('[$displayName] catalog error: $e');
      return [];
    }
  }

  /// Parses a listing page into catalogue items.
  ///
  /// Overridden by sites whose cards are not `a[title]` anchors.
  List<MediaItem> parseListingHtml(String html) =>
      HubCloudSiteScraper.parseListing(
        html,
        baseUrl: baseUrl,
        providerId: providerId,
      );

  /// Parses a listing, falling back to the generic card parser when the
  /// site-specific one finds nothing.
  ///
  /// These sites change theme without warning, and a theme change is exactly
  /// what silently empties a provider. Trying the generic `a[title]` reader as a
  /// second pass costs nothing when the primary works, and rescues the provider
  /// when the theme moves out from under it.
  List<MediaItem> parseListingResilient(String html) {
    final primary = parseListingHtml(html);
    if (primary.isNotEmpty) return primary;

    final fallback = HubCloudSiteScraper.parseListing(
      html,
      baseUrl: baseUrl,
      providerId: providerId,
    );
    if (fallback.isNotEmpty) {
      debugPrint(
        '[$displayName] Site-specific listing parser found nothing; '
        'recovered ${fallback.length} cards via the generic parser.',
      );
    }
    return fallback;
  }

  // -------------------------------------------------------------------
  // Resolution
  // -------------------------------------------------------------------

  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    bool? isSeries,
  }) async {
    try {
      final pageUrl = subjectId.startsWith('http')
          ? subjectId
          : '$baseUrl${subjectId.startsWith('/') ? '' : '/'}$subjectId';

      if (pageUrl.contains('hubcloud')) {
        final html = await fetch(pageUrl);
        if (html == null) return [];
        return streamsFromServers(
          HubCloudExtractor.sortServers(HubCloudExtractor.parseServers(html)),
          quality: 'Auto',
        );
      }

      if (HubCloudExtractor.isDirectMedia(pageUrl)) {
        return [toStream(pageUrl, server: 'Direct', quality: 'Auto')];
      }

      if (isShortlinkGated(pageUrl)) {
        debugPrint('[$displayName] Skipping unsupported gate: $pageUrl');
        return [];
      }

      final html = await fetch(pageUrl);
      if (html == null) return [];

      final links = HubCloudExtractor.parseEpisodeLinks(html);
      if (links.isEmpty) return [];

      final results = <StreamSource>[];
      for (final link in links) {
        results.addAll(await resolveLink(link.url, quality: link.title));
      }
      return dedupe(results);
    } catch (e) {
      debugPrint('[$displayName] getStreams error: $e');
      return [];
    }
  }

  Future<List<StreamSource>> resolveLink(
    String url, {
    required String quality,
  }) async {
    final label = StreamExtractors.guessQuality(quality);

    if (HubCloudExtractor.isDirectMedia(url)) {
      return [toStream(url, server: 'Direct', quality: label)];
    }

    if (url.contains('hubcloud')) {
      final html = await fetch(url);
      if (html == null) return [];
      return streamsFromServers(
        HubCloudExtractor.sortServers(HubCloudExtractor.parseServers(html)),
        quality: label,
      );
    }

    if (isShortlinkGated(url)) {
      debugPrint('[$displayName] Skipping gated link: $url');
      return [];
    }

    return [];
  }

  List<StreamSource> streamsFromServers(
    List<HubCloudServerLink> servers, {
    required String quality,
  }) {
    return [
      for (final server in servers)
        toStream(server.url, server: server.server, quality: quality),
    ];
  }

  StreamSource toStream(
    String url, {
    required String server,
    required String quality,
  }) {
    return StreamSource(
      quality: quality,
      resolution: StreamExtractors.resolutionForQuality(quality),
      format: StreamExtractors.guessFormat(url),
      url: url,
      headers: {'User-Agent': headers['User-Agent']!, 'Referer': '$baseUrl/'},
      server: server,
      providerId: providerId,
      providerName: displayName,
    );
  }

  List<StreamSource> dedupe(List<StreamSource> streams) {
    final seen = <String>{};
    return streams.where((s) => seen.add(s.url)).toList();
  }

  Future<String?> fetch(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('[$displayName] HTTP ${response.statusCode} for $url');
        return null;
      }
      return response.body;
    } catch (e) {
      debugPrint('[$displayName] fetch failed for $url: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Shared statics
  // -------------------------------------------------------------------

  /// Parses a listing grid into catalogue items.
  static List<MediaItem> parseListing(
    String html, {
    required String baseUrl,
    required String providerId,
  }) {
    return HtmlGridParser.toMediaItems(
      HtmlGridParser.parse(html, baseUrl: baseUrl),
      providerId: providerId,
    );
  }

  /// True when a URL sits behind a shortlink gate this app does not solve.
  static bool isShortlinkGated(String url) {
    final lower = url.toLowerCase();
    return lower.contains('thenaukriadda') ||
        lower.contains('sid=') ||
        lower.contains('_wp_http') ||
        lower.contains('driveseed') ||
        lower.contains('driveleech') ||
        lower.contains('appdrive') ||
        lower.contains('gdflix') ||
        lower.contains('unblockedgames') ||
        lower.contains('leechpro');
  }
}
