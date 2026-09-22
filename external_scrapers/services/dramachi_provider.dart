import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import 'provider_registry.dart';

/// Provider integration for Dramachi (Asian Drama & Movie catalog)
/// Powered by the NodeObjects API with fast CDN streaming.
class DramachiProvider {
  static const String defaultBaseUrl = 'https://api.nodeobjects.com/';
  static const String imageCdnBase =
      'https://static.nodeobjects.com/thumbnail/';
  static const String browserUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final http.Client _client;
  final String baseUrl;

  DramachiProvider({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultBaseUrl;

  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'interface': 'search',
          'q': trimmed,
          'filter': 'all',
          'page': page.toString(),
        },
      );

      final resp = await _client
          .get(uri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final list = data['data'] as List<dynamic>?;
      if (list == null) return [];

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final id = map['id']?.toString() ?? '';
        final title = map['title']?.toString() ?? '';
        final content = (map['content']?.toString() ?? '').toLowerCase();
        final isMovie = content == 'movie' || content == 'movies';
        final thumb = map['thumb']?.toString();
        final posterUrl = (thumb != null && thumb.isNotEmpty)
            ? '$imageCdnBase$thumb'
            : null;
        final year = map['year']?.toString();

        return MediaItem(
          id: id,
          title: title,
          mediaType: isMovie ? MediaType.movie : MediaType.series,
          year: year,
          posterUrl: posterUrl,
          provider: ProviderType.plugins,
          providerId: 'dramachi',
        );
      }).toList();
    } catch (e) {
      debugPrint('Dramachi search error: $e');
      return [];
    }
  }

  Future<MediaDetails?> getDetails(String id) async {
    final titleId = id.contains('::') ? id.split('::').first.trim() : id.trim();
    if (titleId.isEmpty) return null;

    try {
      final uri = Uri.parse(baseUrl)
          .replace(queryParameters: {'interface': 'title_v2', 'id': titleId});

      final resp = await _client
          .get(uri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final albums = data['album'] as List<dynamic>?;
      if (albums == null || albums.isEmpty) return null;

      final album = albums.first as Map<String, dynamic>;
      final title = album['title']?.toString() ?? 'Untitled';
      final year = album['year']?.toString();
      final content = (album['content']?.toString() ?? '').toLowerCase();
      final isMovie = content == 'movie' || content == 'movies';
      final thumb = album['thumb']?.toString();
      final posterUrl = (thumb != null && thumb.isNotEmpty)
          ? '$imageCdnBase$thumb'
          : null;
      final description = album['storyline']?.toString();
      final genresStr = album['genres']?.toString();
      final genres = genresStr != null
          ? genresStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList()
          : <String>[];

      return MediaDetails(
        id: titleId,
        title: title,
        mediaType: isMovie ? MediaType.movie : MediaType.series,
        year: year,
        posterUrl: posterUrl,
        backdropUrl: posterUrl,
        description: description,
        genres: genres,
        provider: ProviderType.plugins,
      );
    } catch (e) {
      debugPrint('Dramachi getDetails error: $e');
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
    String? originProviderId,
    bool? isSeries,
  }) async {
    String? targetId;
    final isLookingForSeries = isSeries ?? (season != null && season > 0);

    if (originProviderId == 'dramachi') {
      targetId = subjectId.trim();
    } else if (title != null && title.trim().isNotEmpty) {
      final clean = MediaItem.parseTitleTags(title).cleanTitle;
      final results = await search(clean);
      if (results.isNotEmpty) {
        final matched =
            MediaItem.findBestMatch(
              candidates: results,
              title: clean,
              year: year,
              isSeries: isLookingForSeries,
            ) ??
            results.firstWhere(
              (r) => isLookingForSeries ? r.isSeries : !r.isSeries,
              orElse: () => results.first,
            );
        targetId = matched.id;
      }
    } else if (int.tryParse(subjectId.trim()) != null &&
        !subjectId.startsWith('/')) {
      targetId = subjectId.trim();
    }

    if (targetId == null ||
        targetId.isEmpty ||
        int.tryParse(targetId) == null) {
      return [];
    }

    try {
      // 1. Fetch title details to resolve season rip / version
      final detailsUri = Uri.parse(baseUrl)
          .replace(queryParameters: {'interface': 'title_v2', 'id': targetId});

      final detailsResp = await _client
          .get(detailsUri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 8));

      if (detailsResp.statusCode != 200) return [];

      final detailsData = json.decode(detailsResp.body) as Map<String, dynamic>;
      final rawSeasons = detailsData['seasons'];
      final seasonsMap = rawSeasons is Map<String, dynamic> ? rawSeasons : null;

      String ripToQuery = 'hd Rip';
      if (seasonsMap != null && seasonsMap.isNotEmpty) {
        if (season != null && season > 0) {
          final sPadded = 'Season ${season.toString().padLeft(2, '0')}';
          if (seasonsMap.containsKey(sPadded)) {
            final grp = seasonsMap[sPadded] as Map<String, dynamic>;
            final versions = grp['versions'] as List<dynamic>?;
            if (versions != null && versions.isNotEmpty) {
              final v = versions.first as Map<String, dynamic>;
              ripToQuery = v['rip']?.toString() ?? sPadded;
            } else {
              ripToQuery = sPadded;
            }
          }
        } else {
          final firstGrp = seasonsMap.values.first as Map<String, dynamic>;
          final versions = firstGrp['versions'] as List<dynamic>?;
          if (versions != null && versions.isNotEmpty) {
            final v = versions.first as Map<String, dynamic>;
            ripToQuery = v['rip']?.toString() ?? 'hd Rip';
          }
        }
      }

      // 2. Fetch episode list for the rip
      final epListUri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'interface': 'eplist',
          'season': ripToQuery,
          'id': targetId,
        },
      );

      final epResp = await _client
          .get(epListUri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 8));

      if (epResp.statusCode != 200) return [];

      final epData = json.decode(epResp.body) as Map<String, dynamic>;
      final episodeList = epData['episode_list'] as List<dynamic>?;
      if (episodeList == null || episodeList.isEmpty) return [];

      // 3. Match desired episode
      Map<String, dynamic>? targetEp;
      if (season != null && season > 0 && episode != null && episode > 0) {
        // Try exact match on f_title e.g. "Vincenzo S01E01"
        for (final item in episodeList) {
          final epMap = item as Map<String, dynamic>;
          final fTitle = epMap['f_title']?.toString() ?? '';
          final epNum = parseEpisodeNumber(fTitle);
          if (epNum == episode) {
            targetEp = epMap;
            break;
          }
        }
        // Fallback: index match
        if (targetEp == null && episode <= episodeList.length) {
          // Note: API might list episodes descending or ascending
          targetEp =
              episodeList[episodeList.length - episode]
                  as Map<String, dynamic>?;
        }
      } else {
        targetEp = episodeList.first as Map<String, dynamic>?;
      }

      if (targetEp == null) return [];

      final fid = targetEp['fid']?.toString();
      final disk = targetEp['disk']?.toString();
      if (fid == null || fid.isEmpty || disk == null || disk.isEmpty) return [];

      // 4. Fetch direct file stream host and URL
      final fileUri = Uri.parse(baseUrl).replace(
        queryParameters: {'interface': 'getFile', 'fid': fid, 'findex': disk},
      );

      final fileResp = await _client
          .get(fileUri, headers: {'User-Agent': browserUa})
          .timeout(const Duration(seconds: 8));

      if (fileResp.statusCode != 200) return [];

      final fileData = json.decode(fileResp.body) as Map<String, dynamic>;
      final hostInfo = fileData['hostInfo'] as Map<String, dynamic>?;
      final fileInfoList = fileData['fileInfo'] as List<dynamic>?;

      if (hostInfo == null || fileInfoList == null || fileInfoList.isEmpty) {
        return [];
      }

      final host = hostInfo['host']?.toString();
      final fileInfo = fileInfoList.first as Map<String, dynamic>;
      final rawPath = fileInfo['url']?.toString();

      if (host == null || host.isEmpty || rawPath == null || rawPath.isEmpty) {
        return [];
      }

      final cleanHost = host.replaceAll(RegExp(r'/+$'), '');
      final cleanPath = rawPath.replaceAll(RegExp(r'^/+'), '');
      final streamUrl = 'https://$cleanHost/cdn/$cleanPath';

      final qualityStr = targetEp['quality']?.toString() ?? 'HD';
      final sizeStr = targetEp['size']?.toString();
      final sizeBytes = sizeStr != null ? parseSizeBytes(sizeStr) : null;
      final resolution = qualityStr.contains('1080')
          ? '1920x1080'
          : (qualityStr.contains('720') ? '1280x720' : '960x540');

      return [
        StreamSource(
          quality: '$qualityStr (MKV)',
          resolution: resolution,
          format: 'MKV',
          url: streamUrl,
          headers: {'User-Agent': browserUa},
          server: 'Dramachi CDN ($qualityStr)',
          sizeBytes: sizeBytes,
          providerId: 'dramachi',
          providerName: 'Dramachi',
        ),
      ];
    } catch (e) {
      debugPrint('Dramachi getStreams error: $e');
      return [];
    }
  }

  static int? parseEpisodeNumber(String fTitle) {
    final match = RegExp(r'[eE](\d+)', caseSensitive: false).firstMatch(fTitle);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static int? parseSizeBytes(String text) {
    final match = RegExp(
      r'([\d\.]+)\s*(GB|MB|KB)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final val = double.tryParse(match.group(1)!);
    if (val == null) return null;
    final unit = match.group(2)!.toUpperCase();
    if (unit == 'GB') return (val * 1024 * 1024 * 1024).toInt();
    if (unit == 'MB') return (val * 1024 * 1024).toInt();
    if (unit == 'KB') return (val * 1024).toInt();
    return null;
  }
}

/// Plug-and-play MediaProviderPlugin adapter for Dramachi
class DramachiAdapter extends MediaProviderPlugin {
  final DramachiProvider _provider = DramachiProvider();

  @override
  String get id => 'dramachi';

  @override
  String get name => 'Dramachi';

  @override
  int get priority => 40;

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
    String? originProviderId,
    bool? isSeries,
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    imdbId: imdbId,
    season: season,
    episode: episode,
    originProviderId: originProviderId,
    isSeries: isSeries,
  );
}
