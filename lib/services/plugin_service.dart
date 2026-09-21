import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exalere_plugin.dart';
import 'exalere_plugin_adapter.dart';
import 'provider_registry.dart';
import 'vidsrc_provider.dart';

/// Central service for installing, persisting, validating, and registering
/// Exalere Plugin Protocol compliant plugins in Exalere.
class PluginService {
  static final PluginService _instance = PluginService._internal();
  factory PluginService() => _instance;
  PluginService._internal();

  static const String _storageKey = 'exalere_installed_plugins_v1';
  static const String _legacyStorageKey = 'exalere_installed_addons_v1';
  final http.Client _client = http.Client();

  /// Normalize a user-entered Plugin URL.
  /// Handles trailing slashes, /manifest.json suffix, and optional scheme prefixes.
  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.startsWith('exalere://')) {
      url = 'https://${url.substring('exalere://'.length)}';
    }
    if (url.startsWith('stremio://')) {
      url = 'https://${url.substring('stremio://'.length)}';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/manifest.json')) {
      url = url.substring(0, url.length - '/manifest.json'.length);
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Fetch and validate the manifest of a Plugin from its base URL.
  Future<ExalerePluginManifest> fetchManifest(String inputUrl) async {
    final baseUrl = normalizeUrl(inputUrl);
    final manifestUri = Uri.parse('$baseUrl/manifest.json');

    debugPrint('[PluginService] Fetching manifest from: $manifestUri');
    final response = await _client
        .get(
          manifestUri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Exalere/1.0 (Plugin-Client)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception(
        'Server returned HTTP ${response.statusCode}. Please verify the Plugin URL.',
      );
    }

    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final manifest = ExalerePluginManifest.fromJson(data);

    if (manifest.id.isEmpty) {
      throw Exception('Invalid Plugin manifest: missing required "id" field.');
    }

    return manifest;
  }

  /// Load all persisted plugins from [SharedPreferences] and register enabled ones
  /// into [ProviderRegistry].
  Future<List<ExalerePluginConfig>> loadInstalledPlugins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        // Fallback to check legacy key
        raw = prefs.getString(_legacyStorageKey);
      }
      if (raw == null || raw.isEmpty) return [];

      final list = json.decode(raw) as List<dynamic>;
      final configs = list
          .map(
            (item) =>
                ExalerePluginConfig.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      for (final config in configs) {
        if (config.isEnabled) {
          if (config.id == 'moviebox') {
            ProviderRegistry().registerProvider(MovieBoxAdapter());
          } else if (config.id == 'vidsrc') {
            ProviderRegistry().registerProvider(VidSrcProvider());
          } else if (config.id == 'fourkhdhub') {
            ProviderRegistry().registerProvider(FourKHdHubAdapter());
          } else if (config.manifest?.supportsStreams ?? true) {
            ProviderRegistry().registerProvider(
              ExalerePluginAdapter(config: config),
            );
          }
        } else {
          ProviderRegistry().unregisterProvider(config.id);
        }
      }

      debugPrint(
        '[PluginService] Loaded ${configs.length} installed plugin(s).',
      );
      return configs;
    } catch (e) {
      debugPrint('[PluginService] Error loading installed plugins: $e');
      return [];
    }
  }

  /// Install a new Plugin by URL.
  /// Fetches the manifest, verifies compatibility, persists to storage,
  /// and registers it into [ProviderRegistry].
  Future<ExalerePluginConfig> installPlugin(String inputUrl) async {
    final trimmed = inputUrl.trim();
    if (trimmed == 'moviebox' ||
        trimmed == 'moviebox://engine' ||
        trimmed == 'https://moviebox://engine') {
      const manifest = ExalerePluginManifest(
        id: 'moviebox',
        name: 'MovieBox Engine',
        version: '1.0.0',
        description: 'Community MovieBox engine scraper & stream resolver with dynamic endpoint sync.',
        resources: ['stream'],
        types: ['movie', 'series'],
      );

      final config = ExalerePluginConfig(
        id: 'moviebox',
        name: 'MovieBox Engine',
        baseUrl: 'https://github.com/mesamirh/MovieBox-Tui',
        isEnabled: true,
        addedAt: DateTime.now(),
        manifest: manifest,
      );

      final existing = await loadInstalledPlugins();
      existing.removeWhere((c) => c.id == config.id);
      existing.add(config);

      await _savePlugins(existing);
      ProviderRegistry().registerProvider(MovieBoxAdapter());
      debugPrint(
        '[PluginService] Successfully installed Plugin: ${config.name} (${config.id})',
      );
      return config;
    }

    if (trimmed == 'vidsrc' ||
        trimmed == 'vidsrc://engine' ||
        trimmed == 'https://vidsrc://engine' ||
        trimmed == 'https://vidsrc.sh' ||
        trimmed == 'https://vidsrc.sh/' ||
        trimmed == 'vidsrc.sh') {
      const manifest = ExalerePluginManifest(
        id: 'vidsrc',
        name: 'VidSrc Engine',
        version: '1.0.0',
        description: 'VidSrc media provider with 9 redundant mirrors and fast embed streaming (vidsrc.sh).',
        resources: ['stream'],
        types: ['movie', 'series'],
      );

      final config = ExalerePluginConfig(
        id: 'vidsrc',
        name: 'VidSrc Engine',
        baseUrl: 'https://vidsrc.sh',
        isEnabled: true,
        addedAt: DateTime.now(),
        manifest: manifest,
      );

      final existing = await loadInstalledPlugins();
      existing.removeWhere((c) => c.id == config.id);
      existing.add(config);

      await _savePlugins(existing);
      ProviderRegistry().registerProvider(VidSrcProvider());
      debugPrint(
        '[PluginService] Successfully installed Plugin: ${config.name} (${config.id})',
      );
      return config;
    }

    if (trimmed == 'fourkhdhub' ||
        trimmed == 'fourkhdhub://engine' ||
        trimmed == 'https://fourkhdhub://engine') {
      const manifest = ExalerePluginManifest(
        id: 'fourkhdhub',
        name: '4K HD Hub Engine',
        version: '1.0.0',
        description:
            'Community 4K HD Hub direct scraper for high-quality movies.',
        resources: ['stream'],
        types: ['movie'],
      );

      final config = ExalerePluginConfig(
        id: 'fourkhdhub',
        name: '4K HD Hub Engine',
        baseUrl: 'fourkhdhub://engine',
        isEnabled: true,
        addedAt: DateTime.now(),
        manifest: manifest,
      );

      final existing = await loadInstalledPlugins();
      existing.removeWhere((c) => c.id == config.id);
      existing.add(config);

      await _savePlugins(existing);
      ProviderRegistry().registerProvider(FourKHdHubAdapter());
      debugPrint(
        '[PluginService] Successfully installed Plugin: ${config.name} (${config.id})',
      );
      return config;
    }

    final baseUrl = normalizeUrl(inputUrl);
    final manifest = await fetchManifest(baseUrl);

    final config = ExalerePluginConfig(
      id: manifest.id,
      name: manifest.name,
      baseUrl: baseUrl,
      isEnabled: true,
      addedAt: DateTime.now(),
      manifest: manifest,
    );

    final existing = await loadInstalledPlugins();
    existing.removeWhere((c) => c.id == config.id);
    existing.add(config);

    await _savePlugins(existing);
    if (manifest.supportsStreams) {
      ProviderRegistry().registerProvider(ExalerePluginAdapter(config: config));
    }
    debugPrint(
      '[PluginService] Successfully installed Plugin: ${config.name} (${config.id})',
    );
    return config;
  }

  /// Uninstall a Plugin by ID.
  Future<void> uninstallPlugin(String id) async {
    final existing = await loadInstalledPlugins();
    existing.removeWhere((c) => c.id == id);
    await _savePlugins(existing);
    ProviderRegistry().unregisterProvider(id);
    debugPrint('[PluginService] Uninstalled Plugin: $id');
  }

  /// Toggle a Plugin's enabled status.
  Future<void> togglePlugin(String id, bool enabled) async {
    final existing = await loadInstalledPlugins();
    final index = existing.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final updated = existing[index].copyWith(isEnabled: enabled);
    existing[index] = updated;
    await _savePlugins(existing);

    if (enabled) {
      if (id == 'moviebox') {
        ProviderRegistry().registerProvider(MovieBoxAdapter());
      } else if (id == 'vidsrc') {
        ProviderRegistry().registerProvider(VidSrcProvider());
      } else if (id == 'fourkhdhub') {
        ProviderRegistry().registerProvider(FourKHdHubAdapter());
      } else if (updated.manifest?.supportsStreams ?? true) {
        ProviderRegistry().registerProvider(
          ExalerePluginAdapter(config: updated),
        );
      }
    } else {
      ProviderRegistry().unregisterProvider(id);
    }
    debugPrint('[PluginService] Toggled Plugin $id to isEnabled: $enabled');
  }

  static const String _catalogCacheKey = 'exalere_cached_community_catalog_v1';
  static const String defaultCatalogUrl =
      'https://raw.githubusercontent.com/Abhishekrazy/Exalere/main/community_addons.json';

  List<CommunityPluginItem> _cachedCatalog = [];

  Future<void> _savePlugins(List<ExalerePluginConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Curated directory of community-maintained plugins and Stremio addons.
  List<CommunityPluginItem> getCommunityCatalog() {
    if (_cachedCatalog.isNotEmpty) {
      return _cachedCatalog;
    }
    return _getDefaultCommunityCatalog();
  }

  /// Load cached catalog from local storage or fallback to defaults.
  Future<List<CommunityPluginItem>> loadCachedCommunityCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_catalogCacheKey);
      if (raw != null && raw.isNotEmpty) {
        final list = json.decode(raw) as List<dynamic>;
        _cachedCatalog = list
            .map((e) => CommunityPluginItem.fromJson(e as Map<String, dynamic>))
            .where((item) => item.manifestUrl.isNotEmpty)
            .toList();
        if (_cachedCatalog.isNotEmpty) {
          return _cachedCatalog;
        }
      }
    } catch (e) {
      debugPrint('[PluginService] Error loading cached catalog: $e');
    }
    _cachedCatalog = _getDefaultCommunityCatalog();
    return _cachedCatalog;
  }

  /// Fetch remote community catalog from GitHub or remote server with offline caching.
  Future<List<CommunityPluginItem>> fetchRemoteCommunityCatalog([
    String? catalogUrl,
  ]) async {
    final url = catalogUrl ?? defaultCatalogUrl;
    try {
      debugPrint(
        '[PluginService] Fetching remote community catalog from: $url',
      );
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Plugin-Catalog-Client)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final raw = utf8.decode(response.bodyBytes);
        final list = json.decode(raw) as List<dynamic>;
        final items = list
            .map((e) => CommunityPluginItem.fromJson(e as Map<String, dynamic>))
            .where((item) => item.manifestUrl.isNotEmpty)
            .toList();

        if (items.isNotEmpty) {
          _cachedCatalog = items;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_catalogCacheKey, raw);
          debugPrint(
            '[PluginService] Updated community catalog with ${items.length} items from remote.',
          );
          return items;
        }
      }
    } catch (e) {
      debugPrint('[PluginService] Failed to fetch remote catalog: $e');
    }

    if (_cachedCatalog.isEmpty) {
      await loadCachedCommunityCatalog();
    }
    return _cachedCatalog;
  }

  List<CommunityPluginItem> _getDefaultCommunityCatalog() {
    return const [
      CommunityPluginItem(
        id: 'vidsrc',
        name: 'VidSrc Engine',
        description: 'Multi-mirror streaming engine with fast embeds and resilient failover (vidsrc.sh).',
        manifestUrl: 'vidsrc://engine',
        author: 'vidsrc.sh',
        isFeatured: true,
        tags: ['Fast', 'Movies', 'TV', 'Embed', 'HLS'],
      ),
      CommunityPluginItem(
        id: 'moviebox',
        name: 'MovieBox Engine',
        description: 'Community MovieBox engine scraper & stream resolver with dynamic endpoint sync.',
        manifestUrl: 'moviebox://engine',
        author: 'mesamirh',
        isFeatured: true,
        tags: ['Fast', 'Movies', 'TV', 'Multi-Audio'],
      ),
      CommunityPluginItem(
        id: 'fourkhdhub',
        name: '4K HD Hub Engine',
        description: 'Direct high-speed 4K/1080p stream scraper for movies.',
        manifestUrl: 'fourkhdhub://engine',
        author: 'Community',
        isFeatured: false,
        tags: ['4K', 'Movies', 'Direct'],
      ),
      CommunityPluginItem(
        id: 'com.stremio.torrentio.addon',
        name: 'Torrentio (Stremio Addon)',
        description: 'Multi-provider stream scraper compatible with Real-Debrid, AllDebrid & Premiumize.',
        manifestUrl: 'https://torrentio.strem.fun/manifest.json',
        author: 'TheAddonBay',
        isFeatured: true,
        tags: ['Stremio', '4K HDR', 'Debrid'],
      ),
      CommunityPluginItem(
        id: 'org.stremio.opensubtitlesv3',
        name: 'OpenSubtitles v3',
        description: 'Community subtitle addon providing synced subtitles in 75+ global languages.',
        manifestUrl: 'https://opensubtitles-v3.strem.io/manifest.json',
        author: 'OpenSubtitles.org',
        isFeatured: false,
        tags: ['Subtitles', 'Multi-Language'],
      ),
      CommunityPluginItem(
        id: 'com.linvo.cinemeta',
        name: 'Cinemeta (Official)',
        description: 'Official Stremio movie and TV series metadata and catalog provider.',
        manifestUrl: 'https://v3-cinemeta.strem.io/manifest.json',
        author: 'Stremio',
        isFeatured: false,
        tags: ['Metadata', 'Official'],
      ),
      CommunityPluginItem(
        id: 'community.anime.kitsu',
        name: 'Anime Kitsu',
        description: 'Anime catalog and streaming index powered by Kitsu.io.',
        manifestUrl: 'https://anime-kitsu.strem.fun/manifest.json',
        author: 'Community',
        isFeatured: false,
        tags: ['Anime', 'Stremio'],
      ),
      CommunityPluginItem(
        id: 'org.stremio.internet-archive',
        name: 'Archivio (Internet Archive)',
        description:
            'Stream public domain and historical archive movies and video.',
        manifestUrl: 'https://archivio.elfhosted.com/manifest.json',
        author: 'ElfHosted',
        isFeatured: false,
        tags: ['Public Domain', 'Movies'],
      ),
    ];
  }
}
