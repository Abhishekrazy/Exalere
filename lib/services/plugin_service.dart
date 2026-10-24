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

  /// Marks that the first-launch defaults have been installed. Persisted
  /// separately from the plugin list so removing a seeded plugin is permanent.
  static const String _seedMarkerKey = 'exalere_plugins_seeded_v1';
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

  /// Manifests for engines that ship inside the app instead of being hosted
  /// remotely. Their catalog entries use a private scheme (e.g.
  /// `circleftp://engine`) so no network manifest fetch is possible or needed.
  static const Map<String, ExalerePluginManifest> builtInEngineManifests = {
    // Seeded on first launch. Metadata only: it powers discovery, ratings and
    // artwork, and deliberately exposes no stream resource, so having it
    // installed never makes the app claim a title is playable.
    'tmdb': ExalerePluginManifest(
      id: 'tmdb',
      name: 'TMDB (The Movie Database)',
      version: '1.0.0',
      description:
          'Metadata catalogue: trending, popular and genre discovery with '
          'ratings and artwork. Never resolves a stream.',
      resources: ['catalog'],
      types: ['movie', 'series'],
      idPrefixes: ['tt'],
    ),
    'circleftp': ExalerePluginManifest(
      id: 'circleftp',
      name: 'CircleFTP (BDIX)',
      version: '1.0.0',
      description:
          'High-speed local streaming on the Bangladesh Internet Exchange.',
      resources: ['stream', 'meta'],
      types: ['movie', 'series'],
      idPrefixes: ['tt', 'circleftp'],
    ),
    'moviesdrive': ExalerePluginManifest(
      id: 'moviesdrive',
      name: 'MoviesDrive',
      version: '1.0.0',
      description:
          'Native scraper for MoviesDrive. Searches its JSON index and resolves '
          'HubCloud, PixelDrain and CDN sources.',
      resources: ['stream', 'meta'],
      types: ['movie', 'series'],
      idPrefixes: ['tt', 'moviesdrive'],
    ),
    'uhdmovies': ExalerePluginManifest(
      id: 'uhdmovies',
      name: 'UHDMovies',
      version: '1.0.0',
      description:
          'Native scraper for UHDMovies. Resolves HubCloud, PixelDrain and CDN '
          'sources; shortlink-gated links are skipped rather than faked.',
      resources: ['stream', 'meta'],
      types: ['movie', 'series'],
      idPrefixes: ['tt', 'uhdmovies'],
    ),
    'moviesmod': ExalerePluginManifest(
      id: 'moviesmod',
      name: 'MoviesMod',
      version: '1.0.0',
      description:
          'Native scraper for MoviesMod. Resolves HubCloud, PixelDrain and CDN '
          'sources; shortlink-gated links are skipped rather than faked.',
      resources: ['stream', 'meta'],
      types: ['movie', 'series'],
      idPrefixes: ['tt', 'moviesmod'],
    ),
    'hdhub4u': ExalerePluginManifest(
      id: 'hdhub4u',
      name: 'HDHub4u',
      version: '1.0.0',
      description:
          'Native scraper for HDHub4u. Resolves HubCloud, PixelDrain and CDN '
          'sources; the domain is refreshed automatically when the site moves.',
      resources: ['stream', 'meta'],
      types: ['movie', 'series'],
      idPrefixes: ['tt', 'hdhub4u'],
    ),
  };

  /// Returns the built-in engine manifest addressed by [inputUrl], or `null`
  /// when the URL points at a remote plugin.
  static ExalerePluginManifest? builtInEngineFor(String inputUrl) {
    final raw = inputUrl.trim().toLowerCase();
    // Match any built-in engine by its private scheme, so adding one to the map
    // above is enough to make it installable.
    for (final entry in builtInEngineManifests.entries) {
      if (raw.startsWith('${entry.key}://')) return entry.value;
    }
    return null;
  }

  /// Whether a remote catalog addon can list titles but never resolve a stream.
  ///
  /// Such addons are still worth installing for their catalogs, but they must
  /// never be treated as proof that a title is watchable.
  static bool isMetadataOnlyManifest(ExalerePluginManifest manifest) =>
      !manifest.supportsStreams && manifest.hasCatalogs;

  /// Fetch and validate the manifest of a Plugin from its base URL.
  Future<ExalerePluginManifest> fetchManifest(String inputUrl) async {
    final builtIn = builtInEngineFor(inputUrl);
    if (builtIn != null) return builtIn;

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
      // Seed the metadata plugin on a first launch so the app can show a
      // catalogue out of the box, then honour the user's list exactly. Seeding
      // is one-shot: an explicitly uninstalled TMDB must not come back.
      configs = await _seedDefaultPlugins(configs);

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
    final builtIn = builtInEngineFor(inputUrl);
    // Built-in engines keep their private scheme: it is a stable identifier, and
    // rewriting it into an https URL would produce an unreachable host.
    final baseUrl = builtIn != null ? inputUrl.trim() : normalizeUrl(inputUrl);
    final manifest = await fetchManifest(inputUrl);

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
    // Register unconditionally so an installed addon behaves the same after a
    // restart as it did at install time. Capability flags decide what it may
    // contribute: metadata-only addons serve catalogs, never streams.
    ProviderRegistry().registerProvider(createPlugin(config));
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

  /// Installs the metadata plugin on a fresh install.
  ///
  /// Runs exactly once, guarded by [_seedMarkerKey]: if the user later removes
  /// TMDB it must stay removed instead of reappearing on every launch. It is
  /// also skipped when plugins already exist, so an upgrade from a build without
  /// seeding does not overwrite a real list.
  Future<List<ExalerePluginConfig>> _seedDefaultPlugins(
    List<ExalerePluginConfig> configs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seedMarkerKey) ?? false) return configs;
    await prefs.setBool(_seedMarkerKey, true);

    if (configs.isNotEmpty) return configs;

    final manifest = builtInEngineManifests['tmdb'];
    final seeded = <ExalerePluginConfig>[
      ExalerePluginConfig(
        id: 'tmdb',
        name: manifest?.name ?? 'TMDB (The Movie Database)',
        // A private scheme: TMDB is built in, so it has no remote manifest host.
        baseUrl: 'tmdb://metadata',
        isEnabled: true,
        addedAt: DateTime.now(),
        manifest: manifest,
      ),
    ];
    await _savePlugins(seeded);
    debugPrint('[PluginService] Seeded default plugin: TMDB (metadata only).');
    return seeded;
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
        id: 'org.exalere.moviebox',
        name: 'MovieBox Engine',
        description:
            'Community MovieBox engine scraper & stream resolver with dynamic endpoint sync, multi-audio tracks, and resilient failover.',
        manifestUrl:
            'https://abhishekrazy.github.io/Exalere/plugins/moviebox/manifest.json',
        author: 'Exalere Community',
        isFeatured: true,
        tags: ['Direct', 'Fast', 'Movies', 'TV', 'Multi-Audio', 'Catalog'],
      ),
      CommunityPluginItem(
        id: 'org.exalere.fourkhd',
        name: '4K HD Hub Engine',
        description:
            'Direct high-speed 4K Ultra HD HDR and 1080p stream scraper for blockbuster movies and trending TV shows.',
        manifestUrl:
            'https://abhishekrazy.github.io/Exalere/plugins/fourkhd/manifest.json',
        author: 'Exalere Community',
        isFeatured: true,
        tags: ['4K HDR', 'UHD', 'Direct', 'Movies', 'TV'],
      ),
      CommunityPluginItem(
        id: 'org.exalere.dramachi',
        name: 'Dramachi Engine',
        description:
            'Asian drama, K-Drama, C-Drama, anime, and movies streaming with fast CDN links and multi-language subtitles.',
        manifestUrl:
            'https://abhishekrazy.github.io/Exalere/plugins/dramachi/manifest.json',
        author: 'Exalere Community',
        isFeatured: true,
        tags: ['Asian Drama', 'K-Drama', 'Anime', 'Fast CDN', 'Subtitles'],
      ),
      CommunityPluginItem(
        id: 'org.exalere.vidsrc',
        name: 'VidSrc Engine',
        description:
            'Free multi-mirror streaming & discovery engine for movies and TV shows powered by VidSrc (vidsrc.sh).',
        manifestUrl:
            'https://abhishekrazy.github.io/Exalere/plugins/vidsrc/manifest.json',
        author: 'Exalere Community',
        isFeatured: true,
        tags: ['Free', 'Multi-Mirror', 'Embed', 'Movies', 'TV', 'Catalog'],
      ),
      CommunityPluginItem(
        id: 'circleftp',
        name: 'CircleFTP (BDIX)',
        description:
            'High-speed local streaming on the Bangladesh Internet Exchange. Runs entirely inside the app.',
        manifestUrl: 'circleftp://engine',
        author: 'CircleFTP',
        isFeatured: false,
        tags: ['BDIX', 'Local', 'Movies', 'TV', 'Built-in'],
      ),
      CommunityPluginItem(
        id: 'moviesdrive',
        name: 'MoviesDrive',
        description:
            'Native in-app scraper for MoviesDrive with automatic domain refresh. '
            'Searches a JSON index and resolves HubCloud, PixelDrain and CDN sources.',
        manifestUrl: 'moviesdrive://engine',
        author: 'Exalere Community',
        isFeatured: false,
        tags: ['Built-in', 'Movies', 'TV', 'Multi-Mirror'],
      ),
      CommunityPluginItem(
        id: 'uhdmovies',
        name: 'UHDMovies',
        description:
            'Native in-app scraper for UHDMovies with automatic domain refresh. '
            'Resolves HubCloud, PixelDrain and CDN sources.',
        manifestUrl: 'uhdmovies://engine',
        author: 'Exalere Community',
        isFeatured: false,
        tags: ['Built-in', 'Movies', 'TV', 'Multi-Mirror'],
      ),
      CommunityPluginItem(
        id: 'moviesmod',
        name: 'MoviesMod',
        description:
            'Native in-app scraper for MoviesMod with automatic domain refresh. '
            'Resolves HubCloud, PixelDrain and CDN sources.',
        manifestUrl: 'moviesmod://engine',
        author: 'Exalere Community',
        isFeatured: false,
        tags: ['Built-in', 'Movies', 'TV', 'Multi-Mirror'],
      ),
      CommunityPluginItem(
        id: 'hdhub4u',
        name: 'HDHub4u',
        description:
            'Native in-app scraper for HDHub4u with automatic domain refresh. '
            'Resolves HubCloud, PixelDrain and CDN sources.',
        manifestUrl: 'hdhub4u://engine',
        author: 'Exalere Community',
        isFeatured: false,
        tags: ['Built-in', 'Movies', 'TV', 'Multi-Mirror'],
      ),
      CommunityPluginItem(
        id: 'com.stremio.torrentio.addon',
        name: 'Torrentio',
        description:
            'Multi-provider torrent stream scraper. Works best with a debrid account; without one, links open in an external player.',
        manifestUrl: 'https://torrentio.strem.fun/manifest.json',
        author: 'TheAddonBay',
        isFeatured: true,
        tags: ['P2P', '4K HDR', 'Debrid', 'Movies', 'TV'],
      ),
      CommunityPluginItem(
        id: 'com.stremio.thepiratebay.plus',
        name: 'ThePirateBay+ (TPB+)',
        description:
            'Peer-to-peer torrent index for movies and TV series. Links open in an external player.',
        manifestUrl: 'https://thepiratebay-plus.strem.fun/manifest.json',
        author: 'TPB Community',
        isFeatured: true,
        tags: ['P2P', 'Torrents', 'Movies', 'TV'],
      ),
      CommunityPluginItem(
        id: 'com.elfhosted.mediafusion',
        name: 'MediaFusion',
        description:
            'Multi-source stream provider covering international movies, series and live events.',
        manifestUrl: 'https://mediafusion.elfhosted.com/manifest.json',
        author: 'Mhdzumair',
        isFeatured: false,
        tags: ['Multi-Source', 'Sports', 'Movies', 'TV'],
      ),
      CommunityPluginItem(
        id: 'org.stremio.watchhub',
        name: 'WatchHub',
        description:
            'Shows which official streaming services carry a title and links straight to them.',
        manifestUrl: 'https://watchhub.strem.io/manifest.json',
        author: 'Stremio',
        isFeatured: false,
        tags: ['Official OTT', 'Availability', 'Movies', 'TV'],
      ),
      CommunityPluginItem(
        id: 'com.linvo.cinemeta',
        name: 'Cinemeta (Official)',
        description:
            'Official Stremio metadata catalogs and posters. Provides metadata only, never streams.',
        manifestUrl: 'https://v3-cinemeta.strem.io/manifest.json',
        author: 'Stremio',
        isFeatured: false,
        tags: ['Metadata', 'Official', 'No Streams'],
      ),
      CommunityPluginItem(
        id: 'community.anime.kitsu',
        name: 'Anime Kitsu',
        description:
            'Anime catalogs and metadata keyed by Kitsu, MyAnimeList and AniList ids. Provides metadata only, never streams.',
        manifestUrl: 'https://anime-kitsu.strem.fun/manifest.json',
        author: 'Community',
        isFeatured: false,
        tags: ['Anime', 'Metadata', 'No Streams'],
      ),
      CommunityPluginItem(
        id: 'org.stremio.opensubtitlesv3',
        name: 'OpenSubtitles v3',
        description:
            'Synced subtitles in 75+ languages, served for the exact episode you are playing.',
        manifestUrl: 'https://opensubtitles-v3.strem.io/manifest.json',
        author: 'OpenSubtitles.org',
        isFeatured: false,
        tags: ['Subtitles', 'Multi-Language'],
      ),
    ];
  }
}
