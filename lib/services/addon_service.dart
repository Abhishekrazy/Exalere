import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stremio_addon.dart';
import 'provider_registry.dart';
import 'stremio_addon_plugin.dart';

/// Central service for installing, persisting, validating, and registering
/// Stremio Addon Protocol v1 compliant plugins in Exalere.
class AddonService {
  static final AddonService _instance = AddonService._internal();
  factory AddonService() => _instance;
  AddonService._internal();

  static const String _storageKey = 'exalere_installed_addons_v1';
  final http.Client _client = http.Client();

  /// Normalize a user-entered Addon URL.
  /// Handles `stremio://` protocol, trailing slashes, and whitespace.
  static String normalizeUrl(String input) {
    var url = input.trim();
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

  /// Fetch and validate the manifest of an Addon from its base URL.
  Future<StremioManifest> fetchManifest(String inputUrl) async {
    final baseUrl = normalizeUrl(inputUrl);
    final manifestUri = Uri.parse('$baseUrl/manifest.json');

    debugPrint('[AddonService] Fetching manifest from: $manifestUri');
    final response = await _client
        .get(
          manifestUri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Exalere/1.0 (Stremio-Compatible-Client)',
          },
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception(
        'Server returned HTTP ${response.statusCode}. Please verify the Addon URL.',
      );
    }

    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final manifest = StremioManifest.fromJson(data);

    if (manifest.id.isEmpty) {
      throw Exception('Invalid Addon manifest: missing required "id" field.');
    }
    if (!manifest.supportsStreams) {
      throw Exception(
        'This Addon does not provide streaming capabilities (missing "stream" in resources).',
      );
    }

    return manifest;
  }

  /// Load all persisted addons from [SharedPreferences] and register enabled ones
  /// into [ProviderRegistry].
  Future<List<StremioAddonConfig>> loadInstalledAddons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final list = json.decode(raw) as List<dynamic>;
      final configs = list
          .map(
            (item) => StremioAddonConfig.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      for (final config in configs) {
        if (config.isEnabled) {
          ProviderRegistry().registerProvider(
            StremioAddonPlugin(config: config),
          );
        } else {
          ProviderRegistry().unregisterProvider(config.id);
        }
      }

      debugPrint('[AddonService] Loaded ${configs.length} installed addon(s).');
      return configs;
    } catch (e) {
      debugPrint('[AddonService] Error loading installed addons: $e');
      return [];
    }
  }

  /// Install a new Addon by URL.
  /// Fetches the manifest, verifies compatibility, persists to storage,
  /// and registers it into [ProviderRegistry].
  Future<StremioAddonConfig> installAddon(String inputUrl) async {
    final baseUrl = normalizeUrl(inputUrl);
    final manifest = await fetchManifest(baseUrl);

    final config = StremioAddonConfig(
      id: manifest.id,
      name: manifest.name,
      baseUrl: baseUrl,
      isEnabled: true,
      addedAt: DateTime.now(),
      manifest: manifest,
    );

    final existing = await loadInstalledAddons();
    existing.removeWhere((c) => c.id == config.id);
    existing.add(config);

    await _saveAddons(existing);
    ProviderRegistry().registerProvider(StremioAddonPlugin(config: config));
    debugPrint(
      '[AddonService] Successfully installed Addon: ${config.name} (${config.id})',
    );
    return config;
  }

  /// Uninstall an Addon by ID.
  Future<void> uninstallAddon(String id) async {
    final existing = await loadInstalledAddons();
    existing.removeWhere((c) => c.id == id);
    await _saveAddons(existing);
    ProviderRegistry().unregisterProvider(id);
    debugPrint('[AddonService] Uninstalled Addon: $id');
  }

  /// Toggle an Addon's enabled status.
  Future<void> toggleAddon(String id, bool enabled) async {
    final existing = await loadInstalledAddons();
    final index = existing.indexWhere((c) => c.id == id);
    if (index == -1) return;

    final updated = existing[index].copyWith(isEnabled: enabled);
    existing[index] = updated;
    await _saveAddons(existing);

    if (enabled) {
      ProviderRegistry().registerProvider(StremioAddonPlugin(config: updated));
    } else {
      ProviderRegistry().unregisterProvider(id);
    }
    debugPrint('[AddonService] Toggled Addon $id to isEnabled: $enabled');
  }

  Future<void> _saveAddons(List<StremioAddonConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(configs.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
