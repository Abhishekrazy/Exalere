import 'package:flutter/foundation.dart';

import '../models/stremio_addon.dart';
import '../services/addon_service.dart';

/// Reactive provider managing installed Stremio-compatible Addons.
class AddonProvider extends ChangeNotifier {
  final AddonService _service;

  AddonProvider({AddonService? service}) : _service = service ?? AddonService();

  List<StremioAddonConfig> _addons = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<StremioAddonConfig> get addons => List.unmodifiable(_addons);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load persisted addons from disk and register them with the engine.
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _addons = await _service.loadInstalledAddons();
    } catch (e) {
      _errorMessage = 'Failed to load addons: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Install an Addon from its base URL or manifest URL.
  /// Returns true on success, false on error (error message populated).
  Future<bool> installAddon(String url) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = await _service.installAddon(url);
      _addons.removeWhere((a) => a.id == config.id);
      _addons.add(config);
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

  /// Remove an installed Addon by ID.
  Future<void> uninstallAddon(String id) async {
    try {
      await _service.uninstallAddon(id);
      _addons.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to uninstall addon: $e';
      notifyListeners();
    }
  }

  /// Toggle an Addon on or off.
  Future<void> toggleAddon(String id, bool enabled) async {
    try {
      await _service.toggleAddon(id, enabled);
      final index = _addons.indexWhere((a) => a.id == id);
      if (index != -1) {
        _addons[index] = _addons[index].copyWith(isEnabled: enabled);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle addon: $e';
      notifyListeners();
    }
  }

  /// Reload all installed addons.
  Future<void> reloadAddons() async {
    await initialize();
  }
}
