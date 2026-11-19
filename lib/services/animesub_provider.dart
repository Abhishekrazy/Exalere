import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';
import 'torrentio_provider.dart';

/// AnimeSub+ — ported from Vega's `animesub`.
///
/// The public instance is a Stremio add-on whose manifest requires
/// configuration (`configurationRequired: true`), so the bare manifest answers
/// 404 for streams. Its `/configure` form is plain HTML with a CSRF field, and
/// posting it with P2P enabled plus the torrent sources yields a token path
/// (`/u_xxx/…`) that serves real magnet streams. This engine performs that
/// configuration once, then resolves IMDb ids through the token.
class AnimeSubProvider extends MediaProviderPlugin {
  AnimeSubProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://animesub.duckdns.org';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Every torrent source the instance understands; the form only pre-checks a
  /// handful, and Vega appends the rest.
  static const List<String> allTorrentSources = [
    'nyaa',
    'animetosho',
    'tokyoTosho',
    'eraiRaws',
    'seadex',
    'nekobt',
    'animegarden',
    'tsukihimeDirect',
    'mikan',
    'dmhy',
    'subsplease',
    'anibt',
    'acgrip',
    'knaben',
    'piratebay',
    'torrentgalaxy',
    'torlock',
    'zilean',
    'comet',
    'stremthruTorz',
  ];

  String? _token;

  @override
  String get id => 'animesub';

  @override
  String get name => providerNameOverride ?? 'AnimeSub+';

  @override
  int get priority => 56;

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

  @override
  List<ProviderCatalogRow> get catalogs => const [];

  /// Field pairs to POST to `/configure`, derived from the rendered form.
  ///
  /// Checkboxes and radios contribute only when checked/selected; selects use
  /// their selected option (or the first one); text fields carry their value.
  static Map<String, String> parseConfigForm(String html) {
    final document = html_parser.parse(html);
    final form =
        document.querySelector('#configForm') ??
        document.querySelector('form') ??
        document.body;
    if (form == null) return const {};

    final values = <String, String>{};
    for (final element in form.querySelectorAll('input, select, textarea')) {
      final name = element.attributes['name'];
      if (name == null || name.isEmpty) continue;
      final type = (element.attributes['type'] ?? 'text').toLowerCase();

      if (type == 'checkbox' || type == 'radio') {
        if (element.attributes.containsKey('checked')) {
          values[name] = element.attributes['value'] ?? 'on';
        }
        continue;
      }
      values[name] = element.attributes['value'] ?? element.text.trim();
    }

    for (final select in form.querySelectorAll('select')) {
      final name = select.attributes['name'];
      if (name == null || name.isEmpty) continue;
      final options = select.querySelectorAll('option');
      if (options.isEmpty) continue;
      final selected = options.firstWhere(
        (option) => option.attributes.containsKey('selected'),
        orElse: () => options.first,
      );
      values[name] = selected.attributes['value'] ?? '';
    }
    return values;
  }

  /// Token path (`u_…`) from a configure response.
  static String? parseToken(String body) {
    final match = RegExp(
      r'''/(u_[A-Za-z0-9_-]+)(?:/manifest\.json|/stream)''',
    ).firstMatch(body);
    return match?.group(1);
  }

  static Uri manifestUri(String token) =>
      Uri.parse('$baseUrl/$token/manifest.json');

  static Uri streamUri(String token, String type, String id) =>
      Uri.parse('$baseUrl/$token/stream/$type/$id.json');

  /// IMDb id plus optional `:season:episode` from a subject id.
  static ({String imdb, int? season, int? episode}) parseSubject(
    String subjectId,
  ) {
    final parts = subjectId.split(':');
    final imdb = parts.first;
    final season = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final episode = parts.length > 2 ? int.tryParse(parts[2]) : null;
    return (imdb: imdb, season: season, episode: episode);
  }

  Future<http.Response?> _get(Uri uri) async {
    try {
      return await _client
          .get(
            uri,
            headers: {
              'User-Agent': _ua,
              'Accept': 'application/json, text/html',
              'Referer': '$baseUrl/',
            },
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      return null;
    }
  }

  /// Configures the add-on once and returns its token.
  Future<String?> _ensureToken() async {
    final cached = _token;
    if (cached != null) return cached;

    final page = await _get(Uri.parse('$baseUrl/configure'));
    if (page == null || page.statusCode != 200) return null;

    final fields = Map<String, String>.from(parseConfigForm(page.body));
    if (fields['csrf'] == null) return null;

    // Torrent streaming is what our player does; disable the "hide uncached"
    // filter and enable every source the instance knows.
    fields['enableP2P'] = 'on';
    fields.remove('hideUncached');

    final body = <String>[
      for (final entry in fields.entries)
        '${Uri.encodeQueryComponent(entry.key)}='
            '${Uri.encodeQueryComponent(entry.value)}',
      for (final source in allTorrentSources)
        'torrentSources%5B%5D=${Uri.encodeQueryComponent(source)}',
    ].join('&');

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/configure'),
            headers: {
              'User-Agent': _ua,
              'Accept': 'text/html',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Referer': '$baseUrl/configure',
              'Origin': baseUrl,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 302) return null;
      final token =
          parseToken(response.body) ??
          parseToken(response.headers['location'] ?? '');
      _token = token;
      return token;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async => const [];

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async => const [];

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
    final subject = parseSubject(
      imdbId?.isNotEmpty == true ? imdbId! : subjectId,
    );
    if (!subject.imdb.startsWith('tt')) return const [];

    final token = await _ensureToken();
    if (token == null) return const [];

    final isSeriesRequest =
        isSeries ??
        (season != null || episode != null || subject.season != null);
    final type = isSeriesRequest ? 'series' : 'movie';
    final seasonNumber = season ?? subject.season;
    final episodeNumber = episode ?? subject.episode;
    final id = isSeriesRequest
        ? '${subject.imdb}:$seasonNumber:$episodeNumber'
        : subject.imdb;

    final response = await _get(streamUri(token, type, id));
    if (response == null || response.statusCode != 200) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map) return const [];
    final streams = decoded['streams'];
    if (streams is! List) return const [];

    final results = <StreamSource>[];
    for (final entry in streams) {
      if (entry is! Map) continue;
      final infoHash = (entry['infoHash'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (infoHash.isEmpty) continue;
      final magnet = TorrentioProvider.magnetFor(
        Map<String, dynamic>.from(entry),
      );
      if (magnet == null) continue;
      results.add(
        StreamSource(
          quality: TorrentioProvider.qualityFor(
            Map<String, dynamic>.from(entry),
          ),
          resolution: '',
          format: 'P2P',
          url: magnet,
          server: 'AnimeSub+',
          providerId: 'animesub',
          providerName: name,
        ),
      );
      if (results.length >= 8) break;
    }
    return results;
  }

  /// Configuration state, exposed for tests and the self-test.
  String? get token => _token;
}
