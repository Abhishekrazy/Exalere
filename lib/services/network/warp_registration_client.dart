import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A provisioned Cloudflare WARP profile.
class WarpConfig {
  const WarpConfig({
    required this.accountId,
    required this.accessToken,
    required this.peerPublicKey,
    required this.endpointHost,
    required this.endpointPort,
    required this.ipv4,
    required this.ipv6,
  });

  final String accountId;
  final String accessToken;

  /// The WARP peer's public key.
  final String peerPublicKey;

  final String endpointHost;
  final int endpointPort;

  /// Address assigned to this device inside the tunnel.
  final String ipv4;
  final String ipv6;

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'accessToken': accessToken,
    'peerPublicKey': peerPublicKey,
    'endpointHost': endpointHost,
    'endpointPort': endpointPort,
    'ipv4': ipv4,
    'ipv6': ipv6,
  };

  factory WarpConfig.fromJson(Map<String, dynamic> json) => WarpConfig(
    accountId: json['accountId']?.toString() ?? '',
    accessToken: json['accessToken']?.toString() ?? '',
    peerPublicKey: json['peerPublicKey']?.toString() ?? '',
    endpointHost: json['endpointHost']?.toString() ?? '',
    endpointPort: (json['endpointPort'] as num?)?.toInt() ?? 2408,
    ipv4: json['ipv4']?.toString() ?? '',
    ipv6: json['ipv6']?.toString() ?? '',
  );

  bool get isUsable =>
      peerPublicKey.isNotEmpty && endpointHost.isNotEmpty && ipv4.isNotEmpty;
}

/// Raised when Cloudflare refuses or returns something unusable.
class WarpRegistrationException implements Exception {
  WarpRegistrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Registers a device with Cloudflare WARP over the WireGuard tunnel type.
///
/// The endpoint version and headers are taken from the reference client
/// implementation rather than guessed — Cloudflare changes this version string,
/// and a wrong one is rejected outright.
///
/// This deliberately uses the **WireGuard** tunnel type rather than MASQUE. The
/// reference app drives WARP through a bundled MASQUE client binary, which is
/// GPL-3.0 and therefore cannot be redistributed inside this project; WireGuard
/// is served by an Apache-2.0 library instead, and the licence constraint decides
/// the transport.
class WarpRegistrationClient {
  WarpRegistrationClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Cloudflare client API version. Must match the app version header below.
  static const String apiVersion = 'v0a4471';
  static const String clientVersion = 'a-6.35-4471';
  static const String baseUrl = 'https://api.cloudflareclient.com/$apiVersion';

  static const Duration _timeout = Duration(seconds: 20);

  /// Registers a device and returns a usable [WarpConfig].
  ///
  /// [publicKeyBase64] is the device's 32-byte WireGuard public key, base64
  /// encoded. Key generation stays with the caller because it needs platform
  /// crypto; keeping it out of here means this client is testable.
  Future<WarpConfig> register({
    required String publicKeyBase64,
    String deviceModel = 'PC',
  }) async {
    if (publicKeyBase64.trim().isEmpty) {
      throw WarpRegistrationException('A WireGuard public key is required.');
    }

    final body = json.encode({
      'key': publicKeyBase64.trim(),
      'install_id': '',
      'fcm_token': '',
      'tos': _timestamp(),
      'model': deviceModel,
      'serial_number': _serial(),
      'os_version': '',
      'key_type': 'curve25519',
      'tunnel_type': 'wireguard',
      'locale': 'en_US',
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/reg'),
            headers: {
              'User-Agent': 'WARP for Android',
              'CF-Client-Version': clientVersion,
              'Content-Type': 'application/json; charset=UTF-8',
              'Connection': 'Keep-Alive',
            },
            body: body,
          )
          .timeout(_timeout);
    } catch (e) {
      throw WarpRegistrationException('Could not reach Cloudflare: $e');
    }

    if (response.statusCode != 200) {
      throw WarpRegistrationException(
        'Registration failed (HTTP ${response.statusCode}): '
        '${_shorten(response.body)}',
      );
    }

    return parseRegistration(response.body);
  }

  /// Parses a registration response.
  ///
  /// Cloudflare wraps the payload in `result`; some endpoints return it bare, so
  /// both shapes are accepted. Exposed for testing.
  static WarpConfig parseRegistration(String body) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw WarpRegistrationException('Registration response was not JSON.');
    }
    if (decoded is! Map) {
      throw WarpRegistrationException(
        'Registration response was not an object.',
      );
    }

