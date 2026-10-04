import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../models/subtitle_style_preferences.dart';
import '../models/user_playlist.dart';
import '../models/user_profile.dart';

class WatchHistoryItem {
  final MediaItem item;
  final int positionSeconds;
  final int totalSeconds;
  final int lastWatchedTimestamp;
  final int? season;
  final int? episode;
  final bool isWatched;
  final String? lastServer;
  final String? lastProviderId;
  final String? lastQuality;
  final String? lastStreamUrl;
  final Map<String, dynamic>? lastStreamData;

  const WatchHistoryItem({
    required this.item,
    required this.positionSeconds,
    required this.totalSeconds,
    required this.lastWatchedTimestamp,
    this.season,
    this.episode,
    this.isWatched = false,
    this.lastServer,
    this.lastProviderId,
    this.lastQuality,
    this.lastStreamUrl,
    this.lastStreamData,
  });

  StreamSource? get lastStream =>
      lastStreamData != null ? StreamSource.fromJson(lastStreamData!) : null;

  WatchHistoryItem copyWith({
    MediaItem? item,
    int? positionSeconds,
    int? totalSeconds,
    int? lastWatchedTimestamp,
    int? season,
    int? episode,
    bool? isWatched,
    String? lastServer,
    String? lastProviderId,
    String? lastQuality,
    String? lastStreamUrl,
    Map<String, dynamic>? lastStreamData,
  }) => WatchHistoryItem(
    item: item ?? this.item,
    positionSeconds: positionSeconds ?? this.positionSeconds,
    totalSeconds: totalSeconds ?? this.totalSeconds,
    lastWatchedTimestamp: lastWatchedTimestamp ?? this.lastWatchedTimestamp,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    isWatched: isWatched ?? this.isWatched,
    lastServer: lastServer ?? this.lastServer,
    lastProviderId: lastProviderId ?? this.lastProviderId,
    lastQuality: lastQuality ?? this.lastQuality,
    lastStreamUrl: lastStreamUrl ?? this.lastStreamUrl,
    lastStreamData: lastStreamData ?? this.lastStreamData,
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
    if (lastServer != null) 'lastServer': lastServer,
    if (lastProviderId != null) 'lastProviderId': lastProviderId,
    if (lastQuality != null) 'lastQuality': lastQuality,
    if (lastStreamUrl != null) 'lastStreamUrl': lastStreamUrl,
    if (lastStreamData != null) 'lastStreamData': lastStreamData,
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
        lastServer: json['lastServer'] as String?,
        lastProviderId: json['lastProviderId'] as String?,
        lastQuality: json['lastQuality'] as String?,
        lastStreamUrl: json['lastStreamUrl'] as String?,
        lastStreamData: json['lastStreamData'] as Map<String, dynamic>?,
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
  static const String _defaultAudioLanguageKey = 'user_default_audio_language';
  static const String _hasPromptedInitialLanguageKey =
      'user_has_prompted_initial_language';
  static const String _alreadyWatchedKey = 'user_already_watched_items';
  static const String _onlyShowAvailableOnProvidersKey =
      'user_only_show_available_on_providers';
  static const String _selectedCatalogProviderKey =
      'user_selected_catalog_provider';
  static const String _hasPromptedProviderSelectionKey =
      'user_has_prompted_provider_selection';

  static const String _profilesKey = 'user_profiles_list';
  static const String _activeProfileKey = 'user_active_profile_id';
  static const String _lanSyncEnabledKey = 'user_lan_sync_enabled';
  static const String _deviceIdKey = 'user_device_id';
  static const String _deviceNameKey = 'user_device_name';
  static const String _subtitleStyleKey = 'user_subtitle_style_prefs';
  static const String _liveTvFavoriteChannelsKey =
      'user_live_tv_favorite_channels';
  static const String _iptvPlaylistsKey = 'user_iptv_playlists_list';

  String _favoritesKeyFor(String? profileId) {
    if (profileId == null || profileId == 'default' || profileId.isEmpty) {
      return _favoritesKey;
    }
    return '${_favoritesKey}_$profileId';
  }

  String _alreadyWatchedKeyFor(String? profileId) {
    if (profileId == null || profileId == 'default' || profileId.isEmpty) {
      return _alreadyWatchedKey;
    }
    return '${_alreadyWatchedKey}_$profileId';
  }

  String _historyKeyFor(String? profileId) {
    if (profileId == null || profileId == 'default' || profileId.isEmpty) {
      return _historyKey;
    }
    return '${_historyKey}_$profileId';
  }

  String _watchedEpisodesKeyFor(String? profileId) {
    if (profileId == null || profileId == 'default' || profileId.isEmpty) {
      return _watchedEpisodesKey;
    }
    return '${_watchedEpisodesKey}_$profileId';
  }

  // Profile Management
  Future<List<UserProfile>> getProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_profilesKey);
    if (list == null || list.isEmpty) {
      final defaultProfile = UserProfile.createDefault();
      await saveProfiles([defaultProfile]);
      await setActiveProfileId(defaultProfile.id);
      return [defaultProfile];
    }
    final parsed = list
        .map((s) {
          try {
            return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<UserProfile>()
        .toList();
    if (parsed.isEmpty) {
      final defaultProfile = UserProfile.createDefault();
      await saveProfiles([defaultProfile]);
      await setActiveProfileId(defaultProfile.id);
      return [defaultProfile];
    }
    return parsed;
  }

  Future<void> saveProfiles(List<UserProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _profilesKey,
      profiles.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<String> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeProfileKey) ?? 'default';
  }

  Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, id);
  }

  // LAN Sync Settings
  Future<bool> getLanSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lanSyncEnabledKey) ?? true;
  }

  Future<void> setLanSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lanSyncEnabledKey, enabled);
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id =
          'exalere_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<String?> getCustomDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceNameKey);
  }

  Future<void> setCustomDeviceName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceNameKey, name);
  }

  // Profile-Scoped Favorites
  Future<List<MediaItem>> getFavorites({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _favoritesKeyFor(profileId);
    final list = prefs.getStringList(key) ?? [];
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

  Future<bool> isFavorite(String id, {String? profileId}) async {
    final favs = await getFavorites(profileId: profileId);
    return favs.any((item) => item.id == id);
  }

  Future<void> toggleFavorite(MediaItem item, {String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavorites(profileId: profileId);
    final index = favs.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      favs.removeAt(index);
    } else {
      favs.insert(0, item);
    }
    await prefs.setStringList(
      _favoritesKeyFor(profileId),
      favs.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  Future<void> saveFavorites(List<MediaItem> items, {String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKeyFor(profileId),
      items.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  // Profile-Scoped Already Watched
  Future<List<MediaItem>> getAlreadyWatched({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_alreadyWatchedKeyFor(profileId)) ?? [];
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

  Future<bool> isAlreadyWatched(String id, {String? profileId}) async {
    final items = await getAlreadyWatched(profileId: profileId);
    return items.any((item) => item.id == id);
  }

  Future<bool> toggleAlreadyWatched(MediaItem item, {String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getAlreadyWatched(profileId: profileId);
    final index = items.indexWhere((i) => i.id == item.id);
    bool added;
    if (index >= 0) {
      items.removeAt(index);
      added = false;
    } else {
      items.insert(0, item);
      added = true;
    }
    await prefs.setStringList(
      _alreadyWatchedKeyFor(profileId),
      items.map((i) => jsonEncode(i.toJson())).toList(),
    );
    return added;
  }

  Future<void> saveAlreadyWatched(
    List<MediaItem> items, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _alreadyWatchedKeyFor(profileId),
      items.map((i) => jsonEncode(i.toJson())).toList(),
    );
  }

  Future<void> setAlreadyWatched(
    MediaItem item,
    bool isWatched, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getAlreadyWatched(profileId: profileId);
    final index = items.indexWhere((i) => i.id == item.id);
    if (isWatched && index < 0) {
      items.insert(0, item);
      await prefs.setStringList(
        _alreadyWatchedKeyFor(profileId),
        items.map((i) => jsonEncode(i.toJson())).toList(),
      );
    } else if (!isWatched && index >= 0) {
      items.removeAt(index);
      await prefs.setStringList(
        _alreadyWatchedKeyFor(profileId),
        items.map((i) => jsonEncode(i.toJson())).toList(),
      );
    }
  }

  Future<bool> getOnlyShowAvailableOnProviders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onlyShowAvailableOnProvidersKey) ?? true;
  }

  Future<void> setOnlyShowAvailableOnProviders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlyShowAvailableOnProvidersKey, value);
  }

  Future<List<WatchHistoryItem>> getWatchHistory({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKeyFor(profileId)) ?? [];
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

  Future<void> saveWatchHistory(
    List<WatchHistoryItem> history, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKeyFor(profileId),
      history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<WatchHistoryItem?> getHistoryItem(
    String id, {
    int? season,
    int? episode,
    String? profileId,
  }) async {
    final history = await getWatchHistory(profileId: profileId);
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

  Future<Map<String, Set<String>>> getAllWatchedEpisodes({
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_watchedEpisodesKeyFor(profileId));
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

  Future<void> saveAllWatchedEpisodes(
    Map<String, Set<String>> episodes, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = episodes.map((k, v) => MapEntry(k, v.toList()));
    await prefs.setString(
      _watchedEpisodesKeyFor(profileId),
      jsonEncode(encoded),
    );
  }

  Future<Set<String>> getWatchedEpisodes(
    String seriesId, {
    String? profileId,
  }) async {
    final all = await getAllWatchedEpisodes(profileId: profileId);
    return all[seriesId] ?? {};
  }

  Future<void> setEpisodeWatched(
    String seriesId,
    int season,
    int episode,
    bool isWatched, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllWatchedEpisodes(profileId: profileId);
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
    await prefs.setString(
      _watchedEpisodesKeyFor(profileId),
      jsonEncode(encoded),
    );
  }

  Future<void> setSeasonWatched(
    String seriesId,
    int season,
    List<int> episodeNumbers,
    bool isWatched, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAllWatchedEpisodes(profileId: profileId);
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
    await prefs.setString(
      _watchedEpisodesKeyFor(profileId),
      jsonEncode(encoded),
    );

    final history = await getWatchHistory(profileId: profileId);
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
        _historyKeyFor(profileId),
        history.map((h) => jsonEncode(h.toJson())).toList(),
      );
    }
  }

  Future<bool> isEpisodeWatched(
    String seriesId,
    int season,
    int episode, {
    String? profileId,
  }) async {
    final set = await getWatchedEpisodes(seriesId, profileId: profileId);
    return set.contains('s${season}_e$episode');
  }

  Future<void> updateHistoryWatchedStatus(
    String id, {
    int? season,
    int? episode,
    required bool isWatched,
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory(profileId: profileId);
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
        _historyKeyFor(profileId),
        updated.map((h) => jsonEncode(h.toJson())).toList(),
      );
    }
  }

  static const String _titleLastStreamPrefix = 'user_title_last_stream_';

  Future<void> saveTitleLastStream(String mediaId, StreamSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_titleLastStreamPrefix$mediaId',
      jsonEncode(source.toJson()),
    );
  }

  Future<StreamSource?> getTitleLastStream(String mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_titleLastStreamPrefix$mediaId');
    if (raw == null || raw.isEmpty) return null;
    try {
      return StreamSource.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    bool? isWatched,
    StreamSource? streamSource,
    String? lastServer,
    String? lastProviderId,
    String? lastQuality,
    String? lastStreamUrl,
    Map<String, dynamic>? lastStreamData,
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory(profileId: profileId);

    final bool autoWatched =
        isWatched ??
        (totalSeconds > 0 &&
            (positionSeconds >= totalSeconds * 0.95 ||
                positionSeconds >= totalSeconds - 15));

    // Determine stream metadata to save
    String? effectiveServer = lastServer ?? streamSource?.effectiveProviderName;
    String? effectiveProviderId =
        lastProviderId ?? streamSource?.effectiveProviderId;
    String? effectiveQuality = lastQuality ?? streamSource?.quality;
    String? effectiveUrl = lastStreamUrl ?? streamSource?.url;
    Map<String, dynamic>? effectiveStreamData =
        lastStreamData ?? streamSource?.toJson();

    if (streamSource != null) {
      await saveTitleLastStream(item.id, streamSource);
    } else if (effectiveServer == null && effectiveStreamData == null) {
      // Preserve previously saved stream metadata for this title if available
      final existingStream = await getTitleLastStream(item.id);
      if (existingStream != null) {
        effectiveServer = existingStream.effectiveProviderName;
        effectiveProviderId = existingStream.effectiveProviderId;
        effectiveQuality = existingStream.quality;
        effectiveUrl = existingStream.url;
        effectiveStreamData = existingStream.toJson();
      }
    }

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
        lastServer: effectiveServer,
        lastProviderId: effectiveProviderId,
        lastQuality: effectiveQuality,
        lastStreamUrl: effectiveUrl,
        lastStreamData: effectiveStreamData,
      ),
    );

    // Keep up to 50 items
    final trimmed = history.take(50).toList();
    await prefs.setStringList(
      _historyKeyFor(profileId),
      trimmed.map((h) => jsonEncode(h.toJson())).toList(),
    );

    if (autoWatched && season != null && episode != null) {
      await setEpisodeWatched(
        item.id,
        season,
        episode,
        true,
        profileId: profileId,
      );
    }
  }

  Future<void> removeWatchHistoryItem(
    String id, {
    int? season,
    int? episode,
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getWatchHistory(profileId: profileId);
    history.removeWhere(
      (h) =>
          h.item.id == id &&
          (season == null || h.season == season) &&
          (episode == null || h.episode == episode),
    );
    await prefs.setStringList(
      _historyKeyFor(profileId),
      history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> clearWatchHistory({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKeyFor(profileId));
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

  // Live TV Favorites
  Future<List<String>> getLiveTvFavoriteChannelIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_liveTvFavoriteChannelsKey) ?? [];
  }

  Future<void> toggleLiveTvFavoriteChannel(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = List<String>.from(
      prefs.getStringList(_liveTvFavoriteChannelsKey) ?? [],
    );
    if (list.contains(channelId)) {
      list.remove(channelId);
    } else {
      list.add(channelId);
    }
    await prefs.setStringList(_liveTvFavoriteChannelsKey, list);
  }

  Future<bool> isLiveTvChannelFavorite(String channelId) async {
    final favs = await getLiveTvFavoriteChannelIds();
    return favs.contains(channelId);
  }

  // Multi-M3U Playlists
  Future<List<Map<String, String>>> getIptvPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_iptvPlaylistsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveIptvPlaylists(List<Map<String, String>> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_iptvPlaylistsKey, jsonEncode(playlists));
  }

  // Custom User Watchlists & Playlists (Per-Profile)
  static const String _userPlaylistsPrefix = 'user_playlists_';
  String _effectiveProfileId(String? profileId) {
    if (profileId == null || profileId == 'default' || profileId.isEmpty) {
      return 'default';
    }
    return profileId;
  }

  String _userPlaylistsKeyFor(String? profileId) =>
      '$_userPlaylistsPrefix${_effectiveProfileId(profileId)}';

  Future<List<UserPlaylist>> getUserPlaylists({String? profileId}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userPlaylistsKeyFor(profileId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (e) => UserPlaylist.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUserPlaylists(
    List<UserPlaylist> playlists, {
    String? profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = playlists.map((p) => p.toJson()).toList();
    await prefs.setString(_userPlaylistsKeyFor(profileId), jsonEncode(list));
  }

  Future<UserPlaylist> createUserPlaylist(
    String name, {
    String? profileId,
  }) async {
    final playlists = await getUserPlaylists(profileId: profileId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final newPlaylist = UserPlaylist(
      id: 'pl_${now}_${playlists.length}',
      name: name.trim().isNotEmpty ? name.trim() : 'New Playlist',
      profileId: _effectiveProfileId(profileId),
      createdAt: now,
      updatedAt: now,
      items: const [],
    );
    playlists.add(newPlaylist);
    await saveUserPlaylists(playlists, profileId: profileId);
    return newPlaylist;
  }

  Future<void> deleteUserPlaylist(
    String playlistId, {
    String? profileId,
  }) async {
    final playlists = await getUserPlaylists(profileId: profileId);
    playlists.removeWhere((p) => p.id == playlistId);
    await saveUserPlaylists(playlists, profileId: profileId);
  }

  Future<void> addToUserPlaylist(
    String playlistId,
    MediaItem item, {
    String? profileId,
  }) async {
    final playlists = await getUserPlaylists(profileId: profileId);
    final idx = playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final target = playlists[idx];
      if (!target.items.any((i) => i.id == item.id)) {
        final updatedItems = [item, ...target.items];
        playlists[idx] = target.copyWith(
          items: updatedItems,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await saveUserPlaylists(playlists, profileId: profileId);
      }
    }
  }

  Future<void> removeFromUserPlaylist(
    String playlistId,
    String mediaId, {
    String? profileId,
  }) async {
    final playlists = await getUserPlaylists(profileId: profileId);
    final idx = playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final target = playlists[idx];
      final updatedItems = target.items.where((i) => i.id != mediaId).toList();
      playlists[idx] = target.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await saveUserPlaylists(playlists, profileId: profileId);
    }
  }

  Future<void> renameUserPlaylist(
    String playlistId,
    String newName, {
    String? profileId,
  }) async {
    final playlists = await getUserPlaylists(profileId: profileId);
    final idx = playlists.indexWhere((p) => p.id == playlistId);
    if (idx != -1) {
      final target = playlists[idx];
      playlists[idx] = target.copyWith(
        name: newName.trim().isNotEmpty ? newName.trim() : target.name,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await saveUserPlaylists(playlists, profileId: profileId);
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

  /// Returns the persisted set of selected language codes.
  /// An empty set or a set containing only 'ALL' means no language filter.
  Future<Set<String>> getLiveTvLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_liveTvLanguageKey) ?? 'ALL';
    if (raw.isEmpty || raw.toUpperCase() == 'ALL') return <String>{'ALL'};
    return raw
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  Future<void> setLiveTvLanguages(Set<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    final upper = codes.map((c) => c.toUpperCase()).toSet();
    // If contains ALL or is empty, normalize to 'ALL'
    if (upper.isEmpty || upper.contains('ALL')) {
      await prefs.setString(_liveTvLanguageKey, 'ALL');
    } else {
      await prefs.setString(_liveTvLanguageKey, upper.join(','));
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

  Future<bool> getAutoPlayTrailers({bool isTv = false}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPlayTrailersKey) ?? !isTv;
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
    return prefs.getBool(_pipEnabledKey) ?? true;
  }

  Future<void> setPipEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pipEnabledKey, value);
  }

  Future<String?> getDefaultAudioLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultAudioLanguageKey);
  }

  Future<void> setDefaultAudioLanguage(String? language) async {
    final prefs = await SharedPreferences.getInstance();
    if (language == null) {
      await prefs.remove(_defaultAudioLanguageKey);
    } else {
      await prefs.setString(_defaultAudioLanguageKey, language);
    }
  }

  Future<bool> getHasPromptedInitialLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPromptedInitialLanguageKey) ?? false;
  }

  Future<void> setHasPromptedInitialLanguage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasPromptedInitialLanguageKey, value);
  }

  Future<String> getSelectedCatalogProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedCatalogProviderKey) ?? 'tmdb';
  }

  Future<void> setSelectedCatalogProvider(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedCatalogProviderKey, providerId);
  }

  Future<bool> getHasPromptedProviderSelection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasPromptedProviderSelectionKey) ?? false;
  }

  Future<void> setHasPromptedProviderSelection(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasPromptedProviderSelectionKey, value);
  }

  Future<SubtitleStylePreferences> getSubtitleStylePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_subtitleStyleKey);
    return SubtitleStylePreferences.decode(raw);
  }

  Future<void> saveSubtitleStylePreferences(
    SubtitleStylePreferences style,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_subtitleStyleKey, style.encode());
  }
}
