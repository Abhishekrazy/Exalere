import 'package:flutter/foundation.dart';

import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import '../../services/moviebox_provider.dart';

/// Modular MovieBox streaming and catalog plugin for Exalere.
///
/// Implements [MediaProviderPlugin] to provide resilient video resolution,
/// search, details, and subtitle capabilities. Direct calls with foreign
/// slugs (e.g., from 4KHDHub or TMDB) automatically fall back to title search.
class MovieBoxPlugin extends MediaProviderPlugin {
  final MovieBoxProvider _mb = MovieBoxProvider();

  @override
  String get id => 'moviebox';

  @override
  String get name => 'MovieBox Engine';

  @override
  int get priority => 100; // Primary fast multi-resolution streaming provider

  @override
  bool get isEnabled => true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<void> init() async {
    await _mb.init();
  }

  @override
  Future<List<MediaItem>> search(String query) => _mb.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _mb.getDetails(id);

  /// Fetch subtitles for active playback
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    int season = 0,
    int episode = 0,
  }) => _mb.getSubtitles(
    subjectId: subjectId,
    resourceId: resourceId,
    season: season,
    episode: episode,
  );

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    var streams = <StreamSource>[];

    // 1. Direct attempt with subjectId (wrapped in try-catch so foreign slugs don't abort)
    try {
      streams = await _mb.getStreams(
        subjectId: subjectId,
        season: season ?? 0,
        episode: episode ?? 0,
      );
      if (streams.isNotEmpty) return streams;
    } catch (e) {
      debugPrint(
        '[MovieBoxPlugin] Direct subjectId lookup failed ($e). Falling back to title search...',
      );
    }

    // 2. Title fallback search: when subjectId is from TMDB, 4KHDHub, or external catalog
    if (title != null && title.trim().isNotEmpty) {
      try {
        final matches = await _mb.search(title.trim());
        if (matches.isNotEmpty) {
          final isLookingForSeries = season != null && episode != null;
          final best = matches.firstWhere(
            (m) => isLookingForSeries ? m.isSeries : !m.isSeries,
            orElse: () => matches.first,
          );
          if (best.id.isNotEmpty && best.id != subjectId) {
            streams = await _mb.getStreams(
              subjectId: best.id,
              season: season ?? 0,
              episode: episode ?? 0,
            );
          }
        }
      } catch (e) {
        debugPrint('[MovieBoxPlugin] Title fallback stream search error: $e');
      }
    }

    return streams;
  }
}
