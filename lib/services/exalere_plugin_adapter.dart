import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../models/exalere_plugin.dart';
import 'media_provider_plugin.dart';
import 'tmdb_service.dart';

/// Adapter that exposes a remote Exalere Plugin as a native [MediaProviderPlugin].
class ExalerePluginAdapter extends MediaProviderPlugin {
  final ExalerePluginConfig config;
  final http.Client _client;

  ExalerePluginAdapter({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  int get priority => 20; // User-installed plugins take priority over legacy defaults

  @override
  bool get isEnabled => config.isEnabled;

  @override
  bool get supportsMovies => config.manifest?.supportsMovies ?? true;

  @override
  bool get supportsSeries => config.manifest?.supportsSeries ?? true;

  @override
  Future<void> init() async {
    // Initialized from config
  }

  @override
  Future<List<MediaItem>> search(String query) async => [];

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

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
    if (!isEnabled) return [];

    final baseUrl = _cleanBaseUrl(config.baseUrl);
    final isSeries = season != null && episode != null;
    final type = isSeries ? 'series' : 'movie';

    // Stremio addons require IMDb IDs (e.g. tt1234567).
    // If subjectId is already an IMDb ID, use it directly.
    // If an explicit imdbId is passed, prioritize it for Stremio addons.
    String effectiveId = subjectId;
    if (subjectId.startsWith('tt')) {
      effectiveId = subjectId;
    } else if (imdbId != null && imdbId.startsWith('tt')) {
      effectiveId = imdbId;
    } else if (title != null && title.trim().isNotEmpty) {
      try {
        final tmdb = await TmdbService().getEnrichedDetails(
          title: title,
          year: year,
          isSeries: isSeries,
          tmdbId: int.tryParse(subjectId),
        );
        if (tmdb?.imdbId != null && tmdb!.imdbId!.startsWith('tt')) {
          effectiveId = tmdb.imdbId!;
        }
      } catch (_) {}
    }

    final queryId = isSeries ? '$effectiveId:$season:$episode' : effectiveId;
    final streamUrl = Uri.parse('$baseUrl/stream/$type/$queryId.json');

    try {
      debugPrint(
        '[ExalerePluginAdapter] Querying ${config.name} at: $streamUrl',
      );
      final response = await _client
          .get(
            streamUrl,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Exalere-Plugin-Client)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          '[ExalerePluginAdapter] ${config.name} returned HTTP ${response.statusCode}',
        );
        return [];
      }

      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawStreams = data['streams'] as List<dynamic>? ?? const [];

      final streams = <StreamSource>[];
      for (final raw in rawStreams) {
        if (raw is Map<String, dynamic>) {
          try {
            final stream = ExalerePluginStream.fromJson(raw);
            if (stream.url.isNotEmpty &&
                (stream.url.startsWith('http://') ||
                    stream.url.startsWith('https://') ||
                    stream.url.startsWith('magnet:')) &&
                !stream.url.contains('youtube.com/watch') &&
                !stream.url.contains('youtu.be/')) {
              streams.add(stream.toStreamSource(fallbackName: config.name));
            }
          } catch (e) {
            debugPrint('[ExalerePluginAdapter] Error parsing stream item: $e');
          }
        }
      }

      debugPrint(
        '[ExalerePluginAdapter] Resolved ${streams.length} stream(s) from ${config.name}',
      );
      return streams;
    } on TimeoutException {
      debugPrint(
        '[ExalerePluginAdapter] Timeout querying ${config.name} ($streamUrl)',
      );
      return [];
    } catch (e) {
      debugPrint('[ExalerePluginAdapter] Error querying ${config.name}: $e');
      return [];
    }
  }

  static String _cleanBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/manifest.json')) {
      cleaned = cleaned.substring(0, cleaned.length - '/manifest.json'.length);
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }
}
