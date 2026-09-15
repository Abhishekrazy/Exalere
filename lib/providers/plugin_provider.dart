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
  String? _errorMessage;

  List<ExalerePluginConfig> get plugins => List.unmodifiable(_plugins);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load persisted plugins from disk and register them with the engine.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _plugins = await _service.loadInstalledPlugins();
    } catch (e) {
      _errorMessage = 'Failed to load plugins: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      notifyListeners();
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
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle plugin: $e';
      notifyListeners();
    }
  }

  /// Reload all installed plugins.
  Future<void> reloadPlugins() async {
    await initialize();
  }
}
