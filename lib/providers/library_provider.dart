import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<MediaItem> _favorites = [];
  List<WatchHistoryItem> _history = [];
  Map<String, Set<String>> _watchedEpisodes = {};
  bool _isLoading = false;

  List<MediaItem> get favorites => _favorites;
  List<WatchHistoryItem> get history => _history;
  bool get isLoading => _isLoading;

  /// Dedicated continue watching list:
  /// 1. Filters out watched/completed items.
  /// 2. Ensures at most one entry per series (the single most recent episode played).
  List<WatchHistoryItem> get continueWatching {
    final seenSeries = <String>{};
    final result = <WatchHistoryItem>[];

    for (final h in _history) {
      // Trailers must NEVER appear in continue watching / continue playing!
      final titleLower = h.item.title.toLowerCase();
      if (h.item.id.startsWith('trailer_') ||
          titleLower.contains('trailer') ||
          titleLower.contains('teaser')) {
        continue;
      }

      final isSeries = h.item.isSeries || h.season != null;
      final seriesId = h.item.id;

      if (isSeries) {
        if (seenSeries.contains(seriesId)) {
          // Only show the last played episode for any given series
          continue;
        }
        seenSeries.add(seriesId);
      }

      final watched =
          h.isWatched ||
          (h.progress >= 0.95) ||
          (h.totalSeconds > 0 && h.positionSeconds >= h.totalSeconds - 15) ||
          isEpisodeWatched(seriesId, h.season, h.episode);

      if (watched) {
        continue;
      }

      result.add(h);
    }

    return result;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _favorites = await _storageService.getFavorites();
    _history = await _storageService.getWatchHistory();
    _watchedEpisodes = await _storageService.getAllWatchedEpisodes();

    // Clean up any historical trailer entries from history & storage
    final trailers = _history.where((h) {
      final t = h.item.title.toLowerCase();
      return h.item.id.startsWith('trailer_') ||
          t.contains('trailer') ||
          t.contains('teaser');
    }).toList();
    for (final t in trailers) {
      await _storageService.removeWatchHistoryItem(
        t.item.id,
        season: t.season,
        episode: t.episode,
      );
    }
    _history.removeWhere((h) {
      final t = h.item.title.toLowerCase();
      return h.item.id.startsWith('trailer_') ||
          t.contains('trailer') ||
          t.contains('teaser');
    });

    _isLoading = false;
    notifyListeners();
  }

  bool isEpisodeWatched(String seriesId, int? season, int? episode) {
    if (season != null && episode != null) {
      final set = _watchedEpisodes[seriesId];
      if (set != null && set.contains('s${season}_e$episode')) {
        return true;
      }
    }
    final h = getHistoryItem(seriesId, season: season, episode: episode);
    if (h != null && h.isWatched) return true;
    return false;
  }

  Future<void> markAsWatched(
    String id, {
    int? season,
    int? episode,
    required bool isWatched,
    MediaItem? item,
  }) async {
    if (season != null && episode != null) {
      await _storageService.setEpisodeWatched(id, season, episode, isWatched);
      final set = _watchedEpisodes.putIfAbsent(id, () => <String>{});
      final epKey = 's${season}_e$episode';
      if (isWatched) {
        set.add(epKey);
      } else {
        set.remove(epKey);
      }
    }
    await _storageService.updateHistoryWatchedStatus(
      id,
      season: season,
      episode: episode,
      isWatched: isWatched,
    );
    _history = await _storageService.getWatchHistory();
    notifyListeners();
  }

  Future<void> toggleEpisodeWatched({
    required MediaItem series,
    required int season,
    required int episode,
  }) async {
    final current = isEpisodeWatched(series.id, season, episode);
    await markAsWatched(
      series.id,
      season: season,
      episode: episode,
      isWatched: !current,
      item: series,
    );
  }

  bool isSeasonWatched(String seriesId, int season, List<int> episodeNumbers) {
    if (episodeNumbers.isEmpty) return false;
    for (final ep in episodeNumbers) {
      if (!isEpisodeWatched(seriesId, season, ep)) {
        return false;
      }
    }
    return true;
  }

  Future<void> markSeasonAsWatched(
    String seriesId,
    int season,
    List<int> episodeNumbers, {
    required bool isWatched,
  }) async {
    await _storageService.setSeasonWatched(
      seriesId,
      season,
      episodeNumbers,
      isWatched,
    );

    final set = _watchedEpisodes.putIfAbsent(seriesId, () => <String>{});
    for (final ep in episodeNumbers) {
      final epKey = 's${season}_e$ep';
      if (isWatched) {
        set.add(epKey);
      } else {
        set.remove(epKey);
      }
    }

    _history = await _storageService.getWatchHistory();
    notifyListeners();
  }

  Future<void> toggleSeasonWatched({
    required String seriesId,
    required int season,
    required List<int> episodeNumbers,
  }) async {
    final current = isSeasonWatched(seriesId, season, episodeNumbers);
    await markSeasonAsWatched(
      seriesId,
      season,
      episodeNumbers,
      isWatched: !current,
    );
  }

  bool isFavorite(String id) {
    return _favorites.any((item) => item.id == id);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    await _storageService.toggleFavorite(item);
    _favorites = await _storageService.getFavorites();
    notifyListeners();
  }

  Future<void> recordProgress({
    required MediaItem item,
    required int positionSeconds,
    required int totalSeconds,
    int? season,
    int? episode,
    bool? isWatched,
  }) async {
    final titleLower = item.title.toLowerCase();
    if (item.id.startsWith('trailer_') ||
        titleLower.contains('trailer') ||
        titleLower.contains('teaser')) {
      return;
    }

    await _storageService.savePlaybackProgress(
      item: item,
      positionSeconds: positionSeconds,
      totalSeconds: totalSeconds,
      season: season,
      episode: episode,
      isWatched: isWatched,
    );
    if (season != null && episode != null) {
      final autoWatched =
          isWatched ??
          (totalSeconds > 0 &&
              (positionSeconds >= totalSeconds * 0.95 ||
                  positionSeconds >= totalSeconds - 15));
      if (autoWatched) {
        _watchedEpisodes
            .putIfAbsent(item.id, () => <String>{})
            .add('s${season}_e$episode');
      }
    }
    _history = await _storageService.getWatchHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String id, {int? season, int? episode}) async {
    await _storageService.removeWatchHistoryItem(
      id,
      season: season,
      episode: episode,
    );
    _history = await _storageService.getWatchHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _storageService.clearWatchHistory();
    _history = [];
    notifyListeners();
  }

  WatchHistoryItem? getHistoryItem(String id, {int? season, int? episode}) {
    try {
      return _history.firstWhere((h) {
        if (h.item.id != id) return false;
        if (season != null && h.season != null && h.season != season) {
          return false;
        }
        if (episode != null && h.episode != null && h.episode != episode) {
          return false;
        }
        return true;
      });
    } catch (_) {
      return null;
    }
  }

  int getResumePosition(String id, {int? season, int? episode}) {
    final item = getHistoryItem(id, season: season, episode: episode);
    if (item == null) return 0;
    // If watched more than 95% or within last 15 seconds, consider finished -> return 0
    if (item.totalSeconds > 0 &&
        item.positionSeconds >= item.totalSeconds - 15) {
      return 0;
    }
    if (item.progress >= 0.95) {
      return 0;
    }
    // Only resume if watched more than 5 seconds
    return item.positionSeconds > 5 ? item.positionSeconds : 0;
  }

  /// Generates a personalized recommendation shelf based on user's played history saved in local storage.
  /// If history exists: recommends titles matching the most recently watched or most frequent genre.
  /// If history is empty: falls back to top-rated picks from the catalog.
  ({String title, List<MediaItem> items}) getPersonalizedRecommendations(
    List<MediaItem> catalogPool,
  ) {
    final watchedIds = _history.map((h) => h.item.id).toSet();

    if (_history.isNotEmpty) {
      // 1. Try recommendations based on the most recently played item
      final lastPlayed = _history.first;
      final rawGenre = lastPlayed.item.genre ?? '';
      final genreTokens = rawGenre
          .split(RegExp(r'[,/|]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty && s != 'movie' && s != 'tv series')
          .toList();

      if (genreTokens.isNotEmpty) {
        final matches = catalogPool.where((item) {
          if (watchedIds.contains(item.id) || item.id == lastPlayed.item.id) {
            return false;
          }
          return genreTokens.any((g) => item.matchesCategory(g));
        }).toList();

        if (matches.length >= 3) {
          return (
            title: 'Because You Watched ${lastPlayed.item.cleanTitle}',
            items: matches.take(24).toList(),
          );
        }
      }

      // 2. Fallback: Aggregate top watched genres across all history items
      final Map<String, int> genreCounts = {};
      for (final h in _history) {
        final g = h.item.genre ?? '';
        for (final token in g.split(RegExp(r'[,/|]'))) {
          final clean = token.trim().toLowerCase();
          if (clean.isNotEmpty && clean != 'movie' && clean != 'tv series') {
            genreCounts[clean] = (genreCounts[clean] ?? 0) + 1;
          }
        }
      }

      if (genreCounts.isNotEmpty) {
        final topGenre = genreCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

        final matches = catalogPool.where((item) {
          if (watchedIds.contains(item.id)) return false;
          return item.matchesCategory(topGenre);
        }).toList();

        if (matches.length >= 3) {
          final capitalizedGenre = topGenre.isNotEmpty
              ? topGenre[0].toUpperCase() + topGenre.substring(1)
              : 'Top';
          return (
            title: 'Recommended For You: $capitalizedGenre',
            items: matches.take(24).toList(),
          );
        }
      }
    }

    // 3. Fallback for new users or empty history: What to Watch / Top Rated Picks
    final topPicks = catalogPool
        .where((item) => !watchedIds.contains(item.id))
        .where((item) => item.rating == null || item.rating! >= 6.8)
        .take(24)
        .toList();

    return (
      title: 'What to Watch: Handpicked For You',
      items: topPicks.isNotEmpty ? topPicks : catalogPool.take(24).toList(),
    );
  }

  /// Immediately records the start of playback into local storage
  Future<void> recordPlaybackStart(
    MediaItem item, {
    int? season,
    int? episode,
  }) async {
    final titleLower = item.title.toLowerCase();
    if (item.id.startsWith('trailer_') ||
        titleLower.contains('trailer') ||
        titleLower.contains('teaser')) {
      return;
    }

    final existing = getHistoryItem(item.id, season: season, episode: episode);
    if (existing == null) {
      await recordProgress(
        item: item,
        positionSeconds: 1,
        totalSeconds: 0,
        season: season,
        episode: episode,
      );
    }
  }
}
