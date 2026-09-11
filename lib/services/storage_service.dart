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
  final bool isWatched;

  const WatchHistoryItem({
    required this.item,
    required this.positionSeconds,
    required this.totalSeconds,
    required this.lastWatchedTimestamp,
    this.season,
    this.episode,
    this.isWatched = false,
  });

  WatchHistoryItem copyWith({
    MediaItem? item,
    int? positionSeconds,
    int? totalSeconds,
    int? lastWatchedTimestamp,
    int? season,
    int? episode,
    bool? isWatched,
  }) => WatchHistoryItem(
    item: item ?? this.item,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    lastWatchedTimestamp: lastWatchedTimestamp ?? this.lastWatchedTimestamp,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    isWatched: isWatched ?? this.isWatched,
  );

  double get progress =>
      totalSeconds > 0 ? (positionSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'positionSeconds': positionSeconds,
    'totalSeconds': totalSeconds,
    'lastWatchedTimestamp': lastWatchedTimestamp,
    'season': season,
    'episode': episode,
    'isWatched': isWatched,
  };

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) =>
      WatchHistoryItem(
        item: MediaItem.fromJson(json['item']),
        positionSeconds: json['positionSeconds'] ?? 0,
        totalSeconds: json['totalSeconds'] ?? 0,
        lastWatchedTimestamp: json['lastWatchedTimestamp'] ?? 0,
        season: json['season'],
        episode: json['episode'],
        isWatched: json['isWatched'] ?? false,
      );
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _favoritesKey = 'user_favorites';
  static const String _historyKey = 'user_watch_history';
  static const String _watchedEpisodesKey = 'user_watched_episodes';
  static const String _themeKey = 'user_theme_index';
  static const String _iptvKey = 'user_custom_iptv_url';
  static const String _liveTvCountryKey = 'user_live_tv_country';
  static const String _liveTvLanguageKey = 'user_live_tv_language';
  static const String _useExternalPlayerKey = 'user_use_external_player';
  static const String _autoSkipIntroKey = 'user_auto_skip_intro';
  static const String _autoSkipOutroKey = 'user_auto_skip_outro';
  static const String _enableSmartSkipKey = 'user_enable_smart_skip';
  static const String _autoPlayTrailersKey = 'user_auto_play_trailers';
  static const String _tvModeKey = 'user_tv_mode';
  static const String _uiScaleKey = 'user_ui_scale';
  static const String _autoCheckUpdatesKey = 'user_auto_check_updates';
  static const String _lastUpdateCheckKey = 'user_last_update_check_time';
  static const String _cornerStyleKey = 'user_corner_style';
  static const String _surfaceMorphismKey = 'user_surface_morphism';
  static const String _fontFamilyKey = 'user_font_family';
  static const String _filterAdultContentKey = 'user_filter_adult_content';
  static const String _backgroundPlaybackKey = 'user_background_playback';
  static const String _pipEnabledKey = 'user_pip_enabled';

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

  Future<WatchHistoryItem?> getHistoryItem(
    String id, {
    int? season,
    int? episode,
  }) async {
    final history = await getWatchHistory();
    try {
      return history.firstWhere(
        (h) =>
            h.item.id == id &&
            (season == null || h.season == season) &&
            (episode == null || h.episode == episode),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Set<String>>> getAllWatchedEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_watchedEpisodesKey);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonStr);
      final Map<String, Set<String>> result = {};
      decoded.forEach((key, value) {
        if (value is List) {
          result[key] = value.map((e) => e.toString()).toSet();
        }
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<Set<String>> getWatchedEpisodes(String seriesId) async {
    final all = await getAllWatchedEpisodes();
    return all[seriesId] ?? {};
  }

  Future<void> setEpisodeWatched(
    String seriesId,
    int season,
    int episode,
    bool isWatched,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllWatchedEpisodes();
    final epKey = 's${season}_e$episode';
    final set = all[seriesId] ?? <String>{};
    if (isWatched) {
      set.add(epKey);
      all[seriesId] = set;
    } else {
      set.remove(epKey);
      if (set.isEmpty) {
        all.remove(seriesId);
      } else {
        all[seriesId] = set;
      }
    }
    final encoded = all.map((k, v) => MapEntry(k, v.toList()));
    await prefs.setString(_watchedEpisodesKey, jsonEncode(encoded));
  }

  Future<void> setSeasonWatched(
    String seriesId,
    int season,
    List<int> episodeNumbers,
    bool isWatched,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllWatchedEpisodes();
    final set = all[seriesId] ?? <String>{};
    for (final ep in episodeNumbers) {
      final epKey = 's${season}_e$ep';
      if (isWatched) {
        set.add(epKey);
      } else {
        set.remove(epKey);
      }
    }
    if (set.isEmpty) {
      all.remove(seriesId);
    } else {
      all[seriesId] = set;
    }
    final encoded = all.map((k, v) => MapEntry(k, v.toList()));
    await prefs.setString(_watchedEpisodesKey, jsonEncode(encoded));

    final history = await getWatchHistory();
    bool historyChanged = false;
    for (int i = 0; i < history.length; i++) {
      final h = history[i];
      if (h.item.id == seriesId && h.season == season) {
        history[i] = h.copyWith(isWatched: isWatched);
        historyChanged = true;
      }
    }
    if (historyChanged) {
      await prefs.setStringList(
        _historyKey,
        history.map((h) => jsonEncode(h.toJson())).toList(),
      );
    }
  }

  Future<bool> isEpisodeWatched(
    String seriesId,
    int season,
    int episode,
  ) async {
    final set = await getWatchedEpisodes(seriesId);
    return set.contains('s${season}_e$episode');
  }

  Future<void> updateHistoryWatchedStatus(
    String id, {
    int? season,
    int? episode,
    required bool isWatched,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory();
    bool changed = false;
    final updated = history.map((h) {
      if (h.item.id == id &&
          (season == null || h.season == season) &&
          (episode == null || h.episode == episode)) {
        changed = true;
        return h.copyWith(isWatched: isWatched);
      }
      return h;
    }).toList();

    if (changed) {
      await prefs.setStringList(
        _historyKey,
        updated.map((h) => jsonEncode(h.toJson())).toList(),
      );
    }
  }

  Future<void> savePlaybackProgress({
    required MediaItem item,
    required int positionSeconds,
    required int totalSeconds,
    int? season,
    int? episode,
    bool? isWatched,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory();

    final bool autoWatched =
        isWatched ??
        (totalSeconds > 0 &&
            (positionSeconds >= totalSeconds * 0.95 ||
                positionSeconds >= totalSeconds - 15));

    history.removeWhere(
      (h) => h.item.id == item.id && h.season == season && h.episode == episode,
    );

    history.insert(
      0,
      WatchHistoryItem(
        item: item,
        positionSeconds: positionSeconds,
        totalSeconds: totalSeconds,
        lastWatchedTimestamp: DateTime.now().millisecondsSinceEpoch,
        season: season,
        episode: episode,
        isWatched: autoWatched,
      ),
    );

    // Keep up to 50 items
    final trimmed = history.take(50).toList();
    await prefs.setStringList(
      _historyKey,
      trimmed.map((h) => jsonEncode(h.toJson())).toList(),
    );

    if (autoWatched && season != null && episode != null) {
      await setEpisodeWatched(item.id, season, episode, true);
    }
  }

  Future<void> removeWatchHistoryItem(
    String id, {
    int? season,
    int? episode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory();
    history.removeWhere(
      (h) =>
          h.item.id == id &&
          (season == null || h.season == season) &&
          (episode == null || h.episode == episode),
    );
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

  Future<String> getLiveTvCountry() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liveTvCountryKey) ?? 'IN';
  }

  Future<void> setLiveTvCountry(String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liveTvCountryKey, countryCode.toUpperCase());
  }

  Future<String> getLiveTvLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_liveTvLanguageKey) ?? 'ALL';
  }

  Future<void> setLiveTvLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liveTvLanguageKey, languageCode.toUpperCase());
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

  Future<double?> getUiScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_uiScaleKey);
  }

  Future<void> setUiScale(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_uiScaleKey, value);
  }

  Future<bool> getAutoCheckUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCheckUpdatesKey) ?? true;
  }

  Future<void> setAutoCheckUpdates(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckUpdatesKey, value);
  }

  Future<DateTime?> getLastUpdateCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastUpdateCheckKey);
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  Future<void> setLastUpdateCheckTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateCheckKey, time.millisecondsSinceEpoch);
  }

  Future<String?> getCornerStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cornerStyleKey);
  }

  Future<void> setCornerStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cornerStyleKey, style);
  }

  Future<String?> getSurfaceMorphism() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_surfaceMorphismKey);
  }

  Future<void> setSurfaceMorphism(String morphism) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_surfaceMorphismKey, morphism);
  }

  Future<String?> getFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontFamilyKey);
  }

  Future<void> setFontFamily(String? family) async {
    final prefs = await SharedPreferences.getInstance();
    if (family == null) {
      await prefs.remove(_fontFamilyKey);
    } else {
      await prefs.setString(_fontFamilyKey, family);
    }
  }

  Future<bool> getFilterAdultContent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_filterAdultContentKey) ?? true;
  }

  Future<void> setFilterAdultContent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_filterAdultContentKey, value);
  }

  Future<bool> getBackgroundPlayback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backgroundPlaybackKey) ?? false;
  }

  Future<void> setBackgroundPlayback(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundPlaybackKey, value);
  }

  Future<bool> getPipEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pipEnabledKey) ?? false;
  }

  Future<void> setPipEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pipEnabledKey, value);
  }
}
