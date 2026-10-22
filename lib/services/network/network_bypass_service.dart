import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/network_proxy_settings.dart';
import 'anti_dpi_proxy.dart';
import 'doh_resolver.dart';
import 'warp_service.dart';

/// Owns the network-bypass features and their persisted settings.
///
/// Two independent mechanisms, because they solve different halves of ISP
/// interference: [AntiDpiProxy] defeats inspection of the connection, while the
/// DoH resolver fixes a poisoned hostname lookup. WARP would be the third —
/// a full tunnel — but it needs a native WireGuard module that this build does
/// not contain, so it reports itself unavailable rather than silently doing
/// nothing.
class NetworkBypassService extends ChangeNotifier {
  NetworkBypassService._();

  static final NetworkBypassService instance = NetworkBypassService._();

  static const String _warpKey = 'user_network_warp_enabled';
  static const String _antiDpiKey = 'user_network_antidpi_enabled';
  static const String _portKey = 'user_network_antidpi_port';
  static const String _profileKey = 'user_network_antidpi_profile';
  static const String _dohKey = 'user_network_doh_provider';
  static const String _customDohKey = 'user_network_doh_custom_url';

  NetworkProxySettings _settings = const NetworkProxySettings();
  AntiDpiProxy? _proxy;
  DohResolver? _resolver;
  HttpOverrides? _previousOverrides;
  bool _applied = false;

  NetworkProxySettings get settings => _settings;

  bool get isAntiDpiRunning => _proxy?.isRunning ?? false;

  int get antiDpiPort => _proxy?.port ?? 0;

  int get antiDpiConnections => _proxy?.connections ?? 0;

  AntiDpiStatus get antiDpiStatus =>
      _proxy?.status ?? const AntiDpiStatus(running: false, port: 0);

  /// Proxy spec to hand to `HttpClient.findProxy` or mpv's `http-proxy`.
  String? get proxySpec => isAntiDpiRunning ? _proxy?.proxySpec : null;

  /// Whether the native WARP tunnel is present in this build.
  ///
  /// Delegated to [WarpService], which probes the platform channel. With no
  /// native module registered this reports false, so the switch stays disabled
  /// instead of offering a toggle that cannot tunnel anything.
  bool get isWarpAvailable => WarpService.instance.isSupported;

  String get warpUnavailableReason =>
      WarpService.instance.unavailableReason ??
      'WARP is not available in this build.';

  /// Current WARP status, so the settings row can show it.
  WarpStatus get warpStatus => WarpService.instance.status;

  Future<void> initialize() async {
    await _load();
    await WarpService.instance.initialize();
    if (_settings.antiDpiEnabled) {
      await _startAntiDpi();
    }
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = NetworkProxySettings(
        // WARP can never be on while the module is absent, whatever was stored.
        warpEnabled: isWarpAvailable && (prefs.getBool(_warpKey) ?? false),
        antiDpiEnabled: prefs.getBool(_antiDpiKey) ?? false,
        antiDpiPort: prefs.getInt(_portKey) ?? 0,
        antiDpiProfileLabel:
            prefs.getString(_profileKey) ?? AntiDpiProfile.balanced.label,
        dohProvider: DohProvider.fromName(prefs.getString(_dohKey)),
        customDohUrl: prefs.getString(_customDohKey) ?? '',
      );
    } catch (e) {
      debugPrint('[NetworkBypass] could not load settings: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_warpKey, _settings.warpEnabled);
      await prefs.setBool(_antiDpiKey, _settings.antiDpiEnabled);
      await prefs.setInt(_portKey, _settings.antiDpiPort);
      await prefs.setString(_profileKey, _settings.antiDpiProfileLabel);
      await prefs.setString(_dohKey, _settings.dohProvider.name);
      await prefs.setString(_customDohKey, _settings.customDohUrl);
    } catch (e) {
      debugPrint('[NetworkBypass] could not persist settings: $e');
    }
  }

  // -------------------------------------------------------------------
  // WARP
  // -------------------------------------------------------------------

