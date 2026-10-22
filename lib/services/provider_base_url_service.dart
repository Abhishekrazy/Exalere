import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves a provider's current base URL.
///
/// These sites rotate domains constantly — they move to numbered mirrors when a
/// domain is blocked, which is exactly what a map like
/// `hdhub4u -> new8.hdhub4u.cl` records. Baking a domain into Dart therefore
/// means the provider starts returning empty results the next time the site
/// moves, with no way to fix it short of an app release.
///
/// So the map is fetched at runtime and cached, with a bundled fallback so a
/// first launch offline still works. This is the same design the reference
/// implementation uses (`urls.json` plus a `getBaseUrl` helper).
///
/// Both of these shapes are accepted, because the second is what the upstream
/// file already uses, so it can be consumed directly:
///
/// ```json
/// { "hdhub": "https://new8.hdhub4u.cl" }
/// { "hdhub": { "name": "hdhub4u", "url": "https://new8.hdhub4u.cl" } }
/// ```
class ProviderBaseUrlService {
  ProviderBaseUrlService._();

  static final ProviderBaseUrlService instance = ProviderBaseUrlService._();

  /// Upstream domain map. Chosen because it is maintained against the same sites
  /// this app scrapes, so it goes stale at the same rate the sites move.
  static const String defaultRemoteUrl =
      'https://raw.githubusercontent.com/Zenda-Cross/vega-providers/main/urls.json';

  static const String _cacheKey = 'exalere_provider_base_urls_v1';
  static const String _cacheTimeKey = 'exalere_provider_base_urls_at_v1';

  /// Re-fetch at most this often; domains do not move hourly.
  static const Duration cacheTtl = Duration(hours: 6);

  /// Bundled fallback. Deliberately small: only keys this app actually uses, so
  /// a stale entry cannot silently redirect a working provider.
  static const Map<String, String> fallbackUrls = {
    '4khdhub': 'https://4khdhub.one',
    'hdhub': 'https://new8.hdhub4u.cl',
    'uhd': 'https://uhdmovies.us.org',
    'Moviesmod': 'https://moviesmod.uk.com',
    'Topmovies': 'https://moviesleech.club',
    'drive': 'https://new3.moviesdrive.beer',
    'multi': 'https://m1.multimovies.courses',
    'w4u': 'https://world4ufree.tours',
    'kat': 'https://new.katmoviehd.top',
    'nfMirror': 'https://net77.cc',
    'gokuHD': 'https://gokuhd.com',
    'mkvDrama': 'https://mkvdrama.net',
    'eonMovies': 'https://new4.eonmovies.click',
    'kissKh': 'https://kisskh.is',
    'showbox': 'https://www.showbox.media',
    'movies4u': 'https://movies4u.cr',
    'zeefliz': 'https://zeefliz.club',
    'lux': 'https://rogmovies.one',
    'Vega': 'https://new1.vegamovies.lease',
    'dramacool': 'https://asianc.id',
    'movieBoxWeb': 'https://officialmoviebox.com',
    'movielinkdb': 'https://ex5wfv.movielinkbd.li',
  };

  final http.Client _client = http.Client();

  Map<String, String> _resolved = Map.of(fallbackUrls);
  bool _hasRemote = false;
  String? _lastError;
  DateTime? _fetchedAt;

  /// Whether a remote map has ever been loaded in this process.
  bool get hasRemoteMap => _hasRemote;

  String? get lastError => _lastError;

  DateTime? get fetchedAt => _fetchedAt;

  /// Keys currently known.
  Iterable<String> get knownKeys => _resolved.keys;

  /// Current base URL for [key], or [fallback] when the key is unknown.
  ///
  /// A remote entry always wins over the bundled one, and [fallback] is only
  /// used when neither is present — so a caller that passes a historical default
  /// still benefits from a rotated remote domain.
  String? baseUrlFor(String key, {String? fallback}) {
    final remote = _resolved[key];
    if (remote != null && remote.isNotEmpty) return remote;
    return fallback ?? fallbackUrls[key];
  }

