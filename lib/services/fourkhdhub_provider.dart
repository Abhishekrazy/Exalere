import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';

class FourKHdHubProvider {
  static const String defaultBaseUrl = 'https://4khdhub.one';
  static const String browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client = http.Client();

  Future<List<MediaItem>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse('$defaultBaseUrl/')
          .replace(queryParameters: {'s': query});
      final resp = await _client
          .get(
            uri,
            headers: {
              'User-Agent': browserUa,
              'Accept': 'text/html,application/xhtml+xml,application/xml',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return [];

      return parseSearchResults(resp.body);
    } catch (e) {
      debugPrint('4KHDHub search error: $e');
      return [];
    }
  }

  List<MediaItem> parseSearchResults(String html) {
    final List<MediaItem> items = [];
    final cardRegex = RegExp(
      r'<a\s+[^>]*class="[^"]*movie-card[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>',
      caseSensitive: false,
    );
    final titleRegex = RegExp(
      r'<[^>]*class="[^"]*movie-card-title[^"]*"[^>]*>([^<]+)<',
      caseSensitive: false,
    );
    final imgRegex = RegExp(r'<img\s+[^>]*src="([^"]+)"', caseSensitive: false);
    final metaRegex = RegExp(
      r'<[^>]*class="[^"]*movie-card-meta[^"]*"[^>]*>([^<]+)<',
      caseSensitive: false,
    );

    for (final match in cardRegex.allMatches(html)) {
      final href = match.group(1);
      final cardHtml = match.group(2) ?? '';
      if (href == null || href.isEmpty) continue;

      final titleMatch = titleRegex.firstMatch(cardHtml);
      final title = titleMatch?.group(1)?.trim();
      if (title == null || title.isEmpty) continue;

      final imgMatch = imgRegex.firstMatch(cardHtml);
      final posterUrl = imgMatch?.group(1);

      final metaMatch = metaRegex.firstMatch(cardHtml);
      final metaText = metaMatch?.group(1)?.trim();
      String? year;
      if (metaText != null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(metaText);
        year = yMatch?.group(0);
      }

      final isSeries = href.contains('-series-');

      items.add(
        MediaItem(
          id: href,
          title: title,
          mediaType: isSeries ? MediaType.series : MediaType.movie,
          year: year,
          posterUrl: posterUrl,
          provider: ProviderType.fourKHdHub,
        ),
      );
    }

    return items;
  }

  Future<MediaDetails?> getDetails(String path) async {
    try {
      final url = path.startsWith('http') ? path : '$defaultBaseUrl$path';
      final resp = await _client
          .get(Uri.parse(url), headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;
      final html = resp.body;

      final h1Match = RegExp(
        r'<h1[^>]*>([^<]+)<\/h1>',
        caseSensitive: false,
      ).firstMatch(html);
      final title = h1Match?.group(1)?.trim() ?? 'Untitled';

      final descMatch = RegExp(
        r'<div\s+[^>]*class="[^"]*content-section[^"]*"[^>]*>[\s\S]*?<p[^>]*>([^<]+)<\/p>',
        caseSensitive: false,
      ).firstMatch(html);
      final desc = descMatch?.group(1)?.trim();

      final imdbMatch = RegExp(
        r'<[^>]*class="[^"]*imdb-score[^"]*"[^>]*>([^<]+)<',
        caseSensitive: false,
      ).firstMatch(html);
      final imdb = imdbMatch?.group(1)?.trim();

      final imgMatch = RegExp(
        r'<div\s+[^>]*class="[^"]*movie-poster[^"]*"[^>]*>[\s\S]*?<img\s+[^>]*src="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      final poster = imgMatch?.group(1);

      return MediaDetails(
        id: path,
        title: title,
        mediaType: path.contains('-series-')
            ? MediaType.series
            : MediaType.movie,
        description: desc,
        imdbRating: imdb,
        posterUrl: poster,
        provider: ProviderType.fourKHdHub,
      );
    } catch (e) {
      debugPrint('4KHDHub details error: $e');
      return null;
    }
  }

  Future<List<StreamSource>> getStreams(String path) async {
    final List<StreamSource> sources = [];
    try {
      final url = path.startsWith('http') ? path : '$defaultBaseUrl$path';
      final resp = await _client
          .get(Uri.parse(url), headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return sources;
      final html = resp.body;

      final linkRegex = RegExp(
        r'href="([^"]*(?:hubcloud|hubdrive|drive|stream)[^"]*)"',
        caseSensitive: false,
      );
      for (final match in linkRegex.allMatches(html)) {
        final link = match.group(1);
        if (link != null && link.startsWith('http')) {
          sources.add(
            StreamSource(
              quality: 'HD Stream',
              resolution: '1080',
              format: 'MP4',
              url: link,
              headers: {'Referer': defaultBaseUrl, 'User-Agent': browserUa},
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('4KHDHub getStreams error: $e');
    }
    return sources;
  }
}
