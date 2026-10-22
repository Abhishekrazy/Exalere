import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'warp_registration_client.dart';
import 'warp_tunnel.dart';

/// Lifecycle of the WARP connection.
enum WarpStatus {
  /// This build has no native tunnel, so WARP cannot be used at all.
  unavailable,

  /// Available and switched off.
  idle,

  /// Talking to Cloudflare to provision the device.
  registering,

  /// Bringing the tunnel up.
  connecting,

  /// Tunnel is up.
  connected,

  /// Something failed; [WarpService.errorMessage] explains.
  error;

  String get label {
    switch (this) {
      case WarpStatus.unavailable:
        return 'Unavailable';
      case WarpStatus.idle:
        return 'Off';
      case WarpStatus.registering:
        return 'Registering…';
      case WarpStatus.connecting:
        return 'Connecting…';
      case WarpStatus.connected:
        return 'Connected';
      case WarpStatus.error:
        return 'Error';
    }
  }
}

/// Orchestrates Cloudflare WARP: provision once, then start/stop the tunnel.
///
/// Transport-agnostic by design — [WarpTunnel] hides whether the native side is a
/// WireGuard `VpnService` or a local proxy. That keeps the registration flow,
/// persistence and status handling independent of that choice.
class WarpService extends ChangeNotifier {
  WarpService({WarpTunnel? tunnel, WarpRegistrationClient? registrationClient})
    : _tunnel = tunnel ?? WarpTunnel(),
      _registration = registrationClient ?? WarpRegistrationClient();

  static final WarpService instance = WarpService._internal();

  WarpService._internal()
    : _tunnel = WarpTunnel(),
      _registration = WarpRegistrationClient();

  static const String _configKey = 'user_warp_config';
  static const String _privateKeyKey = 'user_warp_private_key';
  static const String _enabledKey = 'user_warp_enabled';

  final WarpTunnel _tunnel;
  final WarpRegistrationClient _registration;

  // Starts as unavailable: nothing may claim WARP works before the platform has
  // been probed, otherwise the settings switch looks usable on a build with no
  // native module.
  WarpStatus _status = WarpStatus.unavailable;

  /// Whether the platform reported a native tunnel. Kept separate from [status]
  /// because status changes for many reasons (user toggles, errors) while this
  /// answers one question only: does this build contain a tunnel at all.
  bool _platformSupported = false;
  String? _errorMessage;
  WarpConfig? _config;
  bool _initialized = false;

  WarpStatus get status => _status;

  String? get errorMessage => _errorMessage;

  WarpConfig? get config => _config;

  bool get isSupported => _platformSupported;

  bool get isConnected => _status == WarpStatus.connected;

  bool get isBusy =>
      _status == WarpStatus.registering || _status == WarpStatus.connecting;

  /// Human-readable reason WARP cannot be used, or null when it can.
  String? get unavailableReason {
    if (isSupported) return null;
    return 'WARP needs the native tunnel module, which this build does not '
        'include. Anti-DPI and DNS-over-HTTPS work without it.';
  }

  /// Probes the platform, restores a saved profile, and resumes if it was on.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _platformSupported = await _tunnel.isSupported();
    if (!_platformSupported) {
      _status = WarpStatus.unavailable;
      notifyListeners();
      return;
    }

    _config = await _store.load();
    _status = WarpStatus.idle;
    notifyListeners();

    // Resume a connection the user left on.
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(_enabledKey) ?? false) && _config != null) {
        await enable();
      }
    } catch (e) {
      debugPrint('[WarpService] could not restore state: $e');
    }
  }

  WarpConfigStore get _store => WarpConfigStore(
    read: () async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_configKey);
    },
    write: (value) async {
      final prefs = await SharedPreferences.getInstance();
      if (value.isEmpty) {
        await prefs.remove(_configKey);
      } else {
        await prefs.setString(_configKey, value);
      }
    },
  );

  Future<String?> _readPrivateKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_privateKeyKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePrivateKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privateKeyKey, key);
    } catch (e) {
      debugPrint('[WarpService] could not store private key: $e');
    }
  }

  Future<void> _setEnabledFlag(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (e) {
      debugPrint('[WarpService] could not store enabled flag: $e');
    }
  }

  /// Registers (if needed) and brings the tunnel up.
  ///
  /// Returns whether the tunnel is running.
  Future<bool> enable() async {
    if (!isSupported) return false;
    if (isConnected) return true;

    _errorMessage = null;

    try {
      var config = _config;
      var privateKey = await _readPrivateKey();

      if (config == null || privateKey == null || privateKey.isEmpty) {
        _status = WarpStatus.registering;
        notifyListeners();

        final keyPair = await _tunnel.generateKeyPair();
        if (keyPair == null) {
          return _fail(
            'Could not generate a WireGuard keypair on this device.',
          );
        }

        config = await _registration.register(
          publicKeyBase64: keyPair.publicKey,
        );
        privateKey = keyPair.privateKey;

        _config = config;
        await _store.save(config);
        await _savePrivateKey(privateKey);
      }

      _status = WarpStatus.connecting;
      notifyListeners();

      final started = await _tunnel.start(
        config: config,
        privateKey: privateKey,
      );
      if (!started) {
        return _fail('The tunnel did not start.');
      }

      final state = await _tunnel.state();
      if (!state.running) {
        return _fail(
          state.error ?? 'The tunnel reported that it is not running.',
        );
      }

      _status = WarpStatus.connected;
      await _setEnabledFlag(true);
      notifyListeners();
      return true;
    } on WarpRegistrationException catch (e) {
      return _fail(e.message);
    } catch (e) {
      return _fail(e.toString());
    }
  }

  Future<void> disable() async {
    await _tunnel.stop();
    await _setEnabledFlag(false);
    _status = _platformSupported ? WarpStatus.idle : WarpStatus.unavailable;
    _errorMessage = null;
    notifyListeners();
  }

  /// Forgets the provisioned profile, so the next enable registers afresh.
  ///
  /// Useful when Cloudflare rejects a stale device, which happens after the
  /// account is removed server-side.
  Future<void> forgetDevice() async {
    await disable();
    await _store.clear();
    _config = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_privateKeyKey);
    } catch (_) {}
    _status = _platformSupported ? WarpStatus.idle : WarpStatus.unavailable;
    notifyListeners();
  }

  bool _fail(String message) {
    _errorMessage = message;
    _status = WarpStatus.error;
    debugPrint('[WarpService] $message');
    notifyListeners();
    return false;
  }

  /// Test seam: replaces the status without touching the platform.
  @visibleForTesting
  void debugSetStatus(WarpStatus status) {
    _status = status;
    notifyListeners();
  }
}