    final result = decoded['result'] is Map
        ? decoded['result'] as Map
        : decoded;

    final id = result['id']?.toString() ?? '';
    final token = result['token']?.toString() ?? '';
    if (id.isEmpty || token.isEmpty) {
      throw WarpRegistrationException(
        'Registration response was missing the account id or token.',
      );
    }

    final config = result['config'];
    if (config is! Map) {
      throw WarpRegistrationException('Registration response had no config.');
    }

    final peers = config['peers'];
    if (peers is! List || peers.isEmpty) {
      throw WarpRegistrationException('Registration response had no peers.');
    }
    final peer = peers.first;
    if (peer is! Map) {
      throw WarpRegistrationException('Registration peer was malformed.');
    }

    final peerPublicKey = peer['public_key']?.toString() ?? '';
    final endpoint = peer['endpoint'];
    if (endpoint is! Map) {
      throw WarpRegistrationException('Registration peer had no endpoint.');
    }

    // Endpoints arrive as `host:port` (IPv6 bracketed), sometimes with port 0.
    final endpointV4 = endpoint['v4']?.toString() ?? '';
    final endpointV6 = endpoint['v6']?.toString() ?? '';
    final resolved = _parseEndpoint(
      endpointV4.isNotEmpty ? endpointV4 : endpointV6,
    );
    if (resolved == null) {
      throw WarpRegistrationException('Registration endpoint was unusable.');
    }

    final iface = config['interface'];
    final addresses = iface is Map ? iface['addresses'] : null;
    final ipv4 = addresses is Map ? (addresses['v4']?.toString() ?? '') : '';
    final ipv6 = addresses is Map ? (addresses['v6']?.toString() ?? '') : '';

    final warpConfig = WarpConfig(
      accountId: id,
      accessToken: token,
      peerPublicKey: peerPublicKey,
      endpointHost: resolved.$1,
      endpointPort: resolved.$2,
      ipv4: ipv4,
      ipv6: ipv6,
    );

    if (!warpConfig.isUsable) {
      throw WarpRegistrationException(
        'Registration produced an incomplete profile.',
      );
    }
    return warpConfig;
  }

  /// Splits `host:port`, handling a bracketed IPv6 address.
  static (String, int)? _parseEndpoint(String value) {
    var text = value.trim();
    if (text.isEmpty) return null;
    if (text.endsWith(':0')) {
      text = text.substring(0, text.length - 2);
    }

    if (text.startsWith('[')) {
      final close = text.indexOf(']');
      if (close < 0) return null;
      final host = text.substring(1, close);
      final portPart = text.length > close + 1
          ? text.substring(close + 1).replaceFirst(':', '')
          : '';
      final port = int.tryParse(portPart);
      return (host, port == null || port == 0 ? 2408 : port);
    }

    final colon = text.lastIndexOf(':');
    if (colon > 0) {
      final host = text.substring(0, colon);
      final port = int.tryParse(text.substring(colon + 1));
      if (port != null) return (host, port == 0 ? 2408 : port);
    }
    return (text, 2408);
  }

  static String _timestamp() {
    // Cloudflare wants ISO-8601 in UTC with milliseconds.
    final now = DateTime.now().toUtc();
    final iso = now.toIso8601String();
    return iso.endsWith('Z') ? iso : '${iso}Z';
  }

  static String _serial() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return random.toRadixString(16).padLeft(16, '0');
  }

  static String _shorten(String body) =>
      body.length <= 160 ? body : '${body.substring(0, 160)}…';
}

/// Persists a provisioned profile so the app registers only once.
class WarpConfigStore {
  WarpConfigStore({required this.read, required this.write});

  final Future<String?> Function() read;
  final Future<void> Function(String value) write;

  Future<WarpConfig?> load() async {
    try {
      final raw = await read();
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final config = WarpConfig.fromJson(decoded.cast<String, dynamic>());
      return config.isUsable ? config : null;
    } catch (e) {
      debugPrint('[WarpConfigStore] could not load config: $e');
      return null;
    }
  }

  Future<void> save(WarpConfig config) async {
    try {
      await write(jsonEncode(config.toJson()));
    } catch (e) {
      debugPrint('[WarpConfigStore] could not save config: $e');
    }
  }

  Future<void> clear() async {
    try {
      await write('');
    } catch (e) {
      debugPrint('[WarpConfigStore] could not clear config: $e');
    }
  }
}