  /// Turns WARP on or off, delegating the tunnel work to [WarpService].
  ///
  /// Returns false when the tunnel could not be brought up — the settings flag is
  /// only stored as on when it genuinely is, so a restart never restores a
  /// connection that was never established.
  Future<bool> setWarpEnabled(bool enabled) async {
    if (!isWarpAvailable) {
      debugPrint('[NetworkBypass] WARP unavailable: $warpUnavailableReason');
      return false;
    }

    final bool ok;
    if (enabled) {
      ok = await WarpService.instance.enable();
    } else {
      await WarpService.instance.disable();
      ok = true;
    }

    _settings = _settings.copyWith(warpEnabled: enabled && ok);
    await _persist();
    notifyListeners();
    return ok;
  }

  // -------------------------------------------------------------------
  // Anti-DPI
  // -------------------------------------------------------------------

  Future<bool> setAntiDpiEnabled(bool enabled) async {
    if (enabled) {
      final started = await _startAntiDpi();
      _settings = _settings.copyWith(antiDpiEnabled: started);
      await _persist();
      notifyListeners();
      return started;
    }

    await _stopAntiDpi();
    await WarpService.instance.forgetDevice();
    _settings = _settings.copyWith(antiDpiEnabled: false);
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> setAntiDpiProfile(AntiDpiProfile profile) async {
    _settings = _settings.copyWith(antiDpiProfileLabel: profile.label);
    _proxy?.profile = profile;
    await _persist();
    notifyListeners();
  }

  Future<bool> _startAntiDpi() async {
    await _stopAntiDpi();
    await WarpService.instance.forgetDevice();

    final resolver = _settings.hasDoh
        ? DohResolver(defaultEndpoint: _settings.dohEndpoint)
        : null;
    final proxy = AntiDpiProxy(
      resolver: resolver,
      profile: _settings.antiDpiProfile,
    );

    final port = await proxy.start(port: _settings.antiDpiPort);
    if (port == null) {
      debugPrint('[NetworkBypass] anti-DPI proxy failed to bind');
      await proxy.dispose();
      return false;
    }

    _proxy = proxy;
    _resolver = resolver;
    _settings = _settings.copyWith(antiDpiPort: port);
    _applyProxyToHttp(_proxy!.proxySpec);
    return true;
  }

  Future<void> _stopAntiDpi() async {
    _restoreHttp();
    await _proxy?.dispose();
    _proxy = null;
    _resolver = null;
  }

  // -------------------------------------------------------------------
  // DNS over HTTPS
  // -------------------------------------------------------------------

  Future<void> setDohProvider(DohProvider provider) async {
    _settings = _settings.copyWith(dohProvider: provider);
    await _persist();
    // The resolver is created when the proxy starts, so a change takes effect on
    // the next start rather than tearing down live connections.
    notifyListeners();
  }

  Future<void> setCustomDohUrl(String url) async {
    _settings = _settings.copyWith(customDohUrl: url.trim());
    await _persist();
    notifyListeners();
  }

  /// Resolves a host using the configured DoH endpoint, or null when disabled.
  Future<String?> resolveViaDoh(String host) async {
    final endpoint = _settings.dohEndpoint;
    if (endpoint == null) return null;
    _resolver ??= DohResolver(defaultEndpoint: endpoint);
    return _resolver!.resolveFirst(host, endpoint: endpoint);
  }

  // -------------------------------------------------------------------
  // Routing
  // -------------------------------------------------------------------

  /// Points new `HttpClient`s at the local proxy.
  void _applyProxyToHttp(String spec) {
    if (_applied) return;
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _ProxyHttpOverrides(spec);
    _applied = true;
    debugPrint('[NetworkBypass] app HTTP routed via $spec');
  }

  void _restoreHttp() {
    if (!_applied) return;
    HttpOverrides.global = _previousOverrides;
    _previousOverrides = null;
    _applied = false;
  }

  /// Stops everything. Called on erase-all-data and app teardown.
  Future<void> shutdown() async {
    await _stopAntiDpi();
    await WarpService.instance.forgetDevice();
    _settings = _settings.copyWith(antiDpiEnabled: false, warpEnabled: false);
    notifyListeners();
  }
}

/// Sends every request created through this client via the local proxy.
class _ProxyHttpOverrides extends HttpOverrides {
  _ProxyHttpOverrides(this.proxySpec);

  final String proxySpec;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => proxySpec;
    return client;
  }
}
