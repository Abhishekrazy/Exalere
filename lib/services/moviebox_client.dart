import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'moviebox_crypto.dart';
import 'moviebox_config_service.dart';

class MovieBoxSession {
  final String token;
  final String? userId;
  final int? expiresAt;
  final int createdAt;

  MovieBoxSession({
    required this.token,
    this.userId,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isValid {
    if (token.trim().isEmpty) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt != null) {
      return (now + 60) < expiresAt!;
    }
    return now < (createdAt + (7 * 24 * 3600));
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'expiresAt': expiresAt,
    'createdAt': createdAt,
  };

  factory MovieBoxSession.fromJson(Map<String, dynamic> json) =>
      MovieBoxSession(
        token: json['token'] ?? '',
        userId: json['userId'],
        expiresAt: json['expiresAt'],
        createdAt:
            json['createdAt'] ??
            (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      );
}

class MovieBoxClient {
  static final MovieBoxClient _instance = MovieBoxClient._internal();
  factory MovieBoxClient() => _instance;

  static const List<String> defaultHostPool =
      MovieBoxConfigService.defaultHostPool;
  List<String> get hostPool => MovieBoxConfigService().hostPool;

  static const List<int> retryStatusCodes = [403, 407, 429, 500, 502, 503, 504];

  final http.Client _client = http.Client();
  final Map<String, (DateTime, dynamic)> _getCache = {};
  MovieBoxSession? _session;
  int _activeHostIdx = 0;
  late String userAgent;
  late String clientInfo;
  late String spoofedIp;
  Completer<String>? _loginCompleter;

  MovieBoxClient._internal() {
    refreshClientInfo();
  }

  void refreshClientInfo() {
    final (ua, info) = MovieBoxCrypto.generateClientInfoAndUa();
    userAgent = ua;
    clientInfo = info;
    spoofedIp = MovieBoxCrypto.randomSpoofedIp();
  }

  Future<void> init() async {
    await MovieBoxConfigService().init();
    refreshClientInfo();
    await ensureSession();
  }

  Future<String> ensureSession() async {
    if (_session != null && _session!.isValid) {
      return _session!.token;
    }

    // Check shared preferences cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('moviebox_session');
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        final session = MovieBoxSession.fromJson(decoded);
        if (session.isValid) {
          _session = session;
          return session.token;
        }
      } catch (_) {}
    }

    // Concurrency guard: single in-flight login
    if (_loginCompleter != null) {
      return _loginCompleter!.future;
    }

    _loginCompleter = Completer<String>();

    try {
      final freshSession = await _fetchFreshSession();
      _session = freshSession;
      await prefs.setString(
        'moviebox_session',
        jsonEncode(freshSession.toJson()),
      );
      _loginCompleter!.complete(freshSession.token);
      return freshSession.token;
    } catch (e, stack) {
      debugPrint('MovieBox login failed: $e\n$stack');
      _loginCompleter!.completeError(e);
      rethrow;
    } finally {
      _loginCompleter = null;
    }
  }

  Future<MovieBoxSession> _fetchFreshSession() async {
    const path = '/wefeed-mobile-bff/user-api/visitor-login';
    const bodyStr = '{}';
    final val = await _requestHosts(
      method: 'POST',
      pathAndQuery: path,
      body: bodyStr,
      authToken: null,
    );

    final data = val is Map && val['data'] is Map ? val['data'] : val;
    final token = data['token']?.toString();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Missing visitor token');
    }

