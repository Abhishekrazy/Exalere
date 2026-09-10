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
}
