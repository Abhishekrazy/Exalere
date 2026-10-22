import 'package:flutter/foundation.dart';

import '../../models/exalere_plugin.dart';
import '../../models/media_details.dart';
import '../../models/media_item.dart';
import '../../models/stream_source.dart';
import '../../services/media_provider_plugin.dart';
import '../../services/tmdb_service.dart';

/// Built-in TMDB discovery provider.
///
/// This is a **metadata catalog**: it supplies browsable, richly illustrated
/// rows out of the box so a fresh install is never an empty screen, but it can
/// never resolve a stream. [supportsStreams] is therefore `false`, which keeps
/// it out of [ProviderRegistry.streamProviders] so availability checks and the
/// play actions treat its titles as browsable-but-not-playable until the user
/// installs a real streaming provider.
///
/// Titles are intentionally reported with no provider tag: they are metadata,
/// not a promise that a stream exists.
class TmdbPlugin extends MediaProviderPlugin {
  TmdbPlugin({this.config});

  final ExalerePluginConfig? config;
  final TmdbService _tmdb = TmdbService();

  @override
  String get id => config?.id ?? 'tmdb';

  @override
  String get name => config?.name ?? 'TMDB Catalog';

  /// Lowest priority: discovery only, never a playback candidate.
  @override
  int get priority => 1;

  @override
  bool get isEnabled => config?.isEnabled ?? true;

  /// Metadata only. This is what makes the app hide play actions and offer
  /// library/favourite actions instead when TMDB is the only provider present.
  @override
  bool get supportsStreams => false;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    try {
      switch (category) {
        case 'movies':
          return await _tmdb.getPopularMoviesFeed(page: page);
        case 'series':
          return await _tmdb.getPopularSeriesFeed(page: page);
        case 'featured':
        case 'trending':
          return await _tmdb.getTrendingFeed(page: page);
        case 'top_rated':
          return await _tmdb.getTopRatedMoviesFeed(page: page);
        case 'upcoming':
          return await _tmdb.getUpcomingMoviesFeed(page: page);
        case null:
          return await _tmdb.getTrendingFeed(page: page);
        default:
          final byGenre = await _tmdb.getGenreFeed(category, page: page);
          if (byGenre.isNotEmpty) return byGenre;
          return await _tmdb.searchMulti(category, page: page);
      }
    } catch (e) {
      debugPrint('[$name] catalog feed "$category" failed: $e');
      return const [];
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      return await _tmdb.searchMulti(query.trim());
    } catch (e) {
      debugPrint('[$name] search failed: $e');
      return const [];
    }
  }

  /// Details are resolved by the details screens through TMDB enrichment, which
  /// already has the title and year needed for an unambiguous lookup. Returning
  /// `null` here avoids guessing from an id alone.
  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  /// A metadata provider must never invent a stream.
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
  }) async => const [];
}
