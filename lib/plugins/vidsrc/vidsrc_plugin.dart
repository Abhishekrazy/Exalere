import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import '../../services/tmdb_service.dart';

/// Modular VidSrc streaming and discovery plugin for Exalere.
///
/// Implements [MediaProviderPlugin] with:
/// - Real-time discovery feeds from https://vidsrc.sh/movies/latest/ and /tvshows/latest/
/// - TMDB-augmented search with VidSrc availability verification via /info/
/// - Multi-mirror stream generation with query params (autoplay, subtitles, autonext)
class VidSrcPlugin extends MediaProviderPlugin {
  final ExalerePluginConfig? config;
  final http.Client _client;

  VidSrcPlugin({this.config, http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => config?.id ?? 'vidsrc';

  @override
  String get name => config?.name ?? 'VidSrc Engine';

  @override
  int get priority => 75;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  static const String _primaryBase = 'https://vidsrc.sh';

  final List<String> _baseMirrors = const [
    'https://vidsrc.sh',
    'https://vidsrcme.ru',
    'https://vidsrcme.su',
    'https://vidsrc-me.ru',
    'https://vidsrc-me.su',
    'https://vidsrc-embed.ru',
    'https://vidsrc-embed.su',
    'https://vsrc.su',
    'https://vidsrc2.ru',
  ];

  @override
  Future<void> init() async {
    debugPrint(
      '[$name] Initialized provider endpoints (${_baseMirrors.length} mirrors)',
    );
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final isSeries = category == 'series' || category == 'tv';
    final endpoint = isSeries
        ? '$_primaryBase/tvshows/latest/page-$page.json'
        : '$_primaryBase/movies/latest/page-$page.json';

    try {
      final response = await _client
          .get(
            Uri.parse(endpoint),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      final data = json.decode(utf8.decode(response.bodyBytes));
      final results = data['result'] as List<dynamic>? ?? [];

      final items = <MediaItem>[];
      for (final entry in results) {
        if (entry is! Map<String, dynamic>) continue;
        final rawTitle =
            (entry['title'] ?? entry['show_title'] ?? '') as String;
        if (rawTitle.isEmpty) continue;

        final imdbId = entry['imdb_id'] as String?;
        final tmdbId = entry['tmdb_id']?.toString();
        final effectiveId = tmdbId ?? imdbId ?? rawTitle;

        // Parse year from title if present (e.g., "Iron Man 3 2013")
        String title = rawTitle;
        String? year;
        final match = RegExp(
          r'^(.*?)\s*\(?(\d{4})\)?$',
        ).firstMatch(rawTitle.trim());
        if (match != null) {
          title = match.group(1)?.trim() ?? rawTitle;
          year = match.group(2);
        }

        // Poster URL: if TMDB id exists, use TMDB poster fallback or load later
        String? posterUrl;
        if (entry['poster'] != null && (entry['poster'] as String).isNotEmpty) {
          posterUrl = entry['poster'] as String;
        }

        items.add(
          MediaItem(
            id: effectiveId,
            title: title,
            year: year,
            mediaType: isSeries ? MediaType.series : MediaType.movie,
            posterUrl: posterUrl,
            provider: ProviderType.plugins,
            providerId: id,
          ),
        );
      }

      return items;
    } catch (e) {
      debugPrint('[$name] Failed to fetch catalog feed ($endpoint): $e');
      return [];
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Search candidates via TMDB catalog
      final tmdb = TmdbService();
      final candidates = await tmdb.searchMulti(cleanQuery);
      if (candidates.isEmpty) return [];

      // 2. Verify availability on VidSrc in parallel
      final verifiedItems = <MediaItem>[];
      final checks = await Future.wait(
        candidates.take(8).map((candidate) async {
          final isSeries = candidate.isSeries;
          final checkUrl = isSeries
              ? '$_primaryBase/info/tv/${candidate.id}.json'
              : '$_primaryBase/info/movie/${candidate.id}.json';

          try {
            final resp = await _client
                .get(
                  Uri.parse(checkUrl),
                  headers: {'User-Agent': 'Mozilla/5.0'},
                )
                .timeout(const Duration(seconds: 4));

            if (resp.statusCode == 200) {
              return candidate.copyWith(
                provider: ProviderType.plugins,
                providerId: id,
              );
            }
          } catch (_) {}
          return null;
        }),
      );

      for (final item in checks) {
        if (item != null) verifiedItems.add(item);
      }

      return verifiedItems.isNotEmpty
          ? verifiedItems
          : candidates.take(4).toList();
    } catch (e) {
      debugPrint('[$name] Search error: $e');
      return [];
    }
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    try {
      // Check movie or TV info endpoint
      for (final type in ['movie', 'tv']) {
        final url = '$_primaryBase/info/$type/$id.json';
        final resp = await _client
            .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
            .timeout(const Duration(seconds: 6));

        if (resp.statusCode == 200) {
          final data = json.decode(utf8.decode(resp.bodyBytes));
          final isTv = data['type'] == 'tv';
          final title = (data['title'] ?? '') as String;
          final year = data['year']?.toString();
          final poster = data['poster'] as String?;
          final rating = (data['imdb_rating'] as num?)?.toDouble();

          final seasons = <Season>[];
          if (isTv && data['seasons'] is List) {
            for (final s in data['seasons']) {
              final sNum = s['season'] as int? ?? 1;
              final epCount = s['episodes'] as int? ?? 1;
              final eps = <Episode>[];
              for (int ep = 1; ep <= epCount; ep++) {
                eps.add(
                  Episode(season: sNum, episode: ep, title: 'Episode $ep'),
                );
              }
              seasons.add(
                Season(
                  seasonNumber: sNum,
                  episodeCount: epCount,
                  episodes: eps,
                ),
              );
            }
          }

          return MediaDetails(
            id: id,
            title: title,
            mediaType: isTv ? MediaType.series : MediaType.movie,
            year: year,
            posterUrl: poster,
            imdbRating: rating?.toString(),
            seasons: seasons,
            provider: ProviderType.plugins,
          );
        }
      }
    } catch (e) {
      debugPrint('[$name] getDetails error: $e');
    }
    return null;
  }

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
  }) async {
    final List<StreamSource> sources = [];
    final effectiveIsSeries = isSeries ?? (season != null && season > 0);

    // 1. Determine effective content ID (prefer IMDb ID tt..., fallback to TMDB lookup if foreign slug)
    String contentId = subjectId;
    if (imdbId != null && imdbId.isNotEmpty && imdbId.startsWith('tt')) {
      contentId = imdbId;
    } else if (subjectId.startsWith('tt')) {
      contentId = subjectId;
    } else if (title != null && title.trim().isNotEmpty) {
      try {
        final tmdb = await TmdbService().getEnrichedDetails(
          title: title,
          year: year,
          isSeries: effectiveIsSeries,
          tmdbId: int.tryParse(subjectId),
        );
        if (tmdb?.imdbId != null && tmdb!.imdbId!.startsWith('tt')) {
          contentId = tmdb.imdbId!;
        } else if (tmdb?.id != null) {
          contentId = tmdb!.id.toString();
        }
      } catch (e) {
        debugPrint('[$name] TMDB enrichment lookup failed: $e');
      }
    }

    // Do not attempt embed urls with raw unparseable slugs like /neagley-series-8117/
    if (contentId.startsWith('/') || contentId.contains(' ')) {
      return [];
    }

    // Check available quality from VidSrc /info/ endpoint
    String qualityLabel = '1080p';
    try {
      final infoUrl = effectiveIsSeries
          ? '$_primaryBase/info/tv/$contentId/$season/$episode.json'
          : '$_primaryBase/info/movie/$contentId.json';
      final infoResp = await _client
          .get(Uri.parse(infoUrl), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 4));
      if (infoResp.statusCode == 200) {
        final infoData = json.decode(utf8.decode(infoResp.bodyBytes));
        if (infoData['quality'] != null &&
            (infoData['quality'] as String).isNotEmpty) {
          qualityLabel = infoData['quality'] as String;
        }
      }
    } catch (_) {}

    for (int i = 0; i < _baseMirrors.length; i++) {
      final mirror = _baseMirrors[i];
      final queryParams = effectiveIsSeries
          ? 'autoplay=1&autonext=1&ds_lang=en'
          : 'autoplay=1&ds_lang=en';
      final embedPath = effectiveIsSeries
          ? '$mirror/embed/tv/$contentId/$season/$episode?$queryParams'
          : '$mirror/embed/movie/$contentId?$queryParams';

      final host = Uri.tryParse(mirror)?.host ?? 'vidsrc.sh';
      sources.add(
        StreamSource(
          quality: '$qualityLabel ($host)',
          resolution: qualityLabel == '720p' ? '1280x720' : '1920x1080',
          format: 'Web Embed',
          url: embedPath,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': '$mirror/',
          },
          server: 'VidSrc ($host)',
          providerId: id,
          providerName: name,
        ),
      );
    }

    debugPrint(
      '[$name] Resolved ${sources.length} fallback embed sources for $contentId',
    );
    return sources;
  }
}
