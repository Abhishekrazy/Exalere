import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import 'provider_registry.dart';

/// Provider integration for CircleFTP (BDIX Network)
/// High-speed local media server on Bangladesh Internet Exchange.
class BdixCircleFtpProvider {
  static const String defaultBaseUrl = 'http://new.circleftp.net:5000/api';
  static const String uploadsUrl = 'http://new.circleftp.net:5000/uploads/';
  static const String browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client;
  final String baseUrl;

  BdixCircleFtpProvider({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse('$baseUrl/posts')
          .replace(queryParameters: {'searchTerm': trimmed, 'order': 'desc'});

      // Quick timeout because BDIX is only reachable from BDIX networks
      final resp = await _client
          .get(uri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(milliseconds: 3500));

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final List<dynamic> posts = data is List
          ? data
          : (data is Map<String, dynamic>
                ? (data['posts'] ?? data['data'] ?? [])
                : []);

      return posts.map((item) {
        final map = item as Map<String, dynamic>;
        final id = map['_id']?.toString() ?? map['id']?.toString() ?? '';
        final title = map['title']?.toString() ?? map['name']?.toString() ?? '';
        final type = (map['type']?.toString() ?? '').toLowerCase();
        final isSeries = type == 'series';
        final image = map['image']?.toString() ?? map['imageSm']?.toString();
        final posterUrl = (image != null && image.isNotEmpty)
            ? '$uploadsUrl$image'
            : null;
        final year = map['year']?.toString();

        return MediaItem(
          id: id,
          title: title,
          mediaType: isSeries ? MediaType.series : MediaType.movie,
          year: year,
          posterUrl: posterUrl,
          provider: ProviderType.plugins,
          providerId: 'circleftp',
        );
      }).toList();
    } catch (e) {
      debugPrint('CircleFTP search error: $e');
      return [];
    }
  }

  Future<MediaDetails?> getDetails(String id) async {
    if (id.trim().isEmpty) return null;

    try {
      final uri = Uri.parse('$baseUrl/posts/${id.trim()}');
      final resp = await _client
          .get(uri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(milliseconds: 3500));

      if (resp.statusCode != 200) return null;

      final map = json.decode(resp.body) as Map<String, dynamic>;
      final title =
          map['title']?.toString() ?? map['name']?.toString() ?? 'Untitled';
      final type = (map['type']?.toString() ?? '').toLowerCase();
      final isSeries = type == 'series';
      final image = map['image']?.toString() ?? map['imageSm']?.toString();
      final posterUrl = (image != null && image.isNotEmpty)
          ? '$uploadsUrl$image'
          : null;
      final year = map['year']?.toString();
      final description = map['metaData']?.toString();

      return MediaDetails(
        id: id,
        title: title,
        mediaType: isSeries ? MediaType.series : MediaType.movie,
        year: year,
        posterUrl: posterUrl,
        backdropUrl: posterUrl,
        description: description,
        provider: ProviderType.plugins,
      );
    } catch (e) {
      debugPrint('CircleFTP getDetails error: $e');
      return null;
    }
  }

  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) async {
    String targetId = subjectId.trim();

    if (targetId.isEmpty || targetId.startsWith('/')) {
      if (title != null && title.trim().isNotEmpty) {
        final results = await search(title.trim());
        if (results.isNotEmpty) {
          final isSeries = season != null && season > 0;
          final matched = results.firstWhere(
            (r) => isSeries ? r.isSeries : !r.isSeries,
            orElse: () => results.first,
          );
          targetId = matched.id;
        }
      }
    }

    if (targetId.isEmpty) return [];

    try {
      final uri = Uri.parse('$baseUrl/posts/$targetId');
      final resp = await _client
          .get(uri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(milliseconds: 3500));

      if (resp.statusCode != 200) return [];

      final map = json.decode(resp.body) as Map<String, dynamic>;
      final type = (map['type']?.toString() ?? '').toLowerCase();
      final isSeries = type == 'series';
      final qualityStr = map['quality']?.toString() ?? 'HD';

      final List<StreamSource> sources = [];

      if (isSeries) {
        final content = map['content'];
        if (content is List &&
            season != null &&
            season > 0 &&
            episode != null &&
            episode > 0) {
          final sIdx = season - 1;
          if (sIdx < content.length) {
            final sVal = content[sIdx] as Map<String, dynamic>;
            final epArr = sVal['episodes'] as List<dynamic>?;
            if (epArr != null) {
              final eIdx = episode - 1;
              if (eIdx < epArr.length) {
                final eVal = epArr[eIdx] as Map<String, dynamic>;
                final link = eVal['link']?.toString();
                if (link != null && link.startsWith('http')) {
                  sources.add(
                    StreamSource(
                      quality: '$qualityStr (MP4)',
                      resolution: detectResolution(qualityStr),
                      format: 'MP4',
                      url: link,
                      headers: {'User-Agent': browserUa},
                      server: 'CircleFTP BDIX',
                      providerId: 'circleftp',
                      providerName: 'CircleFTP (BDIX)',
                    ),
                  );
                }
              }
            }
          }
        }
      } else {
        final content = map['content'];
        if (content is String && content.startsWith('http')) {
          sources.add(
            StreamSource(
              quality: '$qualityStr (MP4)',
              resolution: detectResolution(qualityStr),
              format: 'MP4',
              url: content,
              headers: {'User-Agent': browserUa},
              server: 'CircleFTP BDIX',
              providerId: 'circleftp',
              providerName: 'CircleFTP (BDIX)',
            ),
          );
        }
      }

      return sources;
    } catch (e) {
      debugPrint('CircleFTP getStreams error: $e');
      return [];
    }
  }

  static String detectResolution(String quality) {
    final lower = quality.toLowerCase();
    if (lower.contains('2160') || lower.contains('4k')) return '3840x2160';
    if (lower.contains('1080')) return '1920x1080';
    if (lower.contains('720')) return '1280x720';
    if (lower.contains('480')) return '854x480';
    return '1920x1080';
  }
}

/// Plug-and-play MediaProviderPlugin adapter for CircleFTP
class BdixCircleFtpAdapter extends MediaProviderPlugin {
  final BdixCircleFtpProvider _provider = BdixCircleFtpProvider();

  @override
  String get id => 'circleftp';

  @override
  String get name => 'CircleFTP (BDIX)';

  @override
  int get priority => 30;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<MediaDetails?> getDetails(String id) => _provider.getDetails(id);

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    imdbId: imdbId,
    season: season,
    episode: episode,
  );
}
