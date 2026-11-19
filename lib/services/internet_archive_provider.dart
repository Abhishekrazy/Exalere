import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// Internet Archive (archive.org) — the public-domain / Creative Commons video
/// library, ported from Vega's `internetArchive` provider.
///
/// Everything here is an open API, so unlike the mirror sites this provider has
/// no gate to solve: `advancedsearch.php` lists items and `metadata/<id>` lists
/// the files those items serve. A stream is the item's own `/download/` URL,
/// which archive.org serves with range requests.
class InternetArchiveProvider extends MediaProviderPlugin {
  InternetArchiveProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://archive.org';

  /// Video extensions archive.org serves as plain files.
  static const List<String> videoExtensions = [
    '.mp4',
    '.m4v',
    '.mkv',
    '.webm',
    '.ogv',
    '.mov',
    '.avi',
    '.mpeg',
    '.mpg',
  ];

  @override
  String get id => 'internetarchive';

  @override
  String get name => providerNameOverride ?? 'Internet Archive';

  @override
  int get priority => 60;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => false;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => false;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(
      id: 'public_domain',
      title: 'Public domain on Archive.org',
    ),
  ];

  /// Search URL: `advancedsearch.php` asks for the four fields this provider
  /// actually renders.
  static String searchUrl(String query, {int page = 1, int rows = 24}) {
    final q = Uri.encodeComponent('$query AND mediatype:(movies)');
    final fields = [
      'identifier',
      'title',
      'year',
      'downloads',
    ].map((field) => 'fl[]=$field').join('&');
    final sort = Uri.encodeComponent('downloads desc');
    return '$baseUrl/advancedsearch.php?q=$q&$fields&sort[]=$sort'
        '&rows=$rows&page=$page&output=json';
  }

  static String catalogUrl({int page = 1, int rows = 24}) {
    final q = Uri.encodeComponent(
      'mediatype:(movies) AND (licenseurl:*publicdomain* OR '
      'licenseurl:*creativecommons*)',
    );
    final fields = [
      'identifier',
      'title',
      'year',
      'downloads',
    ].map((field) => 'fl[]=$field').join('&');
    final sort = Uri.encodeComponent('downloads desc');
    return '$baseUrl/advancedsearch.php?q=$q&$fields&sort[]=$sort'
        '&rows=$rows&page=$page&output=json';
  }

  /// Parses the `response.docs` array of an advanced-search payload.
  static List<MediaItem> parseSearchJson(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final response = decoded is Map ? decoded['response'] : null;
    final docs = response is Map ? response['docs'] : null;
    if (docs is! List) return const [];

    final items = <MediaItem>[];
    final seen = <String>{};
    for (final doc in docs) {
      if (doc is! Map) continue;
      final identifier = (doc['identifier'] ?? '').toString().trim();
      if (identifier.isEmpty || !seen.add(identifier)) continue;
      final rawTitle = (doc['title'] ?? identifier).toString().trim();
      // Titles in the archive are often a list of alternate names.
      final title = rawTitle.replaceAll(RegExp(r'\s+'), ' ');
      final year = (doc['year'] ?? '').toString().trim();
      items.add(
        MediaItem(
          id: identifier,
          title: title,
          mediaType: MediaType.movie,
          year: year.isEmpty ? null : year,
          posterUrl: '$baseUrl/services/img/$identifier',
          providerId: 'internetarchive',
        ),
      );
    }
    return items;
  }

  /// Picks the file to stream from an item's `files` array.
  ///
  /// Archive items carry every derivative the uploader produced (thumbnails,
  /// subtitles, multiple encodes). Prefer `*.mp4`, then the tallest video that
  /// is still TV-friendly, then the largest remaining video file.
  static Map<String, dynamic>? pickVideoFile(List<dynamic> files) {
    final videos = <Map<String, dynamic>>[];
    for (final file in files) {
      if (file is! Map) continue;
      final name = (file['name'] ?? '').toString();
      final lower = name.toLowerCase();
      if (!videoExtensions.any(lower.endsWith)) continue;
      videos.add(Map<String, dynamic>.from(file));
    }
    if (videos.isEmpty) return null;

    int heightOf(Map<String, dynamic> file) {
      final raw = file['height'];
      final parsed = raw is num ? raw.toInt() : int.tryParse('$raw');
      if (parsed != null && parsed > 0) return parsed;
      final name = (file['name'] ?? '').toString();
      final match = RegExp(r'(2160|1080|720|480|360)').firstMatch(name);
      return match == null ? 0 : int.parse(match.group(1)!);
    }

    int sizeOf(Map<String, dynamic> file) {
      final raw = file['size'];
      return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
    }

    videos.sort((a, b) {
      final byHeight = heightOf(b).compareTo(heightOf(a));
      if (byHeight != 0) return byHeight;
      return sizeOf(b).compareTo(sizeOf(a));
    });
    return videos.first;
  }

  /// Builds a playable source list from an item metadata payload.
  static List<StreamSource> streamsFromMetadata(
    String body, {
    required String identifier,
    String providerName = 'Internet Archive',
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final files = decoded is Map ? decoded['files'] : null;
    if (files is! List) return const [];

    final file = pickVideoFile(files);
    if (file == null) return const [];

    final name = (file['name'] ?? '').toString();
    final height = file['height'];
    final parsedHeight = height is num
        ? height.toInt()
        : int.tryParse('$height');
    final quality = parsedHeight != null && parsedHeight > 0
        ? '${parsedHeight}p'
        : 'Auto';
    final url = '$baseUrl/download/$identifier/${Uri.encodeComponent(name)}';

    return [
      StreamSource(
        quality: quality,
        resolution: parsedHeight == null ? '' : '${parsedHeight}p',
        format: name.toLowerCase().endsWith('.m3u8') ? 'HLS' : 'MP4',
        url: url,
        headers: const {},
        server: 'Archive.org',
        providerId: 'internetarchive',
        providerName: providerName,
        availableQualities: [quality],
      ),
    ];
  }

  Future<String?> _get(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: {'User-Agent': 'Exalere/2.0'})
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return null;
      return response.body;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final body = await _get(searchUrl(trimmed));
    if (body == null) return const [];
    return parseSearchJson(body);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final body = await _get(catalogUrl(page: page));
    if (body == null) return const [];
    return parseSearchJson(body);
  }

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async {
    final identifier = subjectId
        .replaceFirst(RegExp(r'^https?://archive\.org/details/'), '')
        .split('?')
        .first
        .trim();
    if (identifier.isEmpty) return const [];
    final body = await _get('$baseUrl/metadata/$identifier');
    if (body == null) return const [];
    return streamsFromMetadata(
      body,
      identifier: identifier,
      providerName: name,
    );
  }
}
