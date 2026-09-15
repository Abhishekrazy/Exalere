import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../models/stremio_addon.dart';
import 'media_provider_plugin.dart';

/// Adapter that exposes a remote Stremio Addon as a native Exalere [MediaProviderPlugin].
class StremioAddonPlugin extends MediaProviderPlugin {
  final StremioAddonConfig config;
  final http.Client _client;

  StremioAddonPlugin({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  int get priority => 20; // User-installed addons take priority over legacy defaults

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
    int? season,
    int? episode,
  }) async {
    if (!isEnabled) return [];

    final baseUrl = _cleanBaseUrl(config.baseUrl);
    final isSeries = season != null && episode != null;
    final type = isSeries ? 'series' : 'movie';
    final queryId = isSeries ? '$subjectId:$season:$episode' : subjectId;
    final streamUrl = Uri.parse('$baseUrl/stream/$type/$queryId.json');

    try {
      debugPrint('[StremioAddonPlugin] Querying ${config.name} at: $streamUrl');
      final response = await _client
          .get(
            streamUrl,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Exalere/1.0 (Stremio-Compatible-Client)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          '[StremioAddonPlugin] ${config.name} returned HTTP ${response.statusCode}',
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
            final stream = StremioStream.fromJson(raw);
            if (stream.url.isNotEmpty) {
              streams.add(stream.toStreamSource(fallbackName: config.name));
            }
          } catch (e) {
            debugPrint('[StremioAddonPlugin] Error parsing stream item: $e');
          }
        }
      }

      debugPrint(
        '[StremioAddonPlugin] Resolved ${streams.length} stream(s) from ${config.name}',
      );
      return streams;
    } on TimeoutException {
      debugPrint(
        '[StremioAddonPlugin] Timeout querying ${config.name} ($streamUrl)',
      );
      return [];
    } catch (e) {
      debugPrint('[StremioAddonPlugin] Error querying ${config.name}: $e');
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
