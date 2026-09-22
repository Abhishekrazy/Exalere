import 'package:flutter/foundation.dart';

import '../models/exalere_plugin.dart';
import '../services/plugin_service.dart';

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

  List<ExalerePluginConfig> get plugins => List.unmodifiable(_plugins);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasActivePlugins => _plugins.any((p) => p.isEnabled);
  bool get hasInstalledPlugins => _plugins.isNotEmpty;

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
