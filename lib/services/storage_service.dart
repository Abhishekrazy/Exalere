import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';

class WatchHistoryItem {
  final MediaItem item;
  final int positionSeconds;
  final int totalSeconds;
  final int lastWatchedTimestamp;
  final int? season;
  final int? episode;

  const WatchHistoryItem({
    required this.item,
    required this.positionSeconds,
    required this.totalSeconds,
    required this.lastWatchedTimestamp,
    this.season,
    this.episode,
  });

  double get progress =>
      totalSeconds > 0 ? (positionSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'positionSeconds': positionSeconds,
    'totalSeconds': totalSeconds,
    'lastWatchedTimestamp': lastWatchedTimestamp,
    'season': season,
    'episode': episode,
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) => WatchHistoryItem(
    item: MediaItem.fromJson(json['item']),
    positionSeconds: json['positionSeconds'] ?? 0,
    totalSeconds: json['totalSeconds'] ?? 0,
    lastWatchedTimestamp: json['lastWatchedTimestamp'] ?? 0,
    season: json['season'],
    episode: json['episode'],
  );
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _favoritesKey = 'user_favorites';
  static const String _historyKey = 'user_watch_history';
  static const String _themeKey = 'user_theme_index';
  static const String _iptvKey = 'user_custom_iptv_url';
  static const String _useExternalPlayerKey = 'user_use_external_player';
  static const String _autoSkipIntroKey = 'user_auto_skip_intro';
  static const String _autoSkipOutroKey = 'user_auto_skip_outro';
  static const String _enableSmartSkipKey = 'user_enable_smart_skip';
  static const String _autoPlayTrailersKey = 'user_auto_play_trailers';
  static const String _tvModeKey = 'user_tv_mode';

  Future<List<MediaItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_favoritesKey) ?? [];
    return list
        .map((s) {
          try {
            return MediaItem.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<MediaItem>()
        .toList();
  }

  Future<bool> isFavorite(String id) async {
    final favs = await getFavorites();
    return favs.any((item) => item.id == id);
  }

  Future<void> toggleFavorite(MediaItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites();
    final index = favs.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      favs.removeAt(index);
    } else {
      favs.insert(0, item);
    }
    await prefs.setStringList(
      _favoritesKey,
      favs.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  Future<List<WatchHistoryItem>> getWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    return list
        .map((s) {
          try {
            return WatchHistoryItem.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<WatchHistoryItem>()
        .toList();
  }

  Future<WatchHistoryItem?> getHistoryItem(String id, {int? season, int? episode}) async {
    final history = await getWatchHistory();
    try {
      return history.firstWhere((h) =>
          h.item.id == id &&
          (season == null || h.season == season) &&
          (episode == null || h.episode == episode));
    } catch (_) {
      return null;
    }
  }

  Future<void> savePlaybackProgress({
    required MediaItem item,
    required int positionSeconds,
    required int totalSeconds,
    int? season,
    int? episode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory();

    history.removeWhere((h) =>
        h.item.id == item.id &&
        h.season == season &&
        h.episode == episode);

    history.insert(
      0,
      WatchHistoryItem(
        item: item,
        positionSeconds: positionSeconds,
        totalSeconds: totalSeconds,
        lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
        season: season,
        episode: episode,
      ),
    );

    // Keep up to 50 items
    final trimmed = history.take(50).toList();
    await prefs.setStringList(
      _historyKey,
      trimmed.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> removeWatchHistoryItem(String id, {int? season, int? episode}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory();
    history.removeWhere((h) =>
        h.item.id == id &&
        (season == null || h.season == season) &&
        (episode == null || h.episode == episode));
    await prefs.setStringList(
      _historyKey,
      history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> clearWatchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  Future<int> getThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey) ?? 0;
  }

  Future<void> setThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, index);
  }

  Future<String?> getCustomIptvUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_iptvKey);
  }

  Future<void> setCustomIptvUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_iptvKey);
    } else {
      await prefs.setString(_iptvKey, url);
    }
  }

  Future<bool> getUseExternalPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useExternalPlayerKey) ?? false;
  }

  Future<void> setUseExternalPlayer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useExternalPlayerKey, value);
  }

  Future<bool> getAutoSkipIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSkipIntroKey) ?? false;
  }

  Future<void> setAutoSkipIntro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSkipIntroKey, value);
  }

  Future<bool> getAutoSkipOutro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSkipOutroKey) ?? false;
  }

  Future<void> setAutoSkipOutro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSkipOutroKey, value);
  }

  Future<bool> getEnableSmartSkip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableSmartSkipKey) ?? true;
  }

  Future<void> setEnableSmartSkip(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableSmartSkipKey, value);
  }

  Future<bool> getAutoPlayTrailers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPlayTrailersKey) ?? true;
  }

  Future<void> setAutoPlayTrailers(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayTrailersKey, value);
  }

  Future<bool?> getTvMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_tvModeKey);
  }

  Future<void> setTvMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tvModeKey, value);
  }
}

