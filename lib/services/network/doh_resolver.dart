import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/network_proxy_settings.dart';

/// One resolved address, with the TTL the resolver supplied.
class DohAnswer {
  const DohAnswer({required this.address, required this.ttlSeconds});

  final String address;
  final int ttlSeconds;
}

/// Resolves hostnames over DNS-over-HTTPS (RFC 8484).
///
/// When an ISP meddles with plaintext DNS, the hostname is already wrong before
/// any connection is attempted — packet fragmentation cannot help with that. This
/// gives the anti-DPI proxy a trustworthy answer to connect to.
///
/// The wire format is used rather than a provider's JSON API because it is the
/// only shape every resolver speaks, including a self-hosted one.
class DohResolver {
  DohResolver({http.Client? client, this.defaultEndpoint})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Endpoint used when the caller does not supply one.
  final String? defaultEndpoint;

  static const Duration _timeout = Duration(seconds: 6);

  /// Answers are cached briefly: a page load resolves the same few hosts many
  /// times, and re-querying each time would add latency to every request.
  static const Duration _minCacheTtl = Duration(seconds: 60);
  static const Duration _maxCacheTtl = Duration(hours: 1);

  final Map<String, _CacheEntry> _cache = {};

  int get cacheSize => _cache.length;

  /// Resolves [host] to IPv4 addresses.
  ///
  /// Returns an empty list on any failure — DNS is best-effort here and callers
  /// fall back to the system resolver.
  Future<List<DohAnswer>> resolve(
    String host, {
    String? endpoint,
    bool allowCache = true,
  }) async {
    final name = host.trim();
    if (name.isEmpty) return const [];

    // Literal addresses need no resolution.
    if (InternetAddress.tryParse(name) != null) {
      return [DohAnswer(address: name, ttlSeconds: 0)];
    }

    final target = endpoint ?? defaultEndpoint;
    if (target == null || target.isEmpty) return const [];

    final cacheKey = '$target|${name.toLowerCase()}';
    if (allowCache) {
      final cached = _cache[cacheKey];
      if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
        return cached.answers;
      }
    }

    try {
      final query = buildQuery(name);
      final response = await _client
          .post(
            Uri.parse(target),
            headers: {
              'Content-Type': 'application/dns-message',
              'Accept': 'application/dns-message',
            },
            body: query,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('[DohResolver] HTTP ${response.statusCode} for $name');
        return const [];
      }

      final answers = parseResponse(response.bodyBytes);
      if (answers.isEmpty) return const [];

      final ttl = _cacheTtlFor(answers);
      _cache[cacheKey] = _CacheEntry(
        answers: answers,
        expiresAt: DateTime.now().add(ttl),
      );
      return answers;
    } catch (e) {
      debugPrint('[DohResolver] resolve failed for $name: $e');
      return const [];
    }
  }

  /// Convenience for callers that only need one address to connect to.
  Future<String?> resolveFirst(String host, {String? endpoint}) async {
    final answers = await resolve(host, endpoint: endpoint);
    return answers.isEmpty ? null : answers.first.address;
  }

  void clearCache() => _cache.clear();

  static Duration _cacheTtlFor(List<DohAnswer> answers) {
    var shortest = answers.first.ttlSeconds;
    for (final answer in answers) {
      if (answer.ttlSeconds < shortest) shortest = answer.ttlSeconds;
    }
    final ttl = Duration(seconds: shortest <= 0 ? 60 : shortest);
    if (ttl < _minCacheTtl) return _minCacheTtl;
    if (ttl > _maxCacheTtl) return _maxCacheTtl;
    return ttl;
  }

  // -------------------------------------------------------------------
  // Wire format (exposed for tests)
  // -------------------------------------------------------------------

  static const int _typeA = 1;
  static const int _classIn = 1;

  /// Builds an A-record query for [host].
  static Uint8List buildQuery(String host, {int id = 0}) {
    final builder = BytesBuilder();
    // Header: id, flags (recursion desired), qdcount=1, others 0.
    builder.add([(id >> 8) & 0xFF, id & 0xFF, 0x01, 0x00]);
    builder.add([0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
    builder.add(encodeName(host));
    builder.add([(_typeA >> 8) & 0xFF, _typeA & 0xFF]);
    builder.add([(_classIn >> 8) & 0xFF, _classIn & 0xFF]);
    return builder.toBytes();
  }

  /// Encodes a hostname as length-prefixed labels plus a root terminator.
  static Uint8List encodeName(String host) {
    final builder = BytesBuilder();
    for (final label in host.split('.')) {
      if (label.isEmpty) continue;
      final bytes = Uint8List.fromList(label.codeUnits);
      builder.addByte(bytes.length);
      builder.add(bytes);
    }
    builder.addByte(0);
    return builder.toBytes();
  }

  /// Parses A records out of a DNS response.
  ///
  /// Only the answer section is read. Names may be compressed (a `0xC0` pointer),
  /// so names are skipped rather than parsed — the address is the only field that
  /// matters here.
  static List<DohAnswer> parseResponse(Uint8List data) {
    if (data.length < 12) return const [];

    final rcode = data[3] & 0x0F;
    if (rcode != 0) {
      debugPrint('[DohResolver] DNS rcode $rcode');
      return const [];
    }

    final answerCount = (data[6] << 8) | data[7];
    if (answerCount == 0) return const [];

    var offset = 12;

    // Skip the question section: name, then 4 bytes of type+class.
    final questionCount = (data[4] << 8) | data[5];
    for (var i = 0; i < questionCount; i++) {
      final next = skipName(data, offset);
      if (next < 0) return const [];
      offset = next + 4;
      if (offset > data.length) return const [];
    }

    final answers = <DohAnswer>[];
    for (var i = 0; i < answerCount; i++) {
      final afterName = skipName(data, offset);
      if (afterName < 0) break;
      offset = afterName;

      if (offset + 10 > data.length) break;
      final type = (data[offset] << 8) | data[offset + 1];
      final ttl =
          (data[offset + 4] << 24) |
          (data[offset + 5] << 16) |
          (data[offset + 6] << 8) |
          data[offset + 7];
      final length = (data[offset + 8] << 8) | data[offset + 9];
      offset += 10;

      if (offset + length > data.length) break;
      if (type == _typeA && length == 4) {
        answers.add(
          DohAnswer(
            address:
                '${data[offset]}.${data[offset + 1]}.'
                '${data[offset + 2]}.${data[offset + 3]}',
            ttlSeconds: ttl,
          ),
        );
      }
      offset += length;
    }
    return answers;
  }

  /// Returns the offset just past the name starting at [offset], or -1.
  static int skipName(Uint8List data, int offset) {
    var cursor = offset;
    while (cursor < data.length) {
      final length = data[cursor];
      if (length == 0) return cursor + 1;
      // A compression pointer terminates the name in two bytes.
      if ((length & 0xC0) == 0xC0) return cursor + 2;
      cursor += 1 + length;
    }
    return -1;
  }
}

class _CacheEntry {
  _CacheEntry({required this.answers, required this.expiresAt});

  final List<DohAnswer> answers;
  final DateTime expiresAt;
}

/// Builds a resolver from persisted settings.
DohResolver buildDohResolverFromSettings(
  NetworkProxySettings settings, {
  http.Client? client,
}) {
  return DohResolver(client: client, defaultEndpoint: settings.dohEndpoint);
}
