import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exalere_plugin.dart';
import 'exalere_plugin_adapter.dart';
import 'provider_registry.dart';

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
    if (!manifest.supportsStreams) {
      throw Exception(
        'This Plugin does not provide streaming capabilities (missing "stream" in resources).',
      );
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
          ProviderRegistry().registerProvider(
            ExalerePluginAdapter(config: config),
          );
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
    ProviderRegistry().registerProvider(ExalerePluginAdapter(config: config));
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
      ProviderRegistry().registerProvider(
        ExalerePluginAdapter(config: updated),
      );
    } else {
      ProviderRegistry().unregisterProvider(id);
    }
    debugPrint('[PluginService] Toggled Plugin $id to isEnabled: $enabled');
  }

  Future<void> _savePlugins(List<ExalerePluginConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
