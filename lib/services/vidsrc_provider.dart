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
  String get name => 'VidSrc / SuperEmbed';

  @override
  int get priority => 30; // Fallback tier after MovieBox (100) and 4KHDHub (50)

  @override
  bool get isEnabled => true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => false;

  final List<String> _baseMirrors = [
    'https://vidsrc.to',
    'https://vidsrc.me',
    'https://vidsrc.pm',
    'https://vidsrc.xyz',
    'https://superembed.stream',
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
    int? season,
    int? episode,
  }) async {
    final List<StreamSource> sources = [];

    // Construct stream URLs across redundant mirrors
    final isSeries =
        season != null && season > 0 && episode != null && episode > 0;

    for (int i = 0; i < _baseMirrors.length; i++) {
      final mirror = _baseMirrors[i];
      final embedPath = isSeries
          ? '$mirror/embed/tv/$subjectId/$season/$episode'
          : '$mirror/embed/movie/$subjectId';

      sources.add(
        StreamSource(
          quality: '1080p (Mirror ${i + 1})',
          resolution: '1920x1080',
          format: 'HLS / Embed',
          url: embedPath,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': '$mirror/',
          },
        ),
      );
    }

    debugPrint(
      '[$name] Resolved ${sources.length} fallback embed sources for $subjectId',
    );
    return sources;
  }
}
