import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'warp_registration_client.dart';

/// A WireGuard keypair produced by the platform.
///
/// Key generation stays native because it needs curve25519 arithmetic that the
/// platform already provides; doing it in Dart would mean another dependency for
/// one operation.
class WarpKeyPair {
  const WarpKeyPair({required this.privateKey, required this.publicKey});

  final String privateKey;
  final String publicKey;
}

/// Reported state of the native tunnel.
class WarpTunnelState {
  const WarpTunnelState({required this.running, this.error});

  final bool running;
  final String? error;
}

/// Platform seam for the WARP tunnel.
///
/// Deliberately transport-agnostic: the native side may be a WireGuard
/// `VpnService` or a local MASQUE proxy, and nothing in Dart needs to know which.
/// When no native module is registered every call degrades to "unsupported"
/// rather than throwing, so the UI can say so honestly.
class WarpTunnel {
  WarpTunnel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.exalere/warp');

  final MethodChannel _channel;

  bool? _supported;

  /// Whether this build contains a native tunnel.
  Future<bool> isSupported() async {
    final cached = _supported;
    if (cached != null) return cached;
    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      _supported = result ?? false;
    } on MissingPluginException {
      debugPrint('[WarpTunnel] no native WARP module registered');
      _supported = false;
    } catch (e) {
      debugPrint('[WarpTunnel] support probe failed: $e');
      _supported = false;
    }
    return _supported!;
  }

  /// Asks the platform for a fresh keypair.
  Future<WarpKeyPair?> generateKeyPair() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'generateKeyPair',
      );
      if (result == null) return null;
      final privateKey = result['privateKey']?.toString() ?? '';
      final publicKey = result['publicKey']?.toString() ?? '';
      if (privateKey.isEmpty || publicKey.isEmpty) return null;
      return WarpKeyPair(privateKey: privateKey, publicKey: publicKey);
    } catch (e) {
      debugPrint('[WarpTunnel] key generation failed: $e');
      return null;
    }
  }

  /// Brings the tunnel up.
  Future<bool> start({
    required WarpConfig config,
    required String privateKey,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('start', {
        'privateKey': privateKey,
        'peerPublicKey': config.peerPublicKey,
        'endpointHost': config.endpointHost,
        'endpointPort': config.endpointPort,
        'ipv4': config.ipv4,
        'ipv6': config.ipv6,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('[WarpTunnel] start failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('[WarpTunnel] stop failed: $e');
    }
  }

  Future<WarpTunnelState> state() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('status');
      if (result == null) return const WarpTunnelState(running: false);
      return WarpTunnelState(
        running: result['running'] == true,
        error: result['error']?.toString(),
      );
    } catch (_) {
      return const WarpTunnelState(running: false);
    }
  }
}
