import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';

class TmdbCrewMember {
  final String name;
  final String role;
  final String? profilePath;

  const TmdbCrewMember({
    required this.name,
    required this.role,
    this.profilePath,
  });

  String? get profileUrl => profilePath != null && profilePath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    if (profilePath != null) 'profilePath': profilePath,
  };

  factory TmdbCrewMember.fromJson(Map<String, dynamic> json) => TmdbCrewMember(
    name: json['name']?.toString() ?? 'Unknown',
    role: json['role']?.toString() ?? '',
    profilePath: json['profilePath']?.toString(),
  );
}

class TmdbCastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;

  const TmdbCastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  String? get profileUrl => profilePath != null && profilePath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (character != null) 'character': character,
    if (profilePath != null) 'profilePath': profilePath,
  };

  factory TmdbCastMember.fromJson(Map<String, dynamic> json) {
    String? char = json['character']?.toString();
    if (char == null || char.isEmpty) {
      if (json['roles'] is List && (json['roles'] as List).isNotEmpty) {
        char = json['roles'][0]['character']?.toString();
      }
    }
    return TmdbCastMember(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name:
          json['name']?.toString() ??
          json['original_name']?.toString() ??
          'Unknown',
      character: char,
      profilePath:
          json['profilePath']?.toString() ?? json['profile_path']?.toString(),
    );
  }
}

class TmdbEpisodeInfo {
  final int episodeNumber;
  final String? name;
  final String? overview;
  final String? stillPath;

  const TmdbEpisodeInfo({
    required this.episodeNumber,
    this.name,
    this.overview,
    this.stillPath,
  });

  String? get stillUrl => (stillPath != null && stillPath!.isNotEmpty)
      ? 'https://image.tmdb.org/t/p/w500$stillPath'
      : null;

  Map<String, dynamic> toJson() => {
    'episodeNumber': episodeNumber,
    if (name != null) 'name': name,
    if (overview != null) 'overview': overview,
    if (stillPath != null) 'stillPath': stillPath,
  };

  factory TmdbEpisodeInfo.fromJson(Map<String, dynamic> json) =>
      TmdbEpisodeInfo(
        episodeNumber: json['episodeNumber'] is int
            ? json['episodeNumber']
            : (int.tryParse(
                    json['episode_number']?.toString() ??
                        json['episodeNumber']?.toString() ??
                        '1',
                  ) ??
                  1),
        name: json['name']?.toString(),
        overview: json['overview']?.toString(),
        stillPath:
            json['stillPath']?.toString() ?? json['still_path']?.toString(),
      );
}

class TmdbEnrichedDetails {
  final int id;
  final String title;
  final String? imdbId;
  final String? overview;
  final String? tagline;
  final double? rating;
  final int? voteCount;
  final int? userScore; // e.g. 79 (%)
  final int? runtimeMinutes; // e.g. 145
  final String? formattedRuntime; // e.g. "2h 25m"
  final String? releaseDateWithCountry; // e.g. "07/30/2026 (IN)"
  final String? certification;
  final String? director;
  final List<TmdbCrewMember> crew;
  final List<TmdbCastMember> cast;
  final String? trailerYoutubeKey;
  final String? posterPath;
  final String? backdropPath;
  final List<String> genres;
  final String? releaseDate;

  const TmdbEnrichedDetails({
    required this.id,
    required this.title,
    this.imdbId,
    this.overview,
    this.tagline,
    this.rating,
    this.voteCount,
    this.userScore,
    this.runtimeMinutes,
    this.formattedRuntime,
    this.releaseDateWithCountry,
    this.certification,
    this.director,
    this.crew = const [],
    this.cast = const [],
    this.trailerYoutubeKey,
    this.posterPath,
    this.backdropPath,
    this.genres = const [],
    this.releaseDate,
  });

  String? get trailerUrl =>
      trailerYoutubeKey != null && trailerYoutubeKey!.isNotEmpty
      ? 'https://www.youtube.com/watch?v=$trailerYoutubeKey'
      : null;

  String? get posterUrl => posterPath != null && posterPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;

  String? get backdropUrl => backdropPath != null && backdropPath!.isNotEmpty
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (imdbId != null) 'imdbId': imdbId,
    'overview': overview,
    'tagline': tagline,
    'rating': rating,
    'voteCount': voteCount,
    'userScore': userScore,
    'runtimeMinutes': runtimeMinutes,
    'formattedRuntime': formattedRuntime,
    'releaseDateWithCountry': releaseDateWithCountry,
    'certification': certification,
    'director': director,
    'crew': crew.map((c) => c.toJson()).toList(),
    'cast': cast.map((c) => c.toJson()).toList(),
    'trailerYoutubeKey': trailerYoutubeKey,
    'posterPath': posterPath,
    'backdropPath': backdropPath,
    'genres': genres,
    'releaseDate': releaseDate,
  };

  factory TmdbEnrichedDetails.fromJson(
    Map<String, dynamic> json,
  ) => TmdbEnrichedDetails(
    id: json['id'] is int
        ? json['id']
        : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
    title: json['title']?.toString() ?? '',
    imdbId: json['imdbId']?.toString(),
    overview: json['overview']?.toString(),
    tagline: json['tagline']?.toString(),
    rating: (json['rating'] as num?)?.toDouble(),
    voteCount: json['voteCount'] is int
        ? json['voteCount']
        : int.tryParse(json['voteCount']?.toString() ?? ''),
    userScore: json['userScore'] is int
        ? json['userScore']
        : int.tryParse(json['userScore']?.toString() ?? ''),
    runtimeMinutes: json['runtimeMinutes'] is int
        ? json['runtimeMinutes']
        : int.tryParse(json['runtimeMinutes']?.toString() ?? ''),
    formattedRuntime: json['formattedRuntime']?.toString(),
    releaseDateWithCountry: json['releaseDateWithCountry']?.toString(),
    certification: json['certification']?.toString(),
    director: json['director']?.toString(),
    crew: (json['crew'] is List)
        ? (json['crew'] as List)
              .whereType<Map>()
              .map((m) => TmdbCrewMember.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : [],
    cast: (json['cast'] is List)
        ? (json['cast'] as List)
              .whereType<Map>()
              .map((m) => TmdbCastMember.fromJson(Map<String, dynamic>.from(m)))
              .toList()
        : [],
    trailerYoutubeKey: json['trailerYoutubeKey']?.toString(),
    posterPath: json['posterPath']?.toString(),
    backdropPath: json['backdropPath']?.toString(),
    genres: (json['genres'] is List)
        ? (json['genres'] as List).map((g) => g.toString()).toList()
        : [],
    releaseDate: json['releaseDate']?.toString(),
  );
}

