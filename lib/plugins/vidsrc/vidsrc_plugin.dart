import 'package:flutter/foundation.dart';

import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import '../../services/tmdb_service.dart';

/// Modular VidSrc streaming plugin for Exalere.
///
/// Implements [MediaProviderPlugin] with 9 redundant web embed mirrors,
/// automatic IMDb ID enrichment via TMDB, and graceful failover.
class VidSrcPlugin extends MediaProviderPlugin {
  static final VidSrcPlugin _instance = VidSrcPlugin._internal();
  factory VidSrcPlugin() => _instance;
  VidSrcPlugin._internal();

  @override
  String get id => 'vidsrc';

  @override
  String get name => 'VidSrc Engine';

  @override
  int get priority => 75;

  @override
  bool get isEnabled => true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => false;

  final List<String> _baseMirrors = [
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
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    int? season,
    int? episode,
    String? imdbId,
  }) async {
    final List<StreamSource> sources = [];
    final isSeries =
        season != null && season > 0 && episode != null && episode > 0;

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
          isSeries: isSeries,
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

    for (int i = 0; i < _baseMirrors.length; i++) {
      final mirror = _baseMirrors[i];
      final queryParams = isSeries
          ? 'autoplay=1&autonext=1&ds_lang=en'
          : 'autoplay=1&ds_lang=en';
      final embedPath = isSeries
          ? '$mirror/embed/tv/$contentId/$season/$episode?$queryParams'
          : '$mirror/embed/movie/$contentId?$queryParams';

      final host = Uri.tryParse(mirror)?.host ?? 'vidsrc.sh';
      sources.add(
        StreamSource(
          quality: '1080p ($host)',
          resolution: '1920x1080',
          format: 'Web Embed',
          url: embedPath,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
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
