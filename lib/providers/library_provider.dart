import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();

  List<MediaItem> _favorites = [];
  List<WatchHistoryItem> _history = [];
  bool _isLoading = false;

  List<MediaItem> get favorites => _favorites;
  List<WatchHistoryItem> get history => _history;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _favorites = await _storageService.getFavorites();
    _history = await _storageService.getWatchHistory();

    _isLoading = false;
    notifyListeners();
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
  }) async {
    await _storageService.savePlaybackProgress(
      item: item,
      positionSeconds: positionSeconds,
      totalSeconds: totalSeconds,
      season: season,
      episode: episode,
    );
    _history = await _storageService.getWatchHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String id, {int? season, int? episode}) async {
    await _storageService.removeWatchHistoryItem(id, season: season, episode: episode);
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
        if (season != null && h.season != null && h.season != season) return false;
        if (episode != null && h.episode != null && h.episode != episode) return false;
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
    if (item.totalSeconds > 0 && item.positionSeconds >= item.totalSeconds - 15) {
      return 0;
    }
    if (item.progress >= 0.95) {
      return 0;
    }
    // Only resume if watched more than 5 seconds
    return item.positionSeconds > 5 ? item.positionSeconds : 0;
  }
}