class TmdbService {
  // Injected at compile time via: --dart-define-from-file=secrets.json (locally)
  // or via GitHub Secrets: --dart-define=TMDB_API_KEY=${{ secrets.TMDB_API_KEY }}
  static const String _apiKey = String.fromEnvironment(
    'TMDB_API_KEY',
    defaultValue: '26459a59e56d32d831cbd6d16bedd200',
  );
  static const String _readAccessToken = String.fromEnvironment(
    'TMDB_READ_TOKEN',
    defaultValue: 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyNjQ1OWE1OWU1NmQzMmQ4MzFjYmQ2ZDE2YmVkZDIwMCIsIm5iZiI6MTU0NjcwNDg2Ny45MTY5OTk4LCJzdWIiOiI1YzMwZDdlMzBlMGEyNjYzMDIzYTg3ZTIiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.IGw9c2kOcx6Qb2KYy9pHhmwjDkgOantmCDel76Nja8E',
  );

  static String get apiKey => _apiKey;
  static bool get hasApiKey => _apiKey.isNotEmpty;

  static const String _preferHttpKey = 'tmdb_prefer_http';

  static final TmdbService _instance = TmdbService._internal();
  factory TmdbService() => _instance;
  TmdbService._internal();

  final Map<String, TmdbEnrichedDetails> _cache = {};
  final Map<String, Map<int, TmdbEpisodeInfo>> _seasonEpisodeCache = {};
  final Map<String, String> _trailerUrlCache = {};
  bool? _preferHttp;

  @visibleForTesting
  http.Client? httpClient;

  @visibleForTesting
  void clearTrailerCache() {
    _trailerUrlCache.clear();
  }

  Future<http.Response> _httpGet(
    Uri url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) {
    final client = httpClient;
    final req = client != null
        ? client.get(url, headers: headers)
        : http.get(url, headers: headers);
    return timeout != null ? req.timeout(timeout) : req;
  }

