import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../services/provider_registry.dart';
import '../../../services/tmdb_service.dart';

/// Mixin encapsulating TMDB enriched metadata fetching, season episodes
/// loading, trailer direct URL extraction, and related recommendations resolution
/// specifically tailored for [TvDetailsScreen].
mixin TvDetailsMetadataMixin<T extends StatefulWidget> on State<T> {
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
          tmdbId: int.tryParse(mediaItem.id),
        )
        .then((tmdb) {
          if (mounted && tmdb != null) {
            setState(() {
              tmdbDetails = tmdb;
              if (details == null ||
                  (mediaItem.isSeries && details!.seasons.isEmpty)) {
                details = tmdb.toMediaDetails(mediaItem);
              }
            });
            if (tmdb.trailerYoutubeKey != null &&
                tmdb.trailerYoutubeKey!.isNotEmpty) {
              try {
                if (context.read<AppProvider>().autoPlayTrailers) {
                  TmdbService().resolveTrailerDirectUrl(
                    tmdb.trailerYoutubeKey!,
                  );
                }
              } catch (_) {}
              onTrailerAvailable();
            }
            if (details != null &&
                details!.isSeries &&
                details!.seasons.isNotEmpty) {
              final sNum = details!
                  .seasons[selectedSeasonIdx.clamp(
                    0,
                    details!.seasons.length - 1,
                  )]
                  .seasonNumber;
              loadSeasonEpisodes(tmdb.id, sNum);
            }
            loadRelatedItems(mediaItem: mediaItem, tmdbId: tmdb.id);
          }
        });

    // 2. Fetch Provider Details
    try {
      details = await ProviderRegistry().getDetails(
        mediaItem.id,
        providerId: mediaItem.effectiveProviderId,
        title: mediaItem.title,
        year: mediaItem.year,
        isSeries: mediaItem.isSeries,
      );

      if ((details == null ||
              (mediaItem.isSeries && details!.seasons.isEmpty)) &&
          tmdbDetails != null) {
        details = tmdbDetails!.toMediaDetails(mediaItem);
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
          final sNum = details!
              .seasons[selectedSeasonIdx.clamp(0, details!.seasons.length - 1)]
              .seasonNumber;
          loadSeasonEpisodes(tmdbDetails!.id, sNum);
        }
      }
    } catch (e) {
      debugPrint('TvDetailsScreen load error: $e');
    } finally {
      if (mounted) {
        if ((details == null ||
                (mediaItem.isSeries && details!.seasons.isEmpty)) &&
            tmdbDetails != null) {
          details = tmdbDetails!.toMediaDetails(mediaItem);
        }
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
      final seasonNum = (details != null && index < details!.seasons.length)
          ? details!.seasons[index].seasonNumber
          : index + 1;
      loadSeasonEpisodes(tmdbDetails!.id, seasonNum);
    }
  }
}
