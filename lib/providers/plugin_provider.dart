import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exalere_plugin.dart';
import '../services/plugin_service.dart';
import '../services/provider_diagnostics_service.dart';
import '../services/provider_registry.dart';

/// Reactive provider managing installed Exalere Plugins.
class PluginProvider extends ChangeNotifier {
  final PluginService _service;

  PluginProvider({PluginService? service})
    : _service = service ?? PluginService();

  List<ExalerePluginConfig> _plugins = [];
  bool _isLoading = false;
  List<CommunityPluginItem> _communityCatalog = [];
  String? _errorMessage;
  String? _defaultProviderId;

  /// Last known health per provider id. Persisted, because a verdict that
  /// vanished on restart would be worse than useless.
  final Map<String, ProviderHealth> _health = {};

  /// Full stage-by-stage reports for this session, keyed by provider id.
  final Map<String, ProviderTestReport> _reports = {};

  static const String _healthStorageKey = 'exalere_provider_health_v1';

  List<ExalerePluginConfig> get plugins => List.unmodifiable(_plugins);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Whether at least one installed, enabled provider can actually resolve a
  /// stream.
  ///
  /// Every play action must key off this. It is deliberately **not** "is any
  /// plugin installed": metadata-only providers (the built-in TMDB catalog,
  /// Cinemeta, Kitsu, subtitle addons) are installed and enabled yet can never
  /// play anything. Treating those as playable is what produced a Play button
  /// that always ended in "No streams available".
  bool get hasPlayableProvider {
    final registry = ProviderRegistry();
    for (final config in _plugins) {
      if (!config.isEnabled) continue;
      final engine = registry.resolveProvider(config.id);
      if (engine != null && engine.supportsStreams) return true;
    }
    return false;
  }

  bool get hasInstalledPlugins => _plugins.isNotEmpty;

  // ---------------------------------------------------------------------
  // Provider health
  // ---------------------------------------------------------------------

  /// Last known health of [id]; [ProviderHealth.untested] when never checked.
  ProviderHealth healthFor(String id) => _health[id] ?? ProviderHealth.untested;

  /// Stage-by-stage report from this session, if the provider has been tested.
  ProviderTestReport? reportFor(String id) => _reports[id];

  bool isTesting(String id) => _health[id] == ProviderHealth.testing;

  /// Runs the staged health check against an installed provider.
  ///
  /// [onStage] fires as each stage settles so a dialog can show live progress.
  Future<ProviderTestReport?> runProviderTest(
    String id, {
    void Function(ProviderStageResult result)? onStage,
  }) async {
    final engine = ProviderRegistry().resolveProvider(id);
    if (engine == null) {
      debugPrint('[PluginProvider] No engine registered for "$id" to test.');
      return null;
    }

    _health[id] = ProviderHealth.testing;
    notifyListeners();

    final report = await ProviderDiagnosticsService.instance.run(
      engine,
      onStage: onStage,
    );

    _reports[id] = report;
    _health[id] = report.health;
    await _persistHealth();
    notifyListeners();
    return report;
  }

  /// Clears a stored verdict, e.g. after the provider is reconfigured.
  Future<void> clearProviderHealth(String id) async {
    _health.remove(id);
    _reports.remove(id);
    await _persistHealth();
    notifyListeners();
  }

  Future<void> _loadHealth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_healthStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final raw = value?.toString();
        if (raw == 'working') {
          _health[key.toString()] = ProviderHealth.working;
        } else if (raw == 'failed') {
          _health[key.toString()] = ProviderHealth.failed;
        }
      });
    } catch (e) {
      // A health cache is a convenience; never let it block startup.
      debugPrint('[PluginProvider] Could not load provider health: $e');
    }
  }

  Future<void> _persistHealth() async {
    try {
      final payload = <String, String>{};
      _health.forEach((key, value) {
        if (value == ProviderHealth.working || value == ProviderHealth.failed) {
          payload[key] = value.name;
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_healthStorageKey, json.encode(payload));
    } catch (e) {
      debugPrint('[PluginProvider] Could not persist provider health: $e');
    }
  }

  /// The ID of the user-designated default provider (null = use all providers).
  String? get defaultProviderId => _defaultProviderId;

  List<CommunityPluginItem> get communityCatalog => _communityCatalog.isNotEmpty
      ? _communityCatalog
      : _service.getCommunityCatalog();

  bool isPluginInstalled(String id, [String? manifestUrl]) {
    final normalized = manifestUrl != null
        ? PluginService.normalizeUrl(manifestUrl)
        : null;
    return _plugins.any(
      (p) => p.id == id || (normalized != null && p.baseUrl == normalized),
    );
  }

  /// Load persisted plugins from disk and register them with the engine.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _communityCatalog = await _service.loadCachedCommunityCatalog();
      _plugins = await _service.loadInstalledPlugins();
      _defaultProviderId = await _service.getDefaultProviderId();
      await _service.loadDefaultProvider();
      await _loadHealth();
    } catch (e) {
      _errorMessage = 'Failed to load plugins: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _fetchRemoteCatalogSilently();
  }

  Future<void> _fetchRemoteCatalogSilently() async {
    try {
      final remote = await _service.fetchRemoteCommunityCatalog();
      if (remote.isNotEmpty) {
        _communityCatalog = remote;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PluginProvider] Remote catalog sync failed silently: $e');
    }
  }

  /// Refresh community catalog from remote repository.
  Future<void> refreshCommunityCatalog() async {
    try {
      final remote = await _service.fetchRemoteCommunityCatalog();
      if (remote.isNotEmpty) {
        _communityCatalog = remote;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to refresh catalog: $e';
      notifyListeners();
    }
  }

  VoidCallback? onPluginsChanged;

  /// Install a Plugin from its base URL or manifest URL.
  /// Returns true on success, false on error (error message populated).
  Future<bool> installPlugin(String url) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = await _service.installPlugin(url);
      _plugins.removeWhere((p) => p.id == config.id);
      _plugins.add(config);
      _isLoading = false;
      notifyListeners();
      onPluginsChanged?.call();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove an installed Plugin by ID.
  Future<void> uninstallPlugin(String id) async {
    try {
      await _service.uninstallPlugin(id);
      _plugins.removeWhere((p) => p.id == id);
      if (_defaultProviderId == id) {
        _defaultProviderId = null;
      }
      notifyListeners();
      onPluginsChanged?.call();
    } catch (e) {
      _errorMessage = 'Failed to uninstall plugin: $e';
      notifyListeners();
    }
  }

  /// Toggle a Plugin on or off.
  Future<void> togglePlugin(String id, bool enabled) async {
    try {
      await _service.togglePlugin(id, enabled);
      final index = _plugins.indexWhere((p) => p.id == id);
      if (index != -1) {
        _plugins[index] = _plugins[index].copyWith(isEnabled: enabled);
        notifyListeners();
        onPluginsChanged?.call();
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle plugin: $e';
      notifyListeners();
    }
  }

  /// Set a plugin as the default provider. Pass null to unset.
  Future<void> setDefaultProvider(String? id) async {
    try {
      await _service.setDefaultProviderId(id);
      _defaultProviderId = id;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to set default provider: $e';
      notifyListeners();
    }
  }

  /// Reload all installed plugins.
  Future<void> reloadPlugins() async {
    await initialize();
  }
}