  Future<http.Response> _httpPost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) {
    final client = httpClient;
    final req = client != null
        ? client.post(url, headers: headers, body: body)
        : http.post(url, headers: headers, body: body);
    return timeout != null ? req.timeout(timeout) : req;
  }

  static const String _defaultVisitorId =
      'CgtDaGJqdDZuYTZpOCihz5fVBjIKCgJJThIEGgAgGWLfAgrcAjIxLllUPVhGOTdJVmdIQUt6S3JQOHlNeUFKT1hjNkV0OGpzTnRXSlJrZnRoc3k0cG82aGNZTW50ME9FZ1RmRlEtWnVISjlvZ08xSjlraFlqNmIwZUNnbFJPTzZVZjFHaXVQdzJVYXRIQ1BHZFJ2OGhWWXRFeENYeEh4QzF4SE1FdnRjNzh3RnUtczdoNFhrNkNpdkJUejVDQnItNWxTU2ZzbDRSOGhpRzd2UTl3TG5hZFZkT09LZVNxMVQ4cXAyVkM1NnhuTEt6ZlBBNFdtUEpfVWlZS25aQXVVbVE5MFFQRFZHNzNwWHVXRkxacnRwX3V2cTVBYmE5VUVMeUxtYUZIcHQ3eUt0RFE4Q2pyNE9mXzViajQ4a2Ztd3lhcVdGcWdKLUNyTmlnb2oyU2IxMkNwNVE4WWVSSS1hUV81bGVqd0tEUXJ3X0JzUW4tWkRTRTVzeGtzOGZ1T1NuZw==';
  String? _cachedVisitorId;

  Future<String> _getVisitorId({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedVisitorId != null &&
        _cachedVisitorId!.isNotEmpty) {
      return _cachedVisitorId!;
    }
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString('yt_visitor_id');
        if (stored != null && stored.isNotEmpty) {
          _cachedVisitorId = stored;
          return stored;
        }
      } catch (_) {}
    }
    try {
      final resp = await _httpGet(
        Uri.parse('https://www.youtube.com'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        },
        timeout: const Duration(seconds: 3),
      );
      if (resp.statusCode == 200) {
        final html = resp.body;
        final m =
            RegExp(r'"visitorData":\s*"([^"]+)"').firstMatch(html) ??
            RegExp(r'"VISITOR_DATA":\s*"([^"]+)"').firstMatch(html);
        if (m != null && m.group(1) != null) {
          final id = m.group(1)!;
          _cachedVisitorId = id;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('yt_visitor_id', id);
          } catch (_) {}
          return id;
        }
      }
    } catch (_) {}

    _cachedVisitorId = _defaultVisitorId;
    return _defaultVisitorId;
  }

  Map<String, String> get _headers => {
    if (_readAccessToken.isNotEmpty)
      'Authorization': 'Bearer $_readAccessToken',
    'Accept': 'application/json',
  };

  Future<bool> _getPreferHttp() async {
    if (_preferHttp != null) return _preferHttp!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferHttp = prefs.getBool(_preferHttpKey) ?? false;
    } catch (_) {
      _preferHttp = false;
    }
    return _preferHttp!;
  }

  Future<void> _setPreferHttp(bool value) async {
    _preferHttp = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferHttpKey, value);
    } catch (_) {}
  }

  /// Perform a GET request to TMDB API with automatic fallback between HTTPS and HTTP
  /// (protecting against regional ISP TLS handshake drops on port 443).
  Future<http.Response?> _get(
    String pathAndQuery, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_apiKey.isEmpty && _readAccessToken.isEmpty) {
      debugPrint(
        'TmdbService: TMDB_API_KEY is not defined. Run flutter with: --dart-define-from-file=secrets.json',
      );
      return null;
    }

    final preferHttp = await _getPreferHttp();
    final schemes = preferHttp ? ['http', 'https'] : ['https', 'http'];
    final normPath = pathAndQuery.startsWith('/')
        ? pathAndQuery
        : '/$pathAndQuery';

    for (int i = 0; i < schemes.length; i++) {
      final scheme = schemes[i];
      final url = '$scheme://api.themoviedb.org/3$normPath';
      try {
        final effectiveTimeout = (scheme == 'https' && !preferHttp)
            ? const Duration(seconds: 3)
            : timeout;
        final resp = await _httpGet(
          Uri.parse(url),
          headers: _headers,
          timeout: effectiveTimeout,
        );
        if (resp.statusCode == 200 || resp.statusCode == 404) {
          if (scheme == 'http' && !preferHttp) {
            await _setPreferHttp(true);
          } else if (scheme == 'https' && preferHttp) {
            await _setPreferHttp(false);
          }
          return resp;
        }
      } catch (e) {
        debugPrint('TmdbService request failed on $scheme ($normPath): $e');
        if (i == 0 && scheme == 'https' && !preferHttp) {
          await _setPreferHttp(true);
        }
      }
    }
    return null;
  }

  static const Map<String, int> genreMap = {
    'action': 28,
    'adventure': 12,
    'animation': 16,
    'anime': 16,
    'comedy': 35,
    'crime': 80,
    'documentary': 99,
    'drama': 18,
    'family': 10751,
    'fantasy': 14,
    'history': 36,
    'horror': 27,
    'music': 10402,
    'mystery': 9648,
    'romance': 10749,
    'sci-fi': 878,
    'science fiction': 878,
    'thriller': 53,
    'war': 10752,
    'western': 37,
  };

  static const Map<int, String> tmdbGenreIdMap = {
    28: 'Action',
    12: 'Adventure',
    16: 'Animation',
    35: 'Comedy',
    80: 'Crime',
    99: 'Documentary',
    18: 'Drama',
    10751: 'Family',
    14: 'Fantasy',
    36: 'History',
    27: 'Horror',
    10402: 'Music',
    9648: 'Mystery',
    10749: 'Romance',
    878: 'Sci-Fi',
    10770: 'TV Movie',
    53: 'Thriller',
    10752: 'War',
    37: 'Western',
    10759: 'Action & Adventure',
    10762: 'Kids',
    10763: 'News',
    10764: 'Reality',
    10765: 'Sci-Fi & Fantasy',
    10766: 'Soap',
    10767: 'Talk',
    10768: 'War & Politics',
  };

  static const String _diskCachePrefix = 'tmdb_meta_';

  Future<TmdbEnrichedDetails?> _loadFromDisk(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_diskCachePrefix$key');
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          return TmdbEnrichedDetails.fromJson(map);
        }
      }
    } catch (e) {
      debugPrint('TmdbService load disk cache error: $e');
    }
    return null;
  }

  Future<void> _saveToDisk(String key, TmdbEnrichedDetails details) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(details.toJson());
      await prefs.setString('$_diskCachePrefix$key', raw);
    } catch (e) {
      debugPrint('TmdbService save disk cache error: $e');
    }
  }

  /// Clean title by stripping tags like [Hindi], (4K), language/audio tags, and season suffixes
  String cleanTitle(String title) {
    var cleaned = title
        // 1. Remove brackets, braces, parentheses and their contents: [Hindi], (2024), {Dubbed}
        .replaceAll(
          RegExp(r'\[.*?\]|\(.*?\)|[\{].*?[\}]', caseSensitive: false),
          ' ',
        )
        // 2. Remove common quality & codec tags
        .replaceAll(
          RegExp(
            r'\b(?:4K|UHD|HDR\d*|1080p|720p|480p|BluRay|WEBRip|WEB-DL|x264|x265|HEVC|Remux|DV|IMAX)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        // 3. Remove language and dub suffixes even without brackets: " - Hindi Dubbed", " - Dual Audio", " Hindi"
        .replaceAll(
          RegExp(
            r'(?:[-–—:]\s*)?\b(?:Dual\s*Audio|Multi\s*Audio|Hindi(?:\s*Dubbed)?|English(?:\s*Dubbed)?|Tamil(?:\s*Dubbed)?|Telugu(?:\s*Dubbed)?|Malayalam|Kannada|Bengali|Japanese|Korean|Dubbed|Subbed|Dub|Sub)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        // 4. Remove season/cour/part numbers so TV shows match parent series title on TMDB
        .replaceAll(
          RegExp(
            r'\b(?:Season\s*\d+|S\d{1,2}|Part\s*\d+|Cour\s*\d+)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        // 5. Clean trailing dashes, colons, dots, spaces
        .replaceAll(RegExp(r'[-–—:\s]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned.isNotEmpty ? cleaned : title.trim();
  }

  /// Generate smart search query candidates:
  /// 1. Cleaned title as-is
  /// 2. Primary title before colon or hyphen (e.g. "Mushoku Tensei: Jobless Reincarnation" -> "Mushoku Tensei")
  /// 3. Title with just brackets removed
  /// 4. Cleaned title with trailing punctuation removed
  /// 5. Title with dots removed (e.g. "G.D.N." -> "GDN", "R.R.R." -> "RRR")
  /// 6. Title with special characters replaced by space
  List<String> getSearchCandidates(String title) {
    final cleaned = cleanTitle(title);
    final candidates = <String>[];
    void add(String s) {
      final t = s.trim();
      if (t.isNotEmpty && !candidates.contains(t)) {
        candidates.add(t);
      }
    }

    add(cleaned);

    // Primary title before colon or dash
    if (cleaned.contains(':')) {
      add(cleaned.split(':').first.trim());
    }
    if (cleaned.contains(' - ')) {
      add(cleaned.split(' - ').first.trim());
    }

    // Title with just brackets stripped
    final justNoBrackets = title
        .replaceAll(
          RegExp(r'\[.*?\]|\(.*?\)|[\{].*?[\}]', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    add(justNoBrackets);

    // Strip trailing punctuation e.g. "G.D.N." -> "G.D.N"
    final noTrailingPunct = cleaned.replaceAll(RegExp(r'[\.\-_:\s,;]+$'), '');
    add(noTrailingPunct);

    // Strip dots inside acronyms e.g. "G.D.N." -> "GDN", "R.R.R." -> "RRR"
    final noDots = cleaned.replaceAll('.', '');
    add(noDots);

    // Strip special characters
    final alphaNum = cleaned
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    add(alphaNum);

    return candidates;
  }

  /// Get enriched details including cast, director, trailer, and age certification
  Future<TmdbEnrichedDetails?> getEnrichedDetails({
    required String title,
    String? year,
    bool isSeries = false,
  }) async {
    final cleaned = cleanTitle(title);
    final cacheKey = '$cleaned-$year-$isSeries'.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Check persistent disk cache
    final diskCached = await _loadFromDisk(cacheKey);
    if (diskCached != null) {
      _cache[cacheKey] = diskCached;
      return diskCached;
    }

    try {
      // 1. Search for item ID on TMDB
      int? tmdbId;
      bool detectedSeries = isSeries;
      final searchType = isSeries ? 'tv' : 'movie';
      final candidates = getSearchCandidates(title);

      // Try candidates with year first (if provided)
      if (year != null && year.isNotEmpty) {
        final yearParam = isSeries
            ? '&first_air_date_year=$year'
            : '&year=$year';
        for (final cand in candidates.take(2)) {
          final queryStr =
              '/search/$searchType?api_key=$apiKey&query=${Uri.encodeComponent(cand)}&include_adult=false$yearParam';
          final resp = await _get(queryStr);
          if (resp != null && resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data['results'] is List &&
                (data['results'] as List).isNotEmpty) {
              tmdbId = data['results'][0]['id'];
              break;
            }
          }
        }
      }

      // Fallback 1: try candidates without year
      if (tmdbId == null) {
        for (final cand in candidates) {
          final queryStr =
              '/search/$searchType?api_key=$apiKey&query=${Uri.encodeComponent(cand)}&include_adult=false';
          final resp = await _get(queryStr);
          if (resp != null && resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data['results'] is List &&
                (data['results'] as List).isNotEmpty) {
              tmdbId = data['results'][0]['id'];
              break;
            }
          }
        }
      }

      // Fallback 2: multi-search across all media types (handles misclassified series vs movie)
      if (tmdbId == null) {
        for (final cand in candidates) {
          final queryStr =
              '/search/multi?api_key=$apiKey&query=${Uri.encodeComponent(cand)}&include_adult=false';
          final resp = await _get(queryStr);
          if (resp != null && resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data['results'] is List &&
                (data['results'] as List).isNotEmpty) {
              final first = data['results'][0];
              tmdbId = first['id'];
              detectedSeries = first['media_type'] == 'tv';
              break;
            }
          }
        }
      }

      if (tmdbId == null) {
        return null;
      }

      // 2. Fetch complete details with appendices
      final append = detectedSeries
          ? 'videos,aggregate_credits,content_ratings,external_ids'
          : 'videos,credits,release_dates,external_ids';

      final detailsPath =
          '/${detectedSeries ? 'tv' : 'movie'}/$tmdbId?api_key=$apiKey&append_to_response=$append';
      final detailsResp = await _get(detailsPath);
      if (detailsResp == null || detailsResp.statusCode != 200) return null;

      final detailsData = jsonDecode(detailsResp.body) as Map<String, dynamic>;

      // Extract trailer (YouTube)
      String? youtubeKey;
      if (detailsData['videos']?['results'] is List) {
        final videos = (detailsData['videos']['results'] as List)
            .cast<Map<String, dynamic>>();
        // Find official trailer first
        final trailer = videos.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => videos.firstWhere(
            (v) =>
                v['site'] == 'YouTube' &&
                (v['type'] == 'Teaser' || v['type'] == 'Clip'),
            orElse: () => videos.isNotEmpty && videos.first['site'] == 'YouTube'
                ? videos.first
                : {},
          ),
        );
        if (trailer.containsKey('key')) {
          youtubeKey = trailer['key']?.toString();
          // Background pre-warm the trailer direct stream URL so it is instant
          if (youtubeKey != null && youtubeKey.isNotEmpty) {
            resolveTrailerDirectUrl(youtubeKey);
          }
        }
      }

      // Extract cast & featured crew
      final List<TmdbCastMember> castList = [];
      final List<TmdbCrewMember> crewList = [];
      final Set<String> seenCrew = {};
      String? directorName;

      void addCrew(String name, String role, String? profile) {
        if (name.trim().isEmpty) return;
        final key = '${name.toLowerCase().trim()}|$role';
        if (!seenCrew.contains(key)) {
          seenCrew.add(key);
          crewList.add(
            TmdbCrewMember(name: name.trim(), role: role, profilePath: profile),
          );
        }
      }

      final credits =
          detailsData['credits'] ?? detailsData['aggregate_credits'];
      if (credits != null) {
        if (credits['cast'] is List) {
          for (final c in (credits['cast'] as List).take(15)) {
            if (c is Map) {
              castList.add(
                TmdbCastMember.fromJson(Map<String, dynamic>.from(c)),
              );
            }
          }
        }
        if (credits['crew'] is List) {
          final allCrew = (credits['crew'] as List).whereType<Map>().toList();

          // 1. Director
          for (final cr in allCrew) {
            if (cr['job'] == 'Director' || cr['department'] == 'Directing') {
              directorName ??= cr['name']?.toString();
              addCrew(
                cr['name']?.toString() ?? '',
                'Director',
                cr['profile_path']?.toString(),
              );
            }
          }

          // 2. Writers / Screenplay
          for (final cr in allCrew) {
            final job = cr['job']?.toString() ?? '';
            if (job == 'Writer' || job == 'Screenplay' || job == 'Story') {
              addCrew(
                cr['name']?.toString() ?? '',
                'Writer',
                cr['profile_path']?.toString(),
              );
            }
          }

          // 3. Characters / Creator
          for (final cr in allCrew) {
            final job = cr['job']?.toString() ?? '';
            if (job == 'Characters' ||
                job == 'Comic Book' ||
                job == 'Creator' ||
                job == 'Novel') {
              addCrew(
                cr['name']?.toString() ?? '',
                'Characters',
                cr['profile_path']?.toString(),
              );
            }
          }

          // 4. Producers (fill up to 6 key crew members)
          if (crewList.length < 6) {
            for (final cr in allCrew) {
              final job = cr['job']?.toString() ?? '';
              if (job == 'Producer' || job == 'Executive Producer') {
                addCrew(
                  cr['name']?.toString() ?? '',
                  'Producer',
                  cr['profile_path']?.toString(),
                );
                if (crewList.length >= 6) break;
              }
            }
          }
        }
      }

      // Extract age rating certification and country release date
      String? cert;
      String? countryReleaseDate;
      String? countryCode;

      if (detectedSeries) {
        if (detailsData['content_ratings']?['results'] is List) {
          for (final cr in detailsData['content_ratings']['results']) {
            if (cr is Map &&
                (cr['iso_3166_1'] == 'US' ||
                    cr['iso_3166_1'] == 'IN' ||
                    cr['iso_3166_1'] == 'GB')) {
              final r = cr['rating']?.toString();
              if (r != null && r.isNotEmpty) {
                cert = r;
                countryCode ??= cr['iso_3166_1']?.toString();
                break;
              }
            }
          }
        }
      } else {
        if (detailsData['release_dates']?['results'] is List) {
          final rds = (detailsData['release_dates']['results'] as List)
              .whereType<Map>()
              .toList();
          final preferred = rds.firstWhere(
            (r) => r['iso_3166_1'] == 'IN',
            orElse: () => rds.firstWhere(
              (r) => r['iso_3166_1'] == 'US',
              orElse: () => rds.isNotEmpty ? rds.first : {},
            ),
          );
          if (preferred.isNotEmpty) {
            countryCode = preferred['iso_3166_1']?.toString();
            if (preferred['release_dates'] is List &&
                (preferred['release_dates'] as List).isNotEmpty) {
              final firstItem = preferred['release_dates'][0];
              if (firstItem is Map) {
                final c = firstItem['certification']?.toString();
                if (c != null && c.isNotEmpty) cert = c;
                final rd = firstItem['release_date']?.toString();
                if (rd != null && rd.length >= 10) {
                  countryReleaseDate = rd.substring(0, 10);
                }
              }
            }
          }

          // Fallback certification
          if (cert == null) {
            for (final rd in rds) {
              if (rd['release_dates'] is List) {
                for (final item in rd['release_dates']) {
                  if (item is Map) {
                    final c = item['certification']?.toString();
                    if (c != null && c.isNotEmpty) {
                      cert = c;
                      break;
                    }
                  }
                }
              }
              if (cert != null) break;
            }
          }
        }
      }

      // Format release date with country code: "07/30/2026 (IN)"
      countryReleaseDate ??=
          detailsData['release_date']?.toString() ??
          detailsData['first_air_date']?.toString();
      String? formattedReleaseWithCountry;
      if (countryReleaseDate != null && countryReleaseDate.length >= 10) {
        final rawYmd = countryReleaseDate.substring(0, 10);
        final parts = rawYmd.split('-');
        if (parts.length == 3) {
          final mdy = '${parts[1]}/${parts[2]}/${parts[0]}';
          formattedReleaseWithCountry = countryCode != null
              ? '$mdy ($countryCode)'
              : mdy;
        } else {
          formattedReleaseWithCountry = countryCode != null
              ? '$rawYmd ($countryCode)'
              : rawYmd;
        }
      }

      // Extract duration / runtime
      int? runtimeMinutes;
      if (detailsData['runtime'] is int) {
        runtimeMinutes = detailsData['runtime'];
      } else if (detailsData['episode_run_time'] is List &&
          (detailsData['episode_run_time'] as List).isNotEmpty) {
        runtimeMinutes = int.tryParse(
          (detailsData['episode_run_time'] as List).first.toString(),
        );
      }

      String? formattedRuntime;
      if (runtimeMinutes != null && runtimeMinutes > 0) {
        final h = runtimeMinutes ~/ 60;
        final m = runtimeMinutes % 60;
        if (h > 0 && m > 0) {
          formattedRuntime = '${h}h ${m}m';
        } else if (h > 0) {
          formattedRuntime = '${h}h';
        } else {
          formattedRuntime = '${m}m';
        }
      }

      // Extract user score (0-100)
      int? userScore;
      if (detailsData['vote_average'] is num) {
        final v = (detailsData['vote_average'] as num).toDouble();
        if (v > 0) {
          userScore = (v * 10).round().clamp(0, 100);
        }
      }

      // Extract genres
      final List<String> genres = [];
      if (detailsData['genres'] is List) {
        for (final g in detailsData['genres']) {
          if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString());
          }
        }
      }

      // Extract IMDb ID (from external_ids or root details)
      final imdbId =
          detailsData['external_ids']?['imdb_id']?.toString() ??
          detailsData['imdb_id']?.toString();

      final result = TmdbEnrichedDetails(
        id: tmdbId,
        title:
            detailsData['title']?.toString() ??
            detailsData['name']?.toString() ??
            cleaned,
        imdbId: imdbId,
        overview: detailsData['overview']?.toString(),
        tagline: detailsData['tagline']?.toString(),
        rating: (detailsData['vote_average'] is num)
            ? (detailsData['vote_average'] as num).toDouble()
            : null,
        voteCount: detailsData['vote_count'] is int
            ? detailsData['vote_count']
            : null,
        userScore: userScore,
        runtimeMinutes: runtimeMinutes,
        formattedRuntime: formattedRuntime,
        releaseDateWithCountry: formattedReleaseWithCountry,
        certification: cert,
        director: directorName,
        crew: crewList,
        cast: castList,
        trailerYoutubeKey: youtubeKey,
        posterPath: detailsData['poster_path']?.toString(),
        backdropPath: detailsData['backdrop_path']?.toString(),
        genres: genres,
        releaseDate:
            detailsData['release_date']?.toString() ??
            detailsData['first_air_date']?.toString(),
      );

      _cache[cacheKey] = result;
      await _saveToDisk(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('TmdbService getEnrichedDetails error for $title: $e');
      return null;
    }
  }

  /// Discover movies by genre ID or name (safe search)
  Future<List<MediaItem>> discoverByGenre(
    String genreName, {
    int page = 1,
    bool isSeries = false,
  }) async {
    final lower = genreName.toLowerCase().trim();
    final genreId = genreMap[lower] ?? (isSeries ? 10759 : 28);
    final endpoint = isSeries ? 'tv' : 'movie';

    final path =
        '/discover/$endpoint?api_key=$apiKey&with_genres=$genreId&sort_by=popularity.desc&include_adult=false&page=$page';

    try {
      final resp = await _get(path);
      if (resp == null || resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);

      if (data['results'] is List) {
        return _parseTmdbResults(data['results'], isSeries);
      }
      return [];
    } catch (e) {
      debugPrint('TmdbService discoverByGenre error: $e');
      return [];
    }
  }

  /// Trending media items (movies and TV series)
  Future<List<MediaItem>> getTrendingFeed({int page = 1}) async {
    try {
      final path = '/trending/all/day?api_key=$apiKey&page=$page';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List) {
          return _parseTmdbResults(data['results']);
        }
      }
    } catch (e) {
      debugPrint('TmdbService getTrendingFeed error: $e');
    }
    return [];
  }

  /// Popular movies
  Future<List<MediaItem>> getPopularMoviesFeed({int page = 1}) async {
    try {
      final path = '/movie/popular?api_key=$apiKey&page=$page';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List) {
          return _parseTmdbResults(data['results'], false);
        }
      }
    } catch (e) {
      debugPrint('TmdbService getPopularMoviesFeed error: $e');
    }
    return [];
  }

  /// Popular TV series
  Future<List<MediaItem>> getPopularSeriesFeed({int page = 1}) async {
    try {
      final path = '/tv/popular?api_key=$apiKey&page=$page';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List) {
          return _parseTmdbResults(data['results'], true);
        }
      }
    } catch (e) {
      debugPrint('TmdbService getPopularSeriesFeed error: $e');
    }
    return [];
  }

  /// Top-rated movies
  Future<List<MediaItem>> getTopRatedMoviesFeed({int page = 1}) async {
    try {
      final path = '/movie/top_rated?api_key=$apiKey&page=$page';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List) {
          return _parseTmdbResults(data['results'], false);
        }
      }
    } catch (e) {
      debugPrint('TmdbService getTopRatedMoviesFeed error: $e');
    }
    return [];
  }

  /// Upcoming movies
  Future<List<MediaItem>> getUpcomingMoviesFeed({int page = 1}) async {
    try {
      final path = '/movie/upcoming?api_key=$apiKey&page=$page';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List) {
          return _parseTmdbResults(data['results'], false);
        }
      }
    } catch (e) {
      debugPrint('TmdbService getUpcomingMoviesFeed error: $e');
    }
    return [];
  }

  /// Genre feed (wrapper around discoverByGenre)
  Future<List<MediaItem>> getGenreFeed(String genreName, {int page = 1}) =>
      discoverByGenre(genreName, page: page);

  /// Fetch related / recommended titles (recommendations with similar fallback)
  Future<List<MediaItem>> getRecommendationsOrSimilar({
    required int tmdbId,
    required bool isSeries,
  }) async {
    final type = isSeries ? 'tv' : 'movie';
    // 1. Try recommendations
    try {
      final path = '/$type/$tmdbId/recommendations?api_key=$apiKey';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List && (data['results'] as List).isNotEmpty) {
          final items = _parseTmdbResults(data['results'], isSeries);
          if (items.isNotEmpty) return items;
        }
      }
    } catch (e) {
      debugPrint('TmdbService recommendations error: $e');
    }

    // 2. Fallback to similar
    try {
      final path = '/$type/$tmdbId/similar?api_key=$apiKey';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['results'] is List && (data['results'] as List).isNotEmpty) {
          final items = _parseTmdbResults(data['results'], isSeries);
          if (items.isNotEmpty) return items;
        }
      }
    } catch (e) {
      debugPrint('TmdbService similar error: $e');
    }

    return [];
  }

  List<MediaItem> _parseTmdbResults(dynamic results, [bool? isSeriesFallback]) {
    final List<MediaItem> list = [];
    if (results is! List) return list;
    for (final item in results) {
      if (item is Map) {
        final id = item['id'].toString();
        final rawMediaType = item['media_type']?.toString();
        final bool isSeries = rawMediaType != null
            ? (rawMediaType == 'tv')
            : (isSeriesFallback ?? false);
        final title =
            (item['title'] ??
                    item['name'] ??
                    item['original_title'] ??
                    item['original_name'] ??
                    'Untitled')
                .toString();
        final poster = item['poster_path'] != null
            ? 'https://image.tmdb.org/t/p/w500${item['poster_path']}'
            : null;
        final backdrop = item['backdrop_path'] != null
            ? 'https://image.tmdb.org/t/p/w1280${item['backdrop_path']}'
            : null;
        final rating = (item['vote_average'] is num)
            ? (item['vote_average'] as num).toDouble()
            : null;
        final release = (item['release_date'] ?? item['first_air_date'])
            ?.toString();
        final year = release != null && release.length >= 4
            ? release.substring(0, 4)
            : null;

        final rawGenreIds = item['genre_ids'];
        final rawGenres = item['genres'];
        List<String> genreNames = [];
        if (rawGenreIds is List) {
          for (final gid in rawGenreIds) {
            final intId = gid is int
                ? gid
                : int.tryParse(gid?.toString() ?? '');
            if (intId != null && tmdbGenreIdMap.containsKey(intId)) {
              genreNames.add(tmdbGenreIdMap[intId]!);
            }
          }
        } else if (rawGenres is List) {
          for (final g in rawGenres) {
            if (g is Map && g['name'] != null) {
              genreNames.add(g['name'].toString());
            }
          }
        }
        final genreString = genreNames.isNotEmpty
            ? genreNames.join(' • ')
            : (isSeries ? 'TV Series' : 'Movie');

        list.add(
          MediaItem(
            id: id,
            title: title,
            mediaType: isSeries ? MediaType.series : MediaType.movie,
            year: year,
            posterUrl: poster,
            backdropUrl: backdrop,
            rating: rating,
            genre: genreString,
            provider: ProviderType.plugins,
          ),
        );
      }
    }
    return list;
  }

  /// Resolve direct streaming URL for trailer using YouTube InnerTube API (HLS m3u8 or MP4)
  Future<String> resolveTrailerDirectUrl(String youtubeKey) async {
    final key = youtubeKey.trim();
    if (key.isEmpty) return '';

    // 1. Check in-memory stream cache (instant 0ms playback)
    if (_trailerUrlCache.containsKey(key)) {
      final cached = _trailerUrlCache[key]!;
      if (cached.isNotEmpty) return cached;
    }

    final youtubeUrl = 'https://www.youtube.com/watch?v=$key';

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final visitorId = await _getVisitorId(forceRefresh: attempt > 0);

        final apiUrl = Uri.parse(
          'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        );
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'X-YouTube-Client-Name': '101',
          'X-YouTube-Client-Version': '1.02',
          'Origin': 'https://www.youtube.com',
          'X-Goog-Visitor-Id': visitorId,
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
        };

        final clientMap = <String, dynamic>{
          'clientName': 'VISIONOS',
          'clientVersion': '1.02',
          'deviceMake': 'Apple',
          'deviceModel': 'RealityDevice17,1',
          'osName': 'visionOS',
          'osVersion': '26.5.23O471',
          'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
          'visitorData': visitorId,
          'hl': 'en',
          'gl': 'US',
        };

        final body = jsonEncode({
          'context': {'client': clientMap},
          'videoId': key,
          'contentCheckOk': true,
          'racyCheckOk': true,
        });

        final res = await _httpPost(
          apiUrl,
          headers: headers,
          body: body,
          timeout: const Duration(seconds: 4),
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final playability =
              data['playabilityStatus'] as Map<String, dynamic>?;
          final status = playability?['status']?.toString();

          if (status == 'LOGIN_REQUIRED' && attempt == 0) {
            // Visitor token expired, loop to refresh and retry
            continue;
          }

          final streamingData = data['streamingData'] as Map<String, dynamic>?;
          if (streamingData != null) {
            // Prefer HLS master manifest playlist (direct streaming with audio+video)
            final hls = streamingData['hlsManifestUrl']?.toString();
            if (hls != null && hls.isNotEmpty) {
              _trailerUrlCache[key] = hls;
              return hls;
            }

            // Fallback to direct formats
            final formats = streamingData['formats'];
            if (formats is List && formats.isNotEmpty) {
              for (final f in formats) {
                if (f is Map &&
                    f['url'] is String &&
                    (f['url'] as String).isNotEmpty) {
                  final url = f['url'] as String;
                  _trailerUrlCache[key] = url;
                  return url;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('InnerTube trailer resolution error (attempt $attempt): $e');
      }
    }

    // 2. Fallback to desktop yt-dlp CLI tool if available (desktop only)
    try {
      final res = await Process.run('yt-dlp', [
        '-g',
        '--no-warnings',
        youtubeUrl,
      ], runInShell: true).timeout(const Duration(seconds: 4));

      if (res.exitCode == 0 && res.stdout != null) {
        final lines = (res.stdout as String).trim().split(RegExp(r'[\r\n]+'));
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('http')) {
            _trailerUrlCache[key] = trimmed;
            return trimmed;
          }
        }
      }
    } catch (_) {}

    return youtubeUrl;
  }

  /// Get season episodes info (thumbnail stills, title, overview) from TMDB
  /// Uses memory cache -> SharedPreferences disk cache (text & URLs only) -> TMDB API
  Future<Map<int, TmdbEpisodeInfo>> getSeasonEpisodes({
    required int tvId,
    required int seasonNumber,
  }) async {
    final cacheKey = 'tv_${tvId}_season_$seasonNumber';
    if (_seasonEpisodeCache.containsKey(cacheKey)) {
      return _seasonEpisodeCache[cacheKey]!;
    }

    // 1. Check persistent disk cache (SharedPreferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tmdb_season_episodes_${tvId}_$seasonNumber');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final Map<int, TmdbEpisodeInfo> map = {};
          for (final item in decoded) {
            if (item is Map) {
              final ep = TmdbEpisodeInfo.fromJson(
                Map<String, dynamic>.from(item),
              );
              map[ep.episodeNumber] = ep;
            }
          }
          if (map.isNotEmpty) {
            _seasonEpisodeCache[cacheKey] = map;
            return map;
          }
        }
      }
    } catch (e) {
      debugPrint('TmdbService load season episode disk cache error: $e');
    }

    // 2. Fetch from TMDB API
    try {
      final path = '/tv/$tvId/season/$seasonNumber?api_key=$apiKey';
      final resp = await _get(path);
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['episodes'] is List) {
          final Map<int, TmdbEpisodeInfo> map = {};
          final List<Map<String, dynamic>> toCache = [];
          for (final epJson in data['episodes']) {
            if (epJson is Map) {
              final ep = TmdbEpisodeInfo.fromJson(
                Map<String, dynamic>.from(epJson),
              );
              map[ep.episodeNumber] = ep;
              toCache.add(ep.toJson());
            }
          }
          _seasonEpisodeCache[cacheKey] = map;

          // Save to persistent disk cache (text and still path strings only, zero image binaries)
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'tmdb_season_episodes_${tvId}_$seasonNumber',
              jsonEncode(toCache),
            );
          } catch (e) {
            debugPrint('TmdbService save season episode disk cache error: $e');
          }

          return map;
        }
      }
    } catch (e) {
      debugPrint('TmdbService getSeasonEpisodes error: $e');
    }

    return {};
  }

  /// Get season episodes by title and season number (resolves tvId if not known)
  Future<Map<int, TmdbEpisodeInfo>> getSeasonEpisodesByTitle({
    required String title,
    String? year,
    required int seasonNumber,
  }) async {
    final details = await getEnrichedDetails(
      title: title,
      year: year,
      isSeries: true,
    );
    if (details == null || details.id <= 0) return {};
    return getSeasonEpisodes(tvId: details.id, seasonNumber: seasonNumber);
  }

  /// Get a single episode thumbnail URL from TMDB
  Future<String?> getEpisodeStillUrl({
    required int tvId,
    required int seasonNumber,
    required int episodeNumber,
  }) async {
    final episodes = await getSeasonEpisodes(
      tvId: tvId,
      seasonNumber: seasonNumber,
    );
    return episodes[episodeNumber]?.stillUrl;
  }

  final Map<String, SkipInterval?> _introSkipCache = {};

  /// Fetch verified episode intro skip timestamps using TMDB IMDb ID + IntroDB.
  /// Returns null if no verified timing is available (guaranteeing no fake/wrong skip intervals).
  Future<SkipInterval?> getEpisodeIntroSkip({
    required String title,
    String? year,
    required int season,
    required int episode,
    String? imdbId,
  }) async {
    final cleaned = cleanTitle(title);
    final cacheKey = '${cleaned}_s${season}_e$episode'.toLowerCase();
    if (_introSkipCache.containsKey(cacheKey)) {
      return _introSkipCache[cacheKey];
    }

    // 1. Check disk cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final diskKey = 'intro_skip_$cacheKey';
      final raw = prefs.getString(diskKey);
      if (raw != null) {
        if (raw.isEmpty || raw == 'null') {
          _introSkipCache[cacheKey] = null;
          return null;
        }
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final interval = SkipInterval.fromJson(decoded);
          _introSkipCache[cacheKey] = interval;
          return interval;
        }
      }
    } catch (e) {
      debugPrint('Intro skip disk cache read error: $e');
    }

    // 2. Resolve IMDb ID if not provided
    String? resolvedImdbId = imdbId;
    if (resolvedImdbId == null || resolvedImdbId.isEmpty) {
      final details = await getEnrichedDetails(
        title: title,
        year: year,
        isSeries: true,
      );
      resolvedImdbId = details?.imdbId;
    }

    if (resolvedImdbId == null || resolvedImdbId.isEmpty) {
      _introSkipCache[cacheKey] = null;
      return null;
    }

    // 3. Query IntroDB public API
    try {
      final uri = Uri.parse(
        'https://api.introdb.app/intro?imdb_id=$resolvedImdbId&season=$season&episode=$episode',
      );
      final resp = await _httpGet(uri, timeout: const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map) {
          final startSec =
              (data['start_sec'] as num?)?.toInt() ??
              ((data['start_ms'] as num?)?.toInt() != null
                  ? (data['start_ms'] as num).toInt() ~/ 1000
                  : null);
          final endSec =
              (data['end_sec'] as num?)?.toInt() ??
              ((data['end_ms'] as num?)?.toInt() != null
                  ? (data['end_ms'] as num).toInt() ~/ 1000
                  : null);

          if (startSec != null && endSec != null && endSec > startSec) {
            final interval = SkipInterval(
              type: SkipType.intro,
              startSeconds: startSec,
              endSeconds: endSec,
              label: 'Skip Intro',
            );
            _introSkipCache[cacheKey] = interval;

            // Save to disk cache
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'intro_skip_$cacheKey',
                jsonEncode(interval.toJson()),
              );
            } catch (_) {}

            return interval;
          }
        }
      }
    } catch (e) {
      debugPrint('IntroDB fetch error for $title S$season E$episode: $e');
    }

    // If not found or error, cache null so we don't spam network repeatedly
    _introSkipCache[cacheKey] = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('intro_skip_$cacheKey', 'null');
    } catch (_) {}

    return null;
  }
}
