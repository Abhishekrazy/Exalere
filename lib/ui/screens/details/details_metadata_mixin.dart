import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/media_details.dart';
import '../../../models/media_item.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/library_provider.dart';
import '../../../services/fourkhdhub_provider.dart';
import '../../../services/moviebox_provider.dart';
import '../../../services/tmdb_service.dart';

/// Mixin managing TMDB enrichment, season/episode metadata caching,
/// background prefetching, and related items resolution for details screens.
mixin DetailsMetadataMixin<T extends StatefulWidget> on State<T> {
  final MovieBoxProvider movieBoxProvider = MovieBoxProvider();
  final FourKHdHubProvider fourKHdHubProvider = FourKHdHubProvider();

  MediaDetails? details;
  TmdbEnrichedDetails? tmdbDetails;
  bool isLoading = true;
  int selectedSeasonIdx = 0;
  int selectedEpisodeIdx = 0;

  List<MediaItem> relatedItems = [];
  bool isLoadingRelated = false;

  Future<void> loadDetails({
    required MediaItem mediaItem,
    required VoidCallback onTrailerLoaded,
  }) async {
    setState(() => isLoading = true);

    // Fetch TMDB enriched metadata in parallel (trailer, cast photos, age certification, related items)
    TmdbService()
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
              onTrailerLoaded();
            }
            if (details != null && details!.isSeries) {
              enrichSeasonEpisodesWithTmdb(
                mediaItem: mediaItem,
                tmdbId: tmdb.id,
              );
            }
            loadRelatedItems(mediaItem: mediaItem, tmdbId: tmdb.id);
          }
        });

    try {
      if (mediaItem.provider == ProviderType.fourKHdHub) {
        details = await fourKHdHubProvider.getDetails(mediaItem.id);
      } else {
        details = await movieBoxProvider.getDetails(mediaItem.id);
      }
      if (!mounted) return;

      if (details != null && details!.isSeries) {
        final history = context.read<LibraryProvider>().getHistoryItem(
          mediaItem.id,
        );
        if (history != null &&
            history.season != null &&
            history.episode != null) {
          final sIdx = history.season! - 1;
          final epIdx = history.episode! - 1;
          if (sIdx >= 0 && sIdx < details!.seasons.length) {
            selectedSeasonIdx = sIdx;
            if (epIdx >= 0 && epIdx < details!.seasons[sIdx].episodes.length) {
              selectedEpisodeIdx = epIdx;
            }
          }
        }
        enrichSeasonEpisodesWithTmdb(
          mediaItem: mediaItem,
          seasonIdx: selectedSeasonIdx,
        );
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        if (tmdbDetails?.trailerYoutubeKey != null &&
            tmdbDetails!.trailerYoutubeKey!.isNotEmpty) {
          onTrailerLoaded();
        }
        // Fallback related items if TMDB didn't load any, only if video source / details available
        if (relatedItems.isEmpty && details != null) {
          try {
            final app = context.read<AppProvider>();
            final candidates = mediaItem.isSeries
                ? app.seriesFeed
                : app.moviesFeed;
            if (candidates.isNotEmpty) {
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
        final tmdbRecs = await TmdbService().getRecommendationsOrSimilar(
          tmdbId: tmdbId,
          isSeries: mediaItem.isSeries,
        );

        for (final rec in tmdbRecs) {
          if (verifiedItems.length >= 10) break;
          final recClean = rec.cleanTitle.toLowerCase().trim();

          // Check if already in active feed
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

          // Search MovieBox with resource availability check
          if (verifiedItems.length < 5 && recClean.isNotEmpty) {
            try {
              final searchResults = await movieBoxProvider.search(
                rec.cleanTitle,
              );
              for (final res in searchResults) {
                if (res.id.isNotEmpty && !seenIds.contains(res.id)) {
                  seenIds.add(res.id);
                  verifiedItems.add(res);
                  break;
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('TMDB recommendations search error: $e');
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
      debugPrint('Error loading related items: $e');
    } finally {
      isLoadingRelated = false;
    }
  }

  Future<void> enrichSeasonEpisodesWithTmdb({
    required MediaItem mediaItem,
    int? tmdbId,
    int? seasonIdx,
  }) async {
    if (details == null || !details!.isSeries) return;
    final sIdx = seasonIdx ?? selectedSeasonIdx;
    if (sIdx < 0 || sIdx >= details!.seasons.length) return;

    final targetSeason = details!.seasons[sIdx];
    final id = tmdbId ?? tmdbDetails?.id;

    Map<int, TmdbEpisodeInfo> tmdbEpisodes = {};
    if (id != null && id > 0) {
      tmdbEpisodes = await TmdbService().getSeasonEpisodes(
        tvId: id,
        seasonNumber: targetSeason.seasonNumber,
      );
    } else {
      tmdbEpisodes = await TmdbService().getSeasonEpisodesByTitle(
        title: mediaItem.title,
        year: mediaItem.year,
        seasonNumber: targetSeason.seasonNumber,
      );
    }

    if (!mounted || tmdbEpisodes.isEmpty) return;

    applyTmdbToSeason(seasonIdx: sIdx, tmdbEpisodes: tmdbEpisodes);

    // Background prefetch remaining seasons for instant switching
    final finalTvId = id ?? tmdbDetails?.id;
    if (finalTvId != null && finalTvId > 0) {
      prefetchOtherSeasons(finalTvId, sIdx);
    }
  }

  void prefetchOtherSeasons(int tvId, int currentIdx) {
    if (details == null || !details!.isSeries) return;
    for (int i = 0; i < details!.seasons.length; i++) {
      if (i == currentIdx) continue;
      final s = details!.seasons[i];
      final hasMissing = s.episodes.any(
        (e) => e.thumbnail == null || e.thumbnail!.trim().isEmpty,
      );
      if (hasMissing) {
        TmdbService()
            .getSeasonEpisodes(tvId: tvId, seasonNumber: s.seasonNumber)
            .then((epMap) {
              if (!mounted || epMap.isEmpty) return;
              applyTmdbToSeason(seasonIdx: i, tmdbEpisodes: epMap);
            });
      }
    }
  }

  void applyTmdbToSeason({
    required int seasonIdx,
    required Map<int, TmdbEpisodeInfo> tmdbEpisodes,
  }) {
    if (details == null ||
        seasonIdx < 0 ||
        seasonIdx >= details!.seasons.length) {
      return;
    }
    final targetSeason = details!.seasons[seasonIdx];
    bool hasChanges = false;
    final updatedEpisodes = targetSeason.episodes.map((ep) {
      final tmdbEp = tmdbEpisodes[ep.episode];
      if (tmdbEp == null) return ep;

      final bool needsThumb =
          (ep.thumbnail == null || ep.thumbnail!.trim().isEmpty) &&
          (tmdbEp.stillUrl != null && tmdbEp.stillUrl!.isNotEmpty);
      final bool isGenericTitle =
          ep.title.isEmpty ||
          RegExp(
            r'^Episode \d+$',
            caseSensitive: false,
          ).hasMatch(ep.title.trim());
      final bool needsTitle =
          isGenericTitle &&
          (tmdbEp.name != null && tmdbEp.name!.trim().isNotEmpty);
      final bool needsOverview =
          (ep.overview == null || ep.overview!.trim().isEmpty) &&
          (tmdbEp.overview != null && tmdbEp.overview!.trim().isNotEmpty);

      if (needsThumb || needsTitle || needsOverview) {
        hasChanges = true;
        return ep.copyWith(
          thumbnail: needsThumb ? tmdbEp.stillUrl : ep.thumbnail,
          title: needsTitle ? tmdbEp.name! : ep.title,
          overview: needsOverview ? tmdbEp.overview : ep.overview,
        );
      }
      return ep;
    }).toList();

    if (hasChanges && mounted) {
      final updatedSeasons = List<Season>.from(details!.seasons);
      updatedSeasons[seasonIdx] = targetSeason.copyWith(
        episodes: updatedEpisodes,
      );
      setState(() {
        details = details!.copyWith(seasons: updatedSeasons);
      });
    }
  }

  void onSeasonChanged(int newIdx, {required MediaItem mediaItem}) {
    if (newIdx == selectedSeasonIdx) return;
    setState(() {
      selectedSeasonIdx = newIdx;
      selectedEpisodeIdx = 0;
    });
    enrichSeasonEpisodesWithTmdb(mediaItem: mediaItem, seasonIdx: newIdx);
  }
}
