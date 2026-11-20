import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../extractors/html_grid_parser.dart';
import '../extractors/cineverse_extractor.dart';
import '../extractors/hubcloud_extractor.dart';
import '../extractors/nexdrive_extractor.dart';
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

  /// How long one page fetch may take. Sites behind a worker proxy answer
  /// slower than a plain host, and a 10 s cut-off turns them into a flaky
  /// "no search hit" in the self-test.
  Duration get fetchTimeout => const Duration(seconds: 10);

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

  /// Reads the labelled links a post page offers.
  ///
  /// Overridden by sites whose download buttons are not heading anchors; the
  /// default reader covers the `<h3><a>` and `.maxbutton` themes.
  List<ScrapedLink> parseEpisodeLinks(String html) =>
      HubCloudExtractor.parseEpisodeLinks(html);

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
        return await streamsFromHubCloudPage(html, quality: 'Auto');
      }

      if (HubCloudExtractor.isVCloudUrl(pageUrl)) {
        return await streamsFromVCloudPage(pageUrl, quality: 'Auto');
      }

      if (NexdriveExtractor.isNexdriveUrl(pageUrl)) {
        return await streamsFromNexdrivePage(pageUrl, quality: 'Auto');
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

      final links = linksToTry(parseEpisodeLinks(html));
      final results = <StreamSource>[];
      final qualities = <String>{};
      // Wall-clock budget: eight mirrors x four servers x a 10 s hop each can
      // outlive the registry's 20 s and leave the user with nothing. Stop
      // asking once the answer is good enough to play.
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      for (final link in links) {
        if (DateTime.now().isAfter(deadline)) {
          debugPrint('[$displayName] stream budget spent, using what resolved');
          break;
        }
        results.addAll(await resolveLink(link.url, quality: link.title));
        qualities.addAll(results.map((stream) => stream.quality));
        // Enough choice: four distinct qualities is what the server sheet
        // offers. Breaking on the raw source count cut a 480p entry that a
        // 1080p page had already outnumbered with its own mirrors.
        if (qualities.length >= 4) break;
      }

      if (results.isEmpty) {
        // Sites like MultiMovies only print their players as iframe src URLs.
        for (final embed in CineverseExtractor.collectEmbedUrls(html).take(2)) {
          results.addAll(await resolveLink(embed, quality: 'Auto'));
        }
      }
      return dedupe(results);
    } catch (e) {
      debugPrint('[$displayName] getStreams error: $e');
      return [];
    }
  }

  /// The links worth resolving from a post page.
  ///
  /// Season pages can print a hundred mirrored links for one title; the picker
  /// only needs a few, and every extra one costs a network round trip.
  static List<ScrapedLink> linksToTry(List<ScrapedLink> links, {int max = 8}) {
    final seen = <String>{};
    final picked = <ScrapedLink>[];
    for (final link in links) {
      if (!seen.add(link.url)) continue;
      picked.add(link);
      if (picked.length >= max) break;
    }
    return picked;
  }

  /// Resolves the servers a nexdrive mirror page offers.
  ///
  /// Each server is taken in turn: V-Cloud/HubCloud pages carry the signed CDN
  /// URL, and the rest are direct hosts. A mirror page that exposes none (a
  /// timer or rotation step) yields nothing rather than a guessed link.
  Future<List<StreamSource>> streamsFromNexdrivePage(
    String url, {
    required String quality,
  }) async {
    final html = await fetch(url);
    if (html == null) return [];

    final servers = NexdriveExtractor.parseServerLinks(html);
    final results = <StreamSource>[];
    for (final server in servers.take(4)) {
      results.addAll(await resolveLink(server.url, quality: quality));
    }
    return dedupe(results);
  }

  /// Resolves a V-Cloud page by decoding the URL it keeps in `atob(atob(…))`.
  ///
  /// The decoded URL is the page's own token link; loading it returns the page
  /// that finally carries the CDN anchors.
  Future<List<StreamSource>> streamsFromVCloudPage(
    String url, {
    required String quality,
  }) async {
    final html = await fetch(url);
    if (html == null) return [];

    final tokenUrl = HubCloudExtractor.decodeDoubleAtob(html);
    if (tokenUrl == null) {
      debugPrint('[$displayName] V-Cloud page carried no decodable URL: $url');
      return [];
    }

    final page = await fetch(tokenUrl);
    if (page == null) return [];

    final servers = HubCloudExtractor.sortServers(
      HubCloudExtractor.parseServers(page),
    );
    if (servers.isNotEmpty) {
      return streamsFromServers(servers, quality: quality);
    }

    // Some mirrors write the CDN URL into a script rather than an anchor.
    final direct = RegExp(
      r'''https?://[^"'\s<>]+\.r2\.dev/[^"'\s<>]+''',
      caseSensitive: false,
    ).firstMatch(page)?.group(0);
    if (direct != null) {
      return [toStream(direct, server: 'R2 CDN', quality: quality)];
    }
    return [];
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
      return streamsFromHubCloudPage(html, quality: label);
    }

    if (HubCloudExtractor.isVCloudUrl(url)) {
      return await streamsFromVCloudPage(url, quality: label);
    }

    if (url.toLowerCase().contains('linkshub.')) {
      // LinkHub pages list the real mirrors (HubDrive/HubCloud) behind an
      // intermediate view page, plain HTML and no captcha.
      final html = await fetch(url);
      if (html == null) return [];
      final mirrors = NexdriveExtractor.parseServerLinks(html);
      final found = <StreamSource>[];
      for (final mirror in mirrors.take(4)) {
        found.addAll(await resolveLink(mirror.url, quality: label));
      }
      if (found.isNotEmpty) return dedupe(found);
      final direct = HubCloudExtractor.parseEpisodeLinks(html);
      for (final link in direct.take(4)) {
        found.addAll(await resolveLink(link.url, quality: label));
      }
      return dedupe(found);
    }

    if (CineverseExtractor.isCineverseUrl(url)) {
      final playlists = await CineverseExtractor.resolve(
        url,
        fetchPage: (embed, embedHeaders) =>
            fetch(embed, extraHeaders: embedHeaders),
      );
      return playlists
          .map(
            (playlist) => toStream(
              playlist,
              server: 'Cineverse',
              quality: label,
              streamHeaders: {
                'User-Agent': CineverseExtractor.mobileUa,
                'Referer': CineverseExtractor.refererHub,
                'Origin': 'https://rozgarlelo.modiplay.xyz',
              },
            ),
          )
          .toList();
    }

    if (NexdriveExtractor.isEmbedRedirectUrl(url)) {
      final html = await fetch(url);
      if (html == null) return [];
      final target = NexdriveExtractor.extractRedirectTarget(html);
      if (target == null) {
        debugPrint(
          '[$displayName] embed page carried no redirect target: $url',
        );
        return [];
      }
      if (HubCloudExtractor.isDirectMedia(target) ||
          target.contains('googleusercontent.com') ||
          target.contains('.mp4') ||
          target.contains('.mkv')) {
        return [toStream(target, server: 'Direct', quality: label)];
      }
      return resolveLink(target, quality: quality);
    }

    if (NexdriveExtractor.isNexdriveUrl(url)) {
      return await streamsFromNexdrivePage(url, quality: label);
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

  /// Resolves a HubCloud page into streams, taking the download-button hop when
  /// the page itself carries no streamable CDN link.
  ///
  /// Current mirrors hide the file behind a proxy endpoint that mints a signed
  /// R2 URL, so the page's own anchors are only a fallback — and they are often
  /// just navigation (a link back to the HubCloud home counts as "download
  /// only"), which is why the mint is tried whenever nothing streamable is found.
  Future<List<StreamSource>> streamsFromHubCloudPage(
    String html, {
    required String quality,
  }) async {
    var servers = HubCloudExtractor.parseServers(html);

    if (!servers.any((server) => !server.isDownloadOnly)) {
      final endpoint = HubCloudExtractor.findDownloadEndpoint(html);
      if (endpoint != null) {
        final minted = await fetch(endpoint);
        if (minted != null) {
          final resolved = HubCloudExtractor.parseServers(minted);
          if (resolved.isNotEmpty) servers = resolved;
        }
      }
    }

    return streamsFromServers(
      HubCloudExtractor.sortServers(servers),
      quality: quality,
    );
  }

  StreamSource toStream(
    String url, {
    required String server,
    required String quality,
    Map<String, String>? streamHeaders,
  }) {
    return StreamSource(
      quality: quality,
      resolution: StreamExtractors.resolutionForQuality(quality),
      format: StreamExtractors.guessFormat(url),
      url: url,
      headers:
          streamHeaders ??
          {'User-Agent': headers['User-Agent']!, 'Referer': '$baseUrl/'},
      server: server,
      providerId: providerId,
      providerName: displayName,
    );
  }

  List<StreamSource> dedupe(List<StreamSource> streams) {
    final seen = <String>{};
    return streams.where((s) => seen.add(s.url)).toList();
  }

  Future<String?> fetch(String url, {Map<String, String>? extraHeaders}) async {
    try {
      final merged = extraHeaders == null
          ? headers
          : <String, String>{...headers, ...extraHeaders};
      final response = await _client
          .get(Uri.parse(url), headers: merged)
          // A hop that has not answered in 10 s is not going to help a TV
          // viewer: the registry gives the whole provider 20 s.
          .timeout(fetchTimeout);
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
