import 'dart:convert';

import '../../models/media_item.dart';
import 'html_grid_parser.dart';

/// Parses the Typesense-backed search responses these sites return.
///
/// Several sites share one search backend, so the response shape is identical
/// even though their HTML differs completely: `hits[].document` carrying
/// `post_title`, `permalink` and `post_thumbnail`. Reading that as JSON removes
/// the most fragile half of a scraper — there is no markup to break.
class TypesenseSearchParser {
  const TypesenseSearchParser._();

  /// Parses a search response into catalogue items.
  ///
  /// Permalinks may be absolute or site-relative; both are resolved against
  /// [baseUrl]. Entries missing a title or a link are dropped, since they render
  /// as unusable blank cards.
  static List<MediaItem> parse(
    String body, {
    required String baseUrl,
    required String providerId,
    bool stripDownloadPrefix = true,
  }) {
    final items = <MediaItem>[];

    final hits = _extractHits(body);
    for (final doc in hits) {
      var title = doc['post_title']?.toString() ?? '';
      if (stripDownloadPrefix) {
        title = title.replaceAll(RegExp('Download', caseSensitive: false), '');
      }
      title = title.trim();

      final permalink = doc['permalink']?.toString() ?? '';
      if (title.isEmpty || permalink.trim().isEmpty) continue;

      final url = _absolute(permalink, baseUrl);
      items.add(
        MediaItem(
          id: url,
          title: title,
          mediaType: HtmlGridParser.mediaTypeFor(title),
          year: HtmlGridParser.yearFrom(title),
          posterUrl: _absoluteOrNull(
            doc['post_thumbnail']?.toString(),
            baseUrl,
          ),
          provider: ProviderType.plugins,
          providerId: providerId,
        ),
      );
    }
    return items;
  }

  /// Extracts the `document` maps from a search body.
  ///
  /// Returns empty for anything malformed rather than throwing: a provider must
  /// degrade to "no results", never to a crash.
  static List<Map<dynamic, dynamic>> _extractHits(String body) {
    if (body.trim().isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];

    final hits = decoded['hits'];
    if (hits is! List) return const [];

    final docs = <Map<dynamic, dynamic>>[];
    for (final hit in hits) {
      if (hit is! Map) continue;
      final doc = hit['document'];
      if (doc is Map) docs.add(doc);
    }
    return docs;
  }

  static String _absolute(String value, String baseUrl) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http')) return trimmed;
    if (baseUrl.isEmpty) return trimmed;
    if (trimmed.startsWith('//')) return 'https:$trimmed';
    return '$baseUrl${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }

  static String? _absoluteOrNull(String? value, String baseUrl) {
    if (value == null || value.trim().isEmpty) return null;
    return _absolute(value, baseUrl);
  }
}
