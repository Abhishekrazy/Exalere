import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/network_proxy_settings.dart';
import 'doh_resolver.dart';

/// Status of the local anti-DPI proxy.
class AntiDpiStatus {
  const AntiDpiStatus({
    required this.running,
    required this.port,
    this.error,
    this.connections = 0,
  });

  final bool running;
  final int port;
  final String? error;
  final int connections;

  String get label {
    if (error != null) return 'Failed: $error';
    if (!running) return 'Off';
    return 'Active :$port';
  }
}

/// A loopback HTTP proxy that fragments TLS handshakes to defeat DPI.
///
/// Deep packet inspection blocks connections by matching the destination
/// hostname, which a TLS ClientHello carries in the clear. TLS is a byte stream,
/// so writing that handshake in several small pieces — with a pause between them
/// — usually slips past the matcher while the server reassembles it normally.
///
/// This is deliberately a proxy rather than a VPN: no `VpnService`, no native
/// code, no special permission. The trade-off is that it only covers traffic that
/// is pointed at it, which is why [proxySpec] exists for callers to apply.
class AntiDpiProxy {
  AntiDpiProxy({DohResolver? resolver, AntiDpiProfile? profile})
    : _resolver = resolver,
      profile = profile ?? AntiDpiProfile.balanced;

  final DohResolver? _resolver;

  /// Fragmentation strategy. Mutable so the user can retune it while running.
  AntiDpiProfile profile;

  ServerSocket? _server;
  int _port = 0;
  int _connections = 0;
  String? _lastError;
  bool _disposed = false;

  bool get isRunning => _server != null;

  int get port => _port;

  int get connections => _connections;

  AntiDpiStatus get status => AntiDpiStatus(
    running: isRunning,
    port: _port,
    error: _lastError,
    connections: _connections,
  );

  /// Proxy string for `HttpClient.findProxy` and mpv's `http-proxy`.
  String get proxySpec => 'PROXY 127.0.0.1:$_port';

  /// Binds the proxy. Pass `0` to let the OS choose a free port.
  ///
  /// Returns the bound port, or null when it could not start (the reason is then
  /// available via [status]).
  Future<int?> start({int port = 0}) async {
    if (_disposed) return null;
    if (_server != null) return _port;

    try {
      // Loopback only: nothing outside this device may use it.
      final server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      _server = server;
      _port = server.port;
      _lastError = null;
      server.listen(_handleConnection);
      debugPrint('[AntiDpiProxy] listening on 127.0.0.1:$_port');
      return _port;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[AntiDpiProxy] failed to start: $e');
      return null;
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _port = 0;
    await server?.close();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
  }

  // -------------------------------------------------------------------
  // Connection handling
  // -------------------------------------------------------------------

  Future<void> _handleConnection(Socket client) async {
    Socket? upstream;
    try {
      final head = await _readRequestHead(client);
      if (head == null) {
        await client.close();
        return;
      }

      final isConnect = head.startsWith('CONNECT ');
      final target = _parseTarget(head, isConnect: isConnect);
      if (target == null) {
        await client.close();
        return;
      }

      upstream = await _connect(target.host, target.port);
      if (upstream == null) {
        await client.close();
        return;
      }

      if (isConnect) {
        client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      } else {
        // Plain-HTTP absolute-form request: forward the head we already read.
        upstream.write(head);
      }
      await client.flush();
      _connections++;

      await _bridge(client, upstream);
    } catch (e) {
      debugPrint('[AntiDpiProxy] connection error: $e');
    } finally {
      upstream?.destroy();
      client.destroy();
    }
  }

  /// Reads the request head up to the blank line.
  Future<String?> _readRequestHead(Socket client) async {
    final buffer = <int>[];
    final completer = Completer<String?>();

    late StreamSubscription<Uint8List> sub;
    sub = client.listen(
      (data) {
        buffer.addAll(data);
        if (_endsHead(buffer)) {
          if (!completer.isCompleted) {
            completer.complete(String.fromCharCodes(buffer));
          }
          sub.cancel();
        }
        // A head this large is not a request we understand.
        if (buffer.length > 32 * 1024 && !completer.isCompleted) {
          completer.complete(null);
          sub.cancel();
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      cancelOnError: true,
    );

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => null,
    );
  }

  static bool _endsHead(List<int> bytes) {
    for (var i = 3; i < bytes.length; i++) {
      if (bytes[i] == 10 &&
          bytes[i - 1] == 13 &&
          bytes[i - 2] == 10 &&
          bytes[i - 3] == 13) {
        return true;
      }
    }
    return false;
  }

  _Target? _parseTarget(String head, {required bool isConnect}) {
    final firstLine = head.split('\r\n').first;
    final parts = firstLine.split(' ');
    if (parts.length < 2) return null;

    if (isConnect) {
      return _Target.tryParse(parts[1]);
    }

    // Absolute-form request: `GET http://host:port/path HTTP/1.1`
    final uri = Uri.tryParse(parts[1]);
    if (uri == null || uri.host.isEmpty) return null;
    return _Target(uri.host, uri.hasPort ? uri.port : 80);
  }

  /// Connects upstream, preferring a DoH answer when one is configured.
  Future<Socket?> _connect(String host, int port) async {
    final resolver = _resolver;
    if (resolver != null) {
      final address = await resolver.resolveFirst(host);
      if (address != null) {
        try {
          return await Socket.connect(
            address,
            port,
            timeout: const Duration(seconds: 12),
          );
        } catch (e) {
          debugPrint('[AntiDpiProxy] DoH address $address failed: $e');
        }
      }
    }
    try {
      return await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 12),
      );
    } catch (e) {
      debugPrint('[AntiDpiProxy] connect $host:$port failed: $e');
      return null;
    }
  }

