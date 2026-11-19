import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// Torrentio — the public Stremio add-on that indexes torrent releases.
///
/// The add-on API is public and ungated: `stream/movie/<imdbId>.json` answers
/// with one entry per release, carrying an info hash plus trackers. Those are
/// turned into magnet links, which this app plays through its torrent engine
/// (the engine is what downloads and range-serves the file; Torrentio only
/// indexes it).
class TorrentioProvider extends MediaProviderPlugin {
  TorrentioProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String defaultBaseUrl = 'https://torrentio.strem.fun';

  @override
  String get id => 'torrentio';

  @override
  String get name => providerNameOverride ?? 'Torrentio';

  @override
  int get priority => 85;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => false;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => false;

  /// Magnet link for one stream entry, or null when the entry has no hash.
  static String? magnetFor(Map<String, dynamic> stream) {
    final hash = (stream['infoHash'] ?? '').toString().trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(hash)) return null;

    final hints = stream['behaviorHints'];
    final title = (stream['title'] ?? '').toString();
    final filename = hints is Map ? (hints['filename'] ?? '').toString() : '';
    final display = filename.isNotEmpty
        ? filename
        : title.split('\n').first.trim();
    final buffer = StringBuffer(
      'magnet:?xt=urn:btih:$hash'
      '&dn=${Uri.encodeComponent(display.isEmpty ? 'Torrentio' : display)}',
    );

    final trackers = <String>[];
    final sources = stream['sources'];
    if (sources is List) {
      for (final source in sources) {
        final text = source.toString();
        if (!text.startsWith('tracker:')) continue;
        final tracker = text.substring('tracker:'.length).trim();
        if (tracker.isNotEmpty) trackers.add(tracker);
      }
    }
    for (final tracker in trackers) {
      buffer.write('&tr=${Uri.encodeComponent(tracker)}');
    }
    return buffer.toString();
  }

  /// Quality label from the release title ("2160p", "1080p", ...) or the name.
  static String qualityFor(Map<String, dynamic> stream) {
    final haystack = '${stream['name'] ?? ''} ${stream['title'] ?? ''}'
        .toLowerCase();
    for (final quality in const ['2160p', '1080p', '720p', '480p', '360p']) {
      if (haystack.contains(quality)) return quality;
    }
    for (final tag in const ['4k', 'uhd']) {
      if (haystack.contains(tag)) return '2160p';
    }
    return 'Auto';
  }

  /// Streams from a Torrentio payload, best quality first and capped so the
  /// resolver sheet stays readable on a TV.
  static List<StreamSource> parseStreams(
    String body, {
    String providerName = 'Torrentio',
    int limit = 8,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final rawStreams = decoded is Map ? decoded['streams'] : null;
    if (rawStreams is! List) return const [];

    final results = <StreamSource>[];
    final seen = <String>{};
    for (final entry in rawStreams) {
      if (entry is! Map) continue;
      final stream = Map<String, dynamic>.from(entry);
      final magnet = magnetFor(stream);
      if (magnet == null || !seen.add(magnet)) continue;

      final quality = qualityFor(stream);
      final serverLine = (stream['name'] ?? '').toString().split('\n').first;
      results.add(
        StreamSource(
          quality: quality,
          resolution: quality == 'Auto' ? '' : quality,
          format: 'P2P',
          url: magnet,
          headers: const {},
          server: serverLine.isEmpty ? 'Torrentio' : serverLine.trim(),
          providerId: 'torrentio',
          providerName: providerName,
        ),
      );
    }

    int rank(String quality) {
      const order = ['2160p', '1080p', '720p', '480p', '360p', 'Auto'];
      final index = order.indexOf(quality);
      return index == -1 ? order.length : index;
    }

    results.sort((a, b) => rank(a.quality).compareTo(rank(b.quality)));
    return results.take(limit).toList(growable: false);
  }

  /// Builds the add-on URL for a movie or a series episode.
  static String streamUrl({
    required String imdbId,
    int? season,
    int? episode,
    String baseUrl = defaultBaseUrl,
  }) {
    final id = imdbId.trim();
    if (season != null && episode != null) {
      return '$baseUrl/stream/series/$id:$season:$episode.json';
    }
    return '$baseUrl/stream/movie/$id.json';
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
    final candidate = (imdbId ?? subjectId).trim();
    final resolved = candidate.toLowerCase().startsWith('tt')
        ? candidate.toLowerCase()
        : _imdbFromSubject(candidate);
    if (resolved == null) return const [];

    final url = streamUrl(
      imdbId: resolved,
      season: isSeries == true ? season : null,
      episode: isSeries == true ? episode : null,
    );
    try {
      final response = await _client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      return parseStreams(response.body, providerName: name);
    } catch (_) {
      return const [];
    }
  }

  /// `tt1234567`, `tt1234567:2:5` or `1234567` (bare numeric ids are not IMDb
  /// ids, so they are rejected rather than guessed).
  static String? _imdbFromSubject(String subject) {
    final match = RegExp(r'^(tt\d{5,})').firstMatch(subject.toLowerCase());
    return match?.group(1);
  }

  @override
  Future<List<MediaItem>> search(String query) async => const [];
}
