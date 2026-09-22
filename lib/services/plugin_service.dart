import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exalere_plugin.dart';
import '../plugins/plugins.dart';
import 'provider_registry.dart';

/// Central service for installing, persisting, validating, and registering
/// Exalere Plugin Protocol compliant plugins in Exalere.
class PluginService {
  static final PluginService _instance = PluginService._internal();
  factory PluginService() => _instance;
  PluginService._internal();

  static const String _storageKey = 'exalere_installed_plugins_v1';
  static const String _legacyStorageKey = 'exalere_installed_addons_v1';
  http.Client _client = http.Client();

  @visibleForTesting
  set client(http.Client customClient) => _client = customClient;

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

      List<ExalerePluginConfig> configs = [];
      if (raw != null && raw.isNotEmpty) {
        final list = json.decode(raw) as List<dynamic>;
        configs = list
            .map(
              (item) =>
                  ExalerePluginConfig.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      // No auto-seeding: if the list is empty (fresh install or user uninstalled
      // everything), we leave the ProviderRegistry empty. The user must visit the
      // Plugin Store and explicitly install the plugins they want.

      // Sync ProviderRegistry to match exactly what is installed & enabled.
      // First, clear any previously registered providers so toggled/uninstalled
      // plugins don't linger across hot restarts or re-initializations.
      ProviderRegistry().clearAll();
      for (final config in configs) {
        if (config.isEnabled) {
          ProviderRegistry().registerProvider(createPlugin(config));
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
      ProviderRegistry().registerProvider(createPlugin(config));
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
    // Clear default if the uninstalled plugin was the default
    if (await getDefaultProviderId() == id) {
      await setDefaultProviderId(null);
    }
    debugPrint('[PluginService] Uninstalled Plugin: $id');
  }

  static const String _defaultProviderKey = 'exalere_default_provider_id_v1';

  /// Returns the ID of the user-designated default provider, or null if none set.
  Future<String?> getDefaultProviderId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultProviderKey);
  }

  /// Set or clear the default provider.
  /// Pass null to unset (fall back to all-providers mode).
  Future<void> setDefaultProviderId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_defaultProviderKey);
      ProviderRegistry().defaultProviderId = null;
      debugPrint('[PluginService] Default provider cleared.');
    } else {
      await prefs.setString(_defaultProviderKey, id);
      ProviderRegistry().defaultProviderId = id;
      debugPrint('[PluginService] Default provider set to: $id');
    }
  }

  /// Load the persisted default provider ID into the registry.
  Future<void> loadDefaultProvider() async {
    final id = await getDefaultProviderId();
    ProviderRegistry().defaultProviderId = id;
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
      ProviderRegistry().registerProvider(createPlugin(updated));
    } else {
      ProviderRegistry().unregisterProvider(id);
    }

    debugPrint('[PluginService] Toggled Plugin $id to isEnabled: $enabled');
  }

  static const String _catalogCacheKey = 'exalere_cached_community_catalog_v1';
  static const String pagesCatalogUrl =
      'https://abhishekrazy.github.io/Exalere/plugins.json';
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

  /// Fetch remote community catalog from GitHub Pages / repo with offline caching.
  Future<List<CommunityPluginItem>> fetchRemoteCommunityCatalog([
    String? catalogUrl,
  ]) async {
    final candidateUrls = catalogUrl != null
        ? [catalogUrl]
        : [pagesCatalogUrl, defaultCatalogUrl];

    for (final url in candidateUrls) {
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
              .map(
                (e) => CommunityPluginItem.fromJson(e as Map<String, dynamic>),
              )
              .where((item) => item.manifestUrl.isNotEmpty)
              .toList();

          if (items.isNotEmpty) {
            _cachedCatalog = items;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_catalogCacheKey, raw);
            debugPrint(
              '[PluginService] Updated community catalog with ${items.length} items from $url',
            );
            return items;
          }
        }
      } catch (e) {
        debugPrint(
          '[PluginService] Failed to fetch remote catalog from $url: $e',
        );
      }
    }

    if (_cachedCatalog.isEmpty) {
      await loadCachedCommunityCatalog();
    }
    return _cachedCatalog;
  }

  List<CommunityPluginItem> _getDefaultCommunityCatalog() {
    return const [
      CommunityPluginItem(
        id: 'com.stremio.thepiratebay.plus',
        name: 'ThePirateBay+ (TPB+)',
        description: 'High-speed peer-to-peer torrent streaming index for movies and TV series.',
        manifestUrl: 'https://thepiratebay-plus.strem.fun/manifest.json',
        author: 'TPB Community',
        isFeatured: true,
        tags: ['P2P', 'Torrents', 'Movies', 'TV'],
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
        id: 'com.elfhosted.mediafusion',
        name: 'MediaFusion',
        description: 'Multi-source stream provider featuring live sports, international TV, and media streams.',
        manifestUrl: 'https://mediafusion.elfhosted.com/manifest.json',
        author: 'Mhdzumair',
        isFeatured: false,
        tags: ['Live TV', 'Sports', 'Movies'],
      ),
      CommunityPluginItem(
        id: 'com.cyberflix.catalog',
        name: 'CyberFlix Catalog',
        description: 'Curated catalogs from popular streaming platforms (Netflix, Disney+, HBO Max, Apple TV+).',
        manifestUrl: 'https://cyberflix.elfhosted.com/manifest.json',
        author: 'CyberFlix Team',
        isFeatured: false,
        tags: ['Catalogs', 'OTT', 'Curated'],
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
