import 'package:flutter/foundation.dart';

import '../../models/exalere_plugin.dart';
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
  final ExalerePluginConfig? config;

  MovieBoxPlugin({this.config});

  @override
  String get id => config?.id ?? 'moviebox';

  @override
  String get name => config?.name ?? 'MovieBox Engine';

  @override
  int get priority => 100; // Primary fast multi-resolution streaming provider

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsSubtitles => true;

  @override
  Future<void> init() async {
    await _mb.init();
  }

  @override
  Future<List<MediaItem>> search(String query) => _mb.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _mb.getDetails(id);

  @override
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) => _mb.getSubtitles(
    subjectId: subjectId,
    resourceId: resourceId,
    season: season ?? 0,
    episode: episode ?? 0,
  );

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
    var streams = <StreamSource>[];
    final isLookingForSeries = isSeries ?? (season != null && season > 0);

    // 1. Direct attempt with subjectId if it originated from moviebox
    // or if subjectId is an internal MovieBox numeric/alphanumeric id (not IMDb or URL)
    final isMovieBoxOrigin =
        originProviderId != null &&
        (originProviderId == 'moviebox' ||
            originProviderId == id ||
            originProviderId.toLowerCase().contains('moviebox'));

    final isNumericOrMovieBoxId =
        !subjectId.startsWith('/') &&
        !subjectId.startsWith('http') &&
        !subjectId.startsWith('tt');

    final canTryDirect = isMovieBoxOrigin || isNumericOrMovieBoxId;

    bool triedDirect = false;
    if (canTryDirect) {
      triedDirect = true;
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
    }

    // 2. Title + Year fallback search: when subjectId is from TMDB, 4KHDHub, IMDb, or external catalog
    if (title != null && title.trim().isNotEmpty) {
      try {
        final clean = MediaItem.parseTitleTags(title).cleanTitle;
        var matches = await _mb.search(clean);

        // Fallback search: stripped title without punctuation/symbols
        if (matches.isEmpty) {
          final stripped = clean
              .replaceAll(RegExp(r'[:\-–—&]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (stripped != clean && stripped.isNotEmpty) {
            matches = await _mb.search(stripped);
          }
        }

        // Fallback search: main title prefix before ":" or "-"
        if (matches.isEmpty && (clean.contains(':') || clean.contains('-'))) {
          final mainTitle = clean.split(RegExp(r'[:\-]')).first.trim();
          if (mainTitle.length >= 3) {
            matches = await _mb.search(mainTitle);
          }
        }

        if (matches.isNotEmpty) {
          final best =
              MediaItem.findBestMatch(
                candidates: matches,
                title: clean,
                year: year,
                isSeries: isLookingForSeries,
              ) ??
              matches.firstWhere(
                (m) => isLookingForSeries ? m.isSeries : !m.isSeries,
                orElse: () => matches.first,
              );
          if (best.id.isNotEmpty && (!triedDirect || best.id != subjectId)) {
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
