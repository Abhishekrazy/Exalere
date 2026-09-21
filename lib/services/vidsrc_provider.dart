import 'package:flutter/foundation.dart';

import '../models/stream_source.dart';
import 'media_provider_plugin.dart';

/// VidSrc / SuperEmbed media provider plugin providing redundant fallback streams
/// when primary scrapers are blocked or undergoing maintenance.
class VidSrcProvider extends MediaProviderPlugin {
  static final VidSrcProvider _instance = VidSrcProvider._internal();
  factory VidSrcProvider() => _instance;
  VidSrcProvider._internal();

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

    // Prioritize IMDB ID if provided, otherwise TMDB subjectId
    final contentId = (imdbId != null && imdbId.isNotEmpty)
        ? imdbId
        : subjectId;
    final isSeries =
        season != null && season > 0 && episode != null && episode > 0;

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
        ),
      );
    }

    debugPrint(
      '[$name] Resolved ${sources.length} fallback embed sources for $contentId',
    );
    return sources;
  }
}