  /// Loads the cached map immediately, then refreshes from the network only if
  /// the cache is older than [cacheTtl].
  ///
  /// Never throws: a provider must still work when this fails.
  Future<void> initialize({bool force = false}) async {
    await _loadCache();
    if (force || _isStale()) {
      await refresh();
    }
  }

  /// App-startup entry point.
  ///
  /// Loads the cache synchronously-ish and refreshes in the background, so a
  /// cold launch is never delayed by a network round trip to GitHub.
  Future<void> warmUp() async {
    await _loadCache();
    if (_isStale()) {
      unawaited(refresh());
    }
  }

  bool _isStale() {
    if (!_hasRemote || _fetchedAt == null) return true;
    return DateTime.now().difference(_fetchedAt!) > cacheTtl;
  }

  /// Fetches the remote map. Returns whether it was applied.
  Future<bool> refresh({String? sourceUrl}) async {
    final url = sourceUrl ?? defaultRemoteUrl;
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        _lastError = 'HTTP ${response.statusCode}';
        return false;
      }

      final parsed = parseBaseUrlMap(utf8.decode(response.bodyBytes));
      if (parsed.isEmpty) {
        _lastError = 'Remote map contained no usable URLs';
        return false;
      }

      // Merge rather than replace: a remote map that omits a key must not drop
      // that provider's bundled URL.
      _resolved = {...fallbackUrls, ...parsed};
      _hasRemote = true;
      _fetchedAt = DateTime.now();
      _lastError = null;
      await _saveCache(utf8.decode(response.bodyBytes));
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ProviderBaseUrlService] refresh failed: $e');
      return false;
    }
  }

  /// Parses either accepted map shape, dropping anything unusable.
  ///
  /// Exposed for testing, and tolerant by design: a provider with a junk URL is
  /// skipped so one bad entry cannot break the rest of the map.
  static Map<String, String> parseBaseUrlMap(String raw) {
    final result = <String, String>{};
    Object? decoded;
    try {
      decoded = json.decode(raw);
    } catch (_) {
      return result;
    }
    if (decoded is! Map) return result;

    decoded.forEach((key, value) {
      final name = key.toString().trim();
      if (name.isEmpty) return;

      String? url;
      if (value is String) {
        url = value;
      } else if (value is Map) {
        url = value['url']?.toString();
      }
      if (url == null) return;

      final cleaned = normalizeUrl(url);
      if (cleaned != null) result[name] = cleaned;
    });
    return result;
  }

  /// Returns a bare `scheme://host` origin, or null when the value is unusable.
  ///
  /// Paths and trailing slashes are discarded because callers append their own
  /// paths, and a leftover `/` produced double slashes in every request.
  static String? normalizeUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return null;

    // Check for an existing scheme before defaulting one, otherwise `ftp://x`
    // becomes `https://ftp` — a valid-looking host pointing at the wrong server.
    final schemeMatch = RegExp(
      r'^([a-zA-Z][a-zA-Z0-9+.\-]*)://',
    ).firstMatch(url);
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return null;
    } else {
      url = 'https://$url';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      final at = prefs.getInt(_cacheTimeKey);
      if (at != null) {
        _fetchedAt = DateTime.fromMillisecondsSinceEpoch(at);
      }
      if (raw == null || raw.isEmpty) return;

      final parsed = parseBaseUrlMap(raw);
      if (parsed.isEmpty) return;
      _resolved = {...fallbackUrls, ...parsed};
      _hasRemote = true;
    } catch (e) {
      debugPrint('[ProviderBaseUrlService] cache read failed: $e');
    }
  }

  Future<void> _saveCache(String raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, raw);
      await prefs.setInt(
        _cacheTimeKey,
        (_fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[ProviderBaseUrlService] cache write failed: $e');
    }
  }

  /// Test seam: restores the bundled map and forgets any loaded remote state.
  @visibleForTesting
  void resetForTest() {
    _resolved = Map.of(fallbackUrls);
    _hasRemote = false;
    _fetchedAt = null;
    _lastError = null;
  }
}