  /// Pipes both directions, fragmenting the client's first write.
  Future<void> _bridge(Socket client, Socket upstream) async {
    final done = Completer<void>();
    var fragmentedFirst = false;

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final clientSub = client.listen(
      (data) async {
        try {
          if (!fragmentedFirst && data.isNotEmpty) {
            fragmentedFirst = true;
            await writeFragmented(upstream, data, profile);
          } else {
            upstream.add(data);
            await upstream.flush();
          }
        } catch (_) {
          finish();
        }
      },
      onDone: finish,
      onError: (_) => finish(),
      cancelOnError: true,
    );

    final upstreamSub = upstream.listen(
      (data) {
        try {
          client.add(data);
        } catch (_) {
          finish();
        }
      },
      onDone: finish,
      onError: (_) => finish(),
      cancelOnError: true,
    );

    await done.future;
    await clientSub.cancel();
    await upstreamSub.cancel();
  }

  /// Writes [data] in fragments with a pause between them.
  ///
  /// Exposed for testing: this is the whole anti-DPI mechanism, and it must not
  /// alter the bytes, only how they are delivered.
  static Future<void> writeFragmented(
    IOSink sink,
    Uint8List data,
    AntiDpiProfile profile,
  ) async {
    for (final fragment in planFragments(data, profile)) {
      sink.add(fragment);
      await sink.flush();
      if (profile.chunkDelayMs > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: profile.chunkDelayMs),
        );
      }
    }
  }

  /// Splits [data] into the fragments [writeFragmented] would send.
  ///
  /// Concatenating the result always reproduces the input exactly; fragmentation
  /// must never corrupt the stream, only pace it.
  static List<Uint8List> planFragments(Uint8List data, AntiDpiProfile profile) {
    final chunk = profile.chunkSize <= 0 ? 1 : profile.chunkSize;
    if (data.isEmpty) return const [];

    final fragments = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      final end = (offset + chunk).clamp(0, data.length);
      fragments.add(Uint8List.sublistView(data, offset, end));
      offset = end;
    }
    return fragments;
  }
}

class _Target {
  const _Target(this.host, this.port);

  final String host;
  final int port;

  static _Target? tryParse(String value) {
    final parts = value.split(':');
    if (parts.isEmpty || parts.first.isEmpty) return null;
    final port = parts.length > 1 ? int.tryParse(parts[1]) : 443;
    if (port == null) return null;
    return _Target(parts.first, port);
  }
}
