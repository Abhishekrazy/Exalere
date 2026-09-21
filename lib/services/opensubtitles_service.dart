import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/stream_source.dart';

/// Lightweight service to fetch external subtitles from the OpenSubtitles v3
/// Stremio add-on protocol endpoint for movies and TV show episodes.
class OpenSubtitlesService {
  static final OpenSubtitlesService _instance =
      OpenSubtitlesService._internal();
  factory OpenSubtitlesService() => _instance;
  OpenSubtitlesService._internal();

  final http.Client _client = http.Client();
  static const String _baseUrl = 'https://opensubtitles-v3.strem.io/subtitles';

  static const Map<String, String> _languageNames = {
    'eng': 'English',
    'en': 'English',
    'spa': 'Spanish',
    'es': 'Spanish',
    'hin': 'Hindi',
    'hi': 'Hindi',
    'fra': 'French',
    'fre': 'French',
    'fr': 'French',
    'deu': 'German',
    'ger': 'German',
    'de': 'German',
    'ita': 'Italian',
    'it': 'Italian',
    'por': 'Portuguese',
    'pt': 'Portuguese',
    'rus': 'Russian',
    'ru': 'Russian',
    'ara': 'Arabic',
    'ar': 'Arabic',
    'jpn': 'Japanese',
    'ja': 'Japanese',
    'kor': 'Korean',
    'ko': 'Korean',
    'zho': 'Chinese',
    'chi': 'Chinese',
    'zh': 'Chinese',
    'tam': 'Tamil',
    'ta': 'Tamil',
    'tel': 'Telugu',
    'te': 'Telugu',
    'mal': 'Malayalam',
    'ml': 'Malayalam',
    'kan': 'Kannada',
    'kn': 'Kannada',
    'ben': 'Bengali',
    'bn': 'Bengali',
  };

  /// Fetch subtitles by IMDb ID.
  /// For movies: [imdbId] (e.g. "tt1375666")
  /// For series: [imdbId] with [season] and [episode] (e.g. "tt0903747:1:1")
  Future<List<SubtitleOption>> getSubtitles({
    required String imdbId,
    bool isSeries = false,
    int? season,
    int? episode,
  }) async {
    if (!imdbId.startsWith('tt')) return const [];

    try {
      final type = isSeries && season != null && episode != null
          ? 'series'
          : 'movie';
      final queryId = isSeries && season != null && episode != null
          ? '$imdbId:$season:$episode'
          : imdbId;

      final uri = Uri.parse('$_baseUrl/$type/$queryId.json');
      final response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Subtitle-Client)',
            },
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) {
        return const [];
      }

      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawSubs = data['subtitles'] as List<dynamic>? ?? const [];

      final List<SubtitleOption> subs = [];
      final Set<String> seenUrls = {};

      for (final s in rawSubs) {
        if (s is! Map) continue;
        final url = s['url']?.toString();
        if (url == null || url.isEmpty || !seenUrls.add(url)) continue;

        final rawLang = s['lang']?.toString().toLowerCase() ?? 'en';
        final friendlyName = _languageNames[rawLang] ?? rawLang.toUpperCase();

        subs.add(
          SubtitleOption(language: rawLang, name: friendlyName, url: url),
        );
      }

      return subs;
    } on TimeoutException {
      debugPrint(
        '[OpenSubtitlesService] Timeout querying subtitles for $imdbId',
      );
      return const [];
    } catch (e) {
      debugPrint('[OpenSubtitlesService] Error querying subtitles: $e');
      return const [];
    }
  }
}
