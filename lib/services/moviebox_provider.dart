import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/stream_source.dart';
import 'moviebox_client.dart';

class MovieBoxProvider {
  final MovieBoxClient _client = MovieBoxClient();

  Future<void> init() async {
    await _client.init();
  }

  /// Resolve DASH manifest index.mpd from CloudFront-Policy cookie
  static String? resolveDashManifestFromPolicy(String signCookie) {
    if (signCookie.isEmpty) return null;

    for (final part in signCookie.split(';')) {
      final trimmed = part.trim();
      if (trimmed.startsWith('CloudFront-Policy=')) {
        var rawPolicy = trimmed.substring('CloudFront-Policy='.length).trim();
        // Normalize custom base64
        var normalized = rawPolicy
            .replaceAll('-', '+')
            .replaceAll('_', '=')
            .replaceAll('~', '/');

        final pad = (4 - normalized.length % 4) % 4;
        if (pad > 0) {
          normalized += '=' * pad;
        }

        try {
          final decodedBytes = base64Decode(normalized);
          final decodedJson = jsonDecode(utf8.decode(decodedBytes));
          if (decodedJson is Map && decodedJson['Statement'] is List) {
            final firstStmt = (decodedJson['Statement'] as List).firstOrNull;
            if (firstStmt is Map && firstStmt['Resource'] is String) {
              var resource = (firstStmt['Resource'] as String).trim();
              while (resource.endsWith('*') || resource.endsWith('/')) {
                resource = resource.substring(0, resource.length - 1);
              }
              if (resource.startsWith('http://') ||
                  resource.startsWith('https://')) {
                return '$resource/index.mpd';
              }
            }
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Get Homepage feed items by tab
  /// tabId: "0" = Featured / All, "1" = Movies, "2" = Series
  Future<List<MediaItem>> getHomepageFeed({
    String tabId = '0',
    int page = 1,
  }) async {
    try {
      final res = await _client.get(
        '/wefeed-mobile-bff/tab-operating?page=$page&tabId=$tabId&version=',
      );

      if (res == null) return [];

      final List<dynamic> items = (res is Map ? res['items'] : res) ?? [];
      final List<MediaItem> mediaItems = [];
      final Set<String> seenIds = {};

      for (final group in items) {
        if (group is! Map) continue;

        // 1. Banner subjects
        final banner = group['banner'];
        if (banner is Map && banner['banners'] is List) {
          for (final b in banner['banners']) {
            if (b is Map && b['subject'] is Map) {
              var item = MediaItem.fromMovieBoxJson(b['subject']);
              if (item.backdropUrl == null || item.backdropUrl!.isEmpty) {
                String? bannerImg;
                if (b['image'] is Map) {
                  bannerImg = b['image']['url'];
                } else if (b['horizontalCover'] is Map) {
                  bannerImg = b['horizontalCover']['url'];
                } else if (b['banner'] is Map) {
                  bannerImg = b['banner']['url'];
                }
                bannerImg ??=
                    b['imgUrl'] ??
                    b['image']?.toString() ??
                    b['bannerUrl'] ??
                    b['horizontalCover']?.toString();
                if (bannerImg != null && bannerImg.isNotEmpty) {
                  item = item.copyWith(backdropUrl: bannerImg);
                }
              }
              if (item.id.isNotEmpty && seenIds.add(item.id)) {
                mediaItems.add(item);
              }
            }
          }
        }

        // 2. CustomData subjects
        final custom = group['customData'];
        if (custom is Map && custom['items'] is List) {
          for (final c in custom['items']) {
            if (c is Map && c['subject'] is Map) {
              final item = MediaItem.fromMovieBoxJson(c['subject']);
              if (item.id.isNotEmpty && seenIds.add(item.id)) {
                mediaItems.add(item);
              }
            }
          }
        }

        // 3. Direct subjects list
        final subjects = group['subjects'];
        if (subjects is List) {
          for (final s in subjects) {
            if (s is Map) {
              final item = MediaItem.fromMovieBoxJson(s);
              if (item.id.isNotEmpty && seenIds.add(item.id)) {
                mediaItems.add(item);
              }
            }
          }
        }
      }

      return mediaItems;
    } catch (e) {
      debugPrint('Error loading MovieBox homepage feed: $e');
      return [];
    }
  }

  /// Search titles
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    if (query.trim().isEmpty) return [];

    try {
      final payload = {
        'keyword': query,
        'page': page,
        'perPage': 15,
        'subjectType': 0,
      };

      final res = await _client.post(
        '/wefeed-mobile-bff/subject-api/search/v2',
        payload,
      );

      if (res == null) return [];

      final List<dynamic> subjects;
      if (res is Map &&
          res['results'] is List &&
          (res['results'] as List).isNotEmpty) {
        subjects = res['results'][0]['subjects'] ?? [];
      } else if (res is Map && res['list'] is List) {
        subjects = res['list'];
      } else {
        subjects = [];
      }

      return subjects
          .whereType<Map<String, dynamic>>()
          .where((s) => s['hasResource'] != false && s['hasResource'] != 0)
          .map((s) => MediaItem.fromMovieBoxJson(s))
          .where((item) => item.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('MovieBox search error: $e');
      return [];
    }
  }

  /// Get title details & seasons
  Future<MediaDetails?> getDetails(String subjectId) async {
    try {
      final detailsRes = await _client.get(
        '/wefeed-mobile-bff/subject-api/get?subjectId=$subjectId',
      );

      if (detailsRes == null) return null;

      final details = MediaDetails.fromMovieBoxJson(detailsRes);

      if (details.isSeries) {
        try {
          final seasonRes = await _client.get(
            '/wefeed-mobile-bff/subject-api/season-info?subjectId=$subjectId',
          );
          if (seasonRes is Map && seasonRes['seasons'] is List) {
            final List<Season> seasons = [];
            for (final s in seasonRes['seasons']) {
              seasons.add(Season.fromMovieBoxJson(s));
            }
            return MediaDetails(
              id: details.id,
              title: details.title,
              mediaType: details.mediaType,
              year: details.year,
              description: details.description,
              tagline: details.tagline,
              imdbRating: details.imdbRating,
              director: details.director,
              stars: details.stars,
              posterUrl: details.posterUrl,
              backdropUrl: details.backdropUrl,
              duration: details.duration,
              genres: details.genres,
              seasons: seasons,
              dubs: details.dubs,
              provider: details.provider,
            );
          }
        } catch (_) {}
      }

      return details;
    } catch (e) {
      debugPrint('MovieBox getDetails error: $e');
      return null;
    }
  }

  /// Get streams for movie (season=0, episode=0) or episode (season>0, episode>0)
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    int season = 0,
    int episode = 0,
  }) async {
    final List<StreamSource> sources = [];

    try {
      final path = (season == 0 && episode == 0)
          ? '/wefeed-mobile-bff/subject-api/play-info/v2?subjectId=$subjectId'
          : '/wefeed-mobile-bff/subject-api/play-info/v2?subjectId=$subjectId&se=$season&ep=$episode';

      final res = await _client.get(path);
      if (res is Map && res['streams'] is List) {
        for (final stream in res['streams']) {
          if (stream is! Map) continue;

          final streamId = stream['id']?.toString();
          final format = stream['format']?.toString() ?? 'MP4';
          final codec = stream['codecName'] ?? stream['codec'];
          final signCookie = stream['signCookie']?.toString() ?? '';
          final streamUrl = stream['url']?.toString() ?? '';
          final resolutions =
              stream['resolutions']?.toString() ?? '1080,720,480';
          final sizeBytes = int.tryParse(stream['size']?.toString() ?? '');

          // Forward authentication headers
          final headers = <String, String>{
            'Referer': 'https://sportslive.wine',
            'User-Agent': _client.userAgent,
          };
          if (signCookie.isNotEmpty) {
            final cleanCookie = signCookie
                .split(';')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .join('; ');
            headers['Cookie'] = cleanCookie;
          }

          final dashUrl = resolveDashManifestFromPolicy(signCookie);
          final directUrl = streamUrl.startsWith('http') ? streamUrl : null;

          if (dashUrl != null) {
            sources.add(
              StreamSource(
                quality: 'Multi-Res (Auto)',
                resolution: resolutions,
                format: 'DASH',
                url: dashUrl,
                headers: headers,
                codec: codec?.toString(),
                sizeBytes: sizeBytes,
                resourceId: streamId,
              ),
            );
          }

          if (directUrl != null && directUrl != dashUrl) {
            final primaryRes = resolutions.split(',').first.trim();
            final resLabel = primaryRes.isNotEmpty
                ? '${primaryRes}p'
                : 'Direct HD';
            sources.add(
              StreamSource(
                quality: resLabel,
                resolution: resolutions,
                format: format,
                url: directUrl,
                headers: headers,
                codec: codec?.toString(),
                sizeBytes: sizeBytes,
                resourceId: streamId,
              ),
            );
          }
        }
      }

      // Fallback: try resource API if play-info had no direct streams
      if (sources.isEmpty) {
        final resPath = (season == 0 && episode == 0)
            ? '/wefeed-mobile-bff/subject-api/resource?subjectId=$subjectId&page=1&perPage=10'
            : '/wefeed-mobile-bff/subject-api/resource?subjectId=$subjectId&se=$season&ep=$episode&page=1&perPage=10';

        final rRes = await _client.get(resPath);
        if (rRes is Map && rRes['list'] is List) {
          for (final item in rRes['list']) {
            if (item is! Map) continue;
            final link = item['resourceLink'] ?? item['url'];
            if (link is String && link.startsWith('http')) {
              final resNum = item['resolution']?.toString() ?? '1080';
              sources.add(
                StreamSource(
                  quality: '${resNum}p',
                  resolution: resNum,
                  format: 'Direct',
                  url: link,
                  headers: {},
                  resourceId:
                      item['resourceId']?.toString() ?? item['id']?.toString(),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('MovieBox getStreams error: $e');
    }

    return sources;
  }

  /// Get external subtitles
  Future<List<SubtitleOption>> getSubtitles({
    required String subjectId,
    String? resourceId,
  }) async {
    if (resourceId == null || resourceId.isEmpty) return [];

    try {
      final res = await _client.get(
        '/wefeed-mobile-bff/subject-api/get-ext-captions?subjectId=$subjectId&resourceId=$resourceId',
      );

      final captions = (res is Map ? res['extCaptions'] : null) ?? [];
      final List<SubtitleOption> subs = [];
      final Set<String> seenUrls = {};

      for (final cap in captions) {
        if (cap is! Map) continue;
        final url = cap['url']?.toString();
        if (url == null || url.isEmpty || !seenUrls.add(url)) continue;

        final size = int.tryParse(cap['size']?.toString() ?? '0') ?? 0;
        if (size > 0 && size <= 50) {
          continue; // Filter placeholder dummy captions
        }

        final rawName = cap['lanName'] ?? cap['lan'] ?? 'English';
        subs.add(
          SubtitleOption(
            language: cap['lan']?.toString() ?? 'en',
            name: rawName.toString(),
            url: url,
          ),
        );
      }

      return subs;
    } catch (e) {
      debugPrint('MovieBox getSubtitles error: $e');
      return [];
    }
  }
}
