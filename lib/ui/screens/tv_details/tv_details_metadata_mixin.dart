import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../services/fourkhdhub_provider.dart';
import '../../../services/moviebox_provider.dart';
import '../../../services/tmdb_service.dart';

/// Mixin managing TV metadata loading, TMDB enrichment, season episode stills caching,
/// and recommendation matching for TV details.
mixin TvDetailsMetadataMixin<T extends StatefulWidget> on State<T> {
  final MovieBoxProvider movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider fourKHdHubProvider = FourKHdHubProvider();
  final TmdbService tmdbService = TmdbService();

  MediaDetails? details;
  TmdbEnrichedDetails? tmdbDetails;
  bool isLoading = true;
  int selectedSeasonIdx = 0;
  final Map<int, Map<int, TmdbEpisodeInfo>> cachedSeasonEpisodes = {};

  List<MediaItem> relatedItems = [];
  bool isLoadingRelated = false;

  Future<void> loadAllDetails({
    required MediaItem mediaItem,
    required VoidCallback onTrailerAvailable,
    required VoidCallback onInitialFocus,
  }) async {
    setState(() => isLoading = true);

    // 1. Fetch TMDB enrichment in parallel
    tmdbService
        .getEnrichedDetails(
          title: mediaItem.title,
          year: mediaItem.year,
          isSeries: mediaItem.isSeries,
        )
        .then((tmdb) {
          if (mounted && tmdb != null) {
            setState(() => tmdbDetails = tmdb);
            if (!isLoading &&
                tmdb.trailerYoutubeKey != null &&
                tmdb.trailerYoutubeKey!.isNotEmpty) {
              onTrailerAvailable();
            }
            if (details != null && details!.isSeries) {
              loadSeasonEpisodes(tmdb.id, selectedSeasonIdx + 1);
            }
            loadRelatedItems(mediaItem: mediaItem, tmdbId: tmdb.id);
          }
        });

    // 2. Fetch Provider Details (MovieBox or 4KHDHub)
    try {
      if (mediaItem.provider == ProviderType.fourKHdHub) {
        details = await fourKHdHubProvider.getDetails(mediaItem.id);
      } else {
        details = await movieBoxProvider.getDetails(mediaItem.id);
      }

      if (!mounted) return;

      // Check watch history for smart season/episode selection
      if (details != null && details!.isSeries && details!.seasons.isNotEmpty) {
        final history = context.read<LibraryProvider>().getHistoryItem(
          mediaItem.id,
        );
        if (history != null && history.season != null && history.season! > 0) {
          final sIdx = (history.season! - 1).clamp(
            0,
            details!.seasons.length - 1,
          );
          selectedSeasonIdx = sIdx;
        }

        if (tmdbDetails != null) {
          loadSeasonEpisodes(tmdbDetails!.id, selectedSeasonIdx + 1);
        }
      }
    } catch (e) {
      debugPrint('TvDetailsScreen load error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        if (tmdbDetails?.trailerYoutubeKey != null &&
            tmdbDetails!.trailerYoutubeKey!.isNotEmpty) {
          onTrailerAvailable();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            onInitialFocus();
          }
        });
        if (relatedItems.isEmpty) {
          try {
            final app = context.read<AppProvider>();
            final candidates = mediaItem.isSeries
                ? app.seriesFeed
                : app.moviesFeed;
            if (candidates.isNotEmpty && details != null) {
              setState(() {
                relatedItems = candidates
                    .where((m) => m.id != mediaItem.id)
                    .take(12)
                    .toList();
              });
            }
          } catch (_) {}
        }
      }
    }
  }

  Future<void> loadRelatedItems({
    required MediaItem mediaItem,
    required int tmdbId,
  }) async {
    if (isLoadingRelated) return;
    isLoadingRelated = true;
    try {
      final app = context.read<AppProvider>();
      final candidates = mediaItem.isSeries ? app.seriesFeed : app.moviesFeed;

      final currentGenres = (details?.genres ?? [])
          .map((g) => g.toLowerCase().trim())
          .toSet();
      if (mediaItem.genre != null && mediaItem.genre!.isNotEmpty) {
        currentGenres.add(mediaItem.genre!.toLowerCase().trim());
      }

      final List<MediaItem> verifiedItems = [];
      final Set<String> seenIds = {mediaItem.id};

      // 1. Fetch TMDB recommendation titles and search/match for playable MovieBox sources
      try {
        final tmdbRecs = await tmdbService.getRecommendationsOrSimilar(
          tmdbId: tmdbId,
          isSeries: mediaItem.isSeries,
        );

        for (final rec in tmdbRecs) {
          if (verifiedItems.length >= 10) break;
          final recClean = rec.cleanTitle.toLowerCase().trim();

          // Check if in active feed
          MediaItem? feedMatch;
          for (final c in candidates) {
            if (!seenIds.contains(c.id) &&
                c.cleanTitle.toLowerCase().trim() == recClean) {
              feedMatch = c;
              break;
            }
          }
          if (feedMatch != null) {
            seenIds.add(feedMatch.id);
            verifiedItems.add(feedMatch);
            continue;
          }

          // On TV, do not fire external network search queries during details load to prevent socket starvation and hangs.
          // Pre-cached catalogue feed and genre matching provide instant, zero-cost recommendations below.
        }
      } catch (e) {
        debugPrint('TvDetailsScreen TMDB recommendations search error: $e');
      }

      // 2. Supplement with genre-matched playable items from verified provider feed
      if (currentGenres.isNotEmpty) {
        for (final c in candidates) {
          if (seenIds.contains(c.id)) continue;
          final g = c.genre?.toLowerCase() ?? '';
          if (currentGenres.any((cg) => g.contains(cg) || cg.contains(g))) {
            seenIds.add(c.id);
            verifiedItems.add(c);
            if (verifiedItems.length >= 12) break;
          }
        }
      }

      // 3. Fill remaining from provider feed
      for (final c in candidates) {
        if (!seenIds.contains(c.id)) {
          seenIds.add(c.id);
          verifiedItems.add(c);
          if (verifiedItems.length >= 12) break;
        }
      }

      if (mounted) {
        setState(() {
          relatedItems = verifiedItems.take(12).toList();
        });
      }
    } catch (e) {
      debugPrint('TvDetailsScreen related items error: $e');
    } finally {
      isLoadingRelated = false;
    }
  }

  Future<void> loadSeasonEpisodes(int tmdbId, int seasonNumber) async {
    if (cachedSeasonEpisodes.containsKey(seasonNumber)) return;
    try {
      final eps = await tmdbService.getSeasonEpisodes(
        tvId: tmdbId,
        seasonNumber: seasonNumber,
      );
      if (mounted && eps.isNotEmpty) {
        setState(() {
          cachedSeasonEpisodes[seasonNumber] = eps;
        });
      }
    } catch (e) {
      debugPrint('Error loading TMDB season episodes: $e');
    }
  }

  void onSeasonSelected(int index) {
    if (selectedSeasonIdx == index) return;
    setState(() => selectedSeasonIdx = index);
    if (tmdbDetails != null) {
      loadSeasonEpisodes(tmdbDetails!.id, index + 1);
    }
  }
}