    final userId = (data['uid'] ?? data['userId'])?.toString();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return MovieBoxSession(token: token, userId: userId, createdAt: now);
  }

  void invalidateSession() {
    _session = null;
    SharedPreferences.getInstance().then((p) => p.remove('moviebox_session'));
  }

  Future<dynamic> get(
    String pathAndQuery, {
    bool forceRefresh = false,
    Duration ttl = const Duration(minutes: 5),
  }) async {
    if (!forceRefresh && _getCache.containsKey(pathAndQuery)) {
      final (cachedAt, data) = _getCache[pathAndQuery]!;
      if (DateTime.now().difference(cachedAt) < ttl) {
        return data;
      } else {
        _getCache.remove(pathAndQuery);
      }
    }

    final res = await _request(
      method: 'GET',
      pathAndQuery: pathAndQuery,
      body: null,
    );
    if (res != null) {
      if (_getCache.length > 50) {
        _getCache.remove(_getCache.keys.first);
      }
      _getCache[pathAndQuery] = (DateTime.now(), res);
    }
    return res;
  }

  void clearCache() {
    _getCache.clear();
  }

  Future<dynamic> post(String pathAndQuery, dynamic body) async {
    final bodyStr = body is String ? body : jsonEncode(body);
    return _request(method: 'POST', pathAndQuery: pathAndQuery, body: bodyStr);
  }

  Future<dynamic> _request({
    required String method,
    required String pathAndQuery,
    String? body,
  }) async {
    final token = await ensureSession();

    try {
      return await _requestHosts(
        method: method,
        pathAndQuery: pathAndQuery,
        body: body,
        authToken: token,
      );
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('403')) {
        invalidateSession();
        final freshToken = await ensureSession();
        return await _requestHosts(
          method: method,
          pathAndQuery: pathAndQuery,
          body: body,
          authToken: freshToken,
        );
      }
      rethrow;
    }
  }

  Future<dynamic> _requestHosts({
    required String method,
    required String pathAndQuery,
    String? body,
    String? authToken,
    bool hasRetriedWithFreshConfig = false,
  }) async {
    final hosts = hostPool;
    final startIdx = _activeHostIdx;

    for (int i = 0; i < hosts.length; i++) {
      final idx = (startIdx + i) % hosts.length;
      final base = hosts[idx];
      final url = '$base$pathAndQuery';

      final headers = MovieBoxCrypto.buildSignedHeaders(
        method: method,
        url: url,
        body: body,
        authToken: authToken,
        userAgent: userAgent,
        clientInfo: clientInfo,
        spoofedIp: spoofedIp,
      );

      try {
        final uri = Uri.parse(url);
        final http.Response resp;

        if (method.toUpperCase() == 'POST') {
          resp = await _client
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 12));
        } else {
          resp = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 12));
        }

        // Absorb x-user header if provided
        final xUser = resp.headers['x-user'];
        if (xUser != null && xUser.isNotEmpty) {
          try {
            final parsedUser = jsonDecode(xUser);
            if (parsedUser['token'] != null) {
              _session = MovieBoxSession(
                token: parsedUser['token'],
                userId:
                    parsedUser['uid']?.toString() ??
                    parsedUser['userId']?.toString(),
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              );
            }
          } catch (_) {}
        }

        if (retryStatusCodes.contains(resp.statusCode)) {
          debugPrint(
            'MovieBox host $idx returned retryable status ${resp.statusCode}',
          );
          continue;
        }

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          _activeHostIdx = idx;
          final json = jsonDecode(resp.body);
          if (json is Map && json.containsKey('data')) {
            return json['data'];
          }
          return json;
        } else {
          debugPrint(
            'MovieBox host $idx error: ${resp.statusCode} ${resp.body}',
          );
          if (resp.statusCode == 406) {
            // "find no content"
            return null;
          }
          continue;
        }
      } catch (e) {
        debugPrint('MovieBox host $idx exception: $e');
        continue;
      }
    }

    // Auto-healing fallback: if all hosts failed, sync latest API from MovieBox-TUI and retry once
    if (!hasRetriedWithFreshConfig) {
      debugPrint(
        'All hosts exhausted. Triggering automatic self-healing sync from MovieBox-TUI...',
      );
      final synced = await MovieBoxConfigService().syncFromUpstream(
        force: true,
      );
      if (synced) {
        refreshClientInfo();
        invalidateSession();
        final freshToken = authToken != null ? await ensureSession() : null;
        return _requestHosts(
          method: method,
          pathAndQuery: pathAndQuery,
          body: body,
          authToken: freshToken,
          hasRetriedWithFreshConfig: true,
        );
      }
    }

    throw Exception('All MovieBox hosts exhausted');
  }
}
