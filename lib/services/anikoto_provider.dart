import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/media_provider_plugin.dart';

/// Anikoto — ported from Vega's `anikoto` provider.
///
/// Four hops, each with its own trick:
/// 1. an anime page carries `data-id`; the episode list answers only with a
///    `vrf` parameter equal to `base64(RC4("simple-hash", animeId))`.
/// 2. an episode's `data-ids` unlocks `/ajax/server/list`, whose servers carry a
///    `data-link-id` that `/ajax/server?get=` turns into an embed URL.
/// 3. the embed page (MegaPlay) exposes a `data-id`; `/stream/getSources`
///    answers `{enc: …}` — AES-256-CBC with a zero-padded key.
/// 4. the decrypted payload holds the HLS master playlist.
class AnikotoProvider extends MediaProviderPlugin {
  AnikotoProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://anikototv.to';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// RC4 key the site uses for its `vrf` request guard.
  static const String vrfKey = 'simple-hash';

  /// MegaPlay key material; the 16-byte string is zero-padded to 32 bytes, so
  /// this is AES-256-CBC.
  static const String megaKey = 'i?LMTAx0Q6,:}50U';
  static const String megaIv = "W0;27ToaUpl_P%'c";

  @override
  String get id => 'anikoto';

  @override
  String get name => providerNameOverride ?? 'Anikoto';

  @override
  int get priority => 55;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => true;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest on Anikoto'),
  ];

  static Uri searchUri(String query) =>
      Uri.parse('$baseUrl/search?keyword=${Uri.encodeQueryComponent(query)}');

  static Uri homeUri({int page = 1}) => Uri.parse('$baseUrl/home?page=$page');

  static Uri episodesUri(String animeId) => Uri.parse(
    '$baseUrl/ajax/episode/list/$animeId?vrf=${Uri.encodeQueryComponent(encodeVrf(animeId))}&style=default',
  );

  static Uri serverListUri(String dataIds) => Uri.parse(
    '$baseUrl/ajax/server/list?servers=${Uri.encodeQueryComponent(dataIds)}',
  );

  static Uri serverUri(String linkId) =>
      Uri.parse('$baseUrl/ajax/server?get=${Uri.encodeQueryComponent(linkId)}');

  static Uri sourcesUri(String host, String id, String type) =>
      Uri.parse('https://$host/stream/getSources?id=$id&type=$type&s=tcdn');

  /// Classic RC4 over UTF-16 code units, the site's request guard.
  static String rc4(String key, String input) {
    final state = List<int>.generate(256, (index) => index);
    var j = 0;
    for (var i = 0; i < 256; i++) {
      j = (j + state[i] + key.codeUnitAt(i % key.length)) & 255;
      final temp = state[i];
      state[i] = state[j];
      state[j] = temp;
    }
    var i = 0;
    j = 0;
    final output = StringBuffer();
    for (final code in input.codeUnits) {
      i = (i + 1) & 255;
      j = (j + state[i]) & 255;
      final temp = state[i];
      state[i] = state[j];
      state[j] = temp;
      output.writeCharCode(code ^ state[(state[i] + state[j]) & 255]);
    }
    return output.toString();
  }

  /// `vrf` value for an anime id.
  static String encodeVrf(String animeId) {
    final enciphered = rc4(vrfKey, animeId);
    return base64Encode(enciphered.codeUnits);
  }

  /// Watch links from a listing/search page.
  static List<MediaItem> parseWatchLinks(String html) {
    final document = html_parser.parse(html);
    final items = <MediaItem>[];
    final seen = <String>{};

    for (final anchor in document.querySelectorAll('a[href*="/watch/"]')) {
      final href = anchor.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final uri = Uri.tryParse(href);
      if (uri == null) continue;
      final resolved = href.startsWith('http') ? href : '$baseUrl$href';
      if (!seen.add(resolved)) continue;

      // The `html` package has no closest(); walk up looking for the card.
      var card = anchor.parent ?? anchor;
      for (var depth = 0; depth < 4; depth++) {
        if (card.classes.contains('item')) break;
        final parent = card.parent;
        if (parent == null) break;
        card = parent;
      }
      final nameAnchor = card.querySelector('a.name') ?? anchor;
      var title = (nameAnchor.attributes['data-jp'] ?? '').trim();
      if (title.isEmpty) title = _clean(nameAnchor.text);
      if (title.isEmpty) {
        title = _clean(card.querySelector('img')?.attributes['alt'] ?? '');
      }
      if (title.isEmpty) {
        final slug = uri.pathSegments.where((s) => s.isNotEmpty).last;
        title = slug.replaceAll('-', ' ');
      }

      final image = card.querySelector('img')?.attributes['src'];
      items.add(
        MediaItem(
          id: resolved,
          title: title,
          mediaType: MediaType.series,
          posterUrl: image == null || image.isEmpty ? null : image,
          providerId: 'anikoto',
        ),
      );
    }
    return items;
  }

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Episode entries from an `/ajax/episode/list` payload.
  static List<AnikotoEpisode> parseEpisodeList(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! String) return const [];

    final document = html_parser.parse(result);
    final episodes = <AnikotoEpisode>[];
    final seen = <String>{};
    for (final anchor in document.querySelectorAll('a[data-ids]')) {
      final dataIds = anchor.attributes['data-ids'] ?? '';
      if (dataIds.isEmpty || !seen.add(dataIds)) continue;
      final number =
          int.tryParse(anchor.attributes['data-num'] ?? '') ??
          episodes.length + 1;
      episodes.add(AnikotoEpisode(number: number, dataIds: dataIds));
    }
    episodes.sort((a, b) => a.number.compareTo(b.number));
    return episodes;
  }

  /// `data-link-id` values from an `/ajax/server/list` payload.
  static List<AnikotoServer> parseServerList(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! String) return const [];

    final document = html_parser.parse(result);
    final servers = <AnikotoServer>[];
    final seen = <String>{};
    for (final element in document.querySelectorAll('[data-link-id]')) {
      final linkId = element.attributes['data-link-id'] ?? '';
      if (linkId.isEmpty || !seen.add(linkId)) continue;
      final name = _clean(element.text);
      servers.add(
        AnikotoServer(
          linkId: linkId,
          name: name.isEmpty ? 'Server' : name,
          isSub: _isSubServer(element),
        ),
      );
    }
    return servers;
  }

  static bool _isSubServer(dynamic element) {
    var node = element;
    for (var depth = 0; depth < 4 && node != null; depth++) {
      final type = node.attributes?['data-type'];
      if (type == 'sub') return true;
      if (type == 'dub') return false;
      node = node.parent;
    }
    return true;
  }

  /// Embed URL from an `/ajax/server` payload.
  static String? parseServerUrl(String body) {
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final result = decoded['result'];
    if (result is! Map) return null;
    final url = (result['url'] ?? '').toString().trim();
    return url.startsWith('http') ? url : null;
  }

  /// Embed id pairs from a MegaPlay player page.
  static ({String? dataId, String? realId}) parseEmbedIds(String html) {
    final dataId = RegExp(
      r'''data-id=["']?([^"'\s>]+)''',
    ).firstMatch(html)?.group(1);
    final realId = RegExp(
      r'''data-realid=["']?([^"'\s>]+)''',
    ).firstMatch(html)?.group(1);
    return (dataId: dataId, realId: realId);
  }

  /// AES-256-CBC (key zero-padded to 32 bytes) over a base64url payload.
  static Future<String?> decryptMegaPlay(String enc) async {
    var base64Url = enc.replaceAll('-', '+').replaceAll('_', '/');
    final pad = base64Url.length % 4;
    if (pad != 0) base64Url += '=' * (4 - pad);

    final keyBytes = Uint8List(32);
    final keySource = utf8.encode(megaKey);
    for (var i = 0; i < math.min(32, keySource.length); i++) {
      keyBytes[i] = keySource[i];
    }
    final iv = Uint8List(16);
    final ivSource = utf8.encode(megaIv);
    for (var i = 0; i < math.min(16, ivSource.length); i++) {
      iv[i] = ivSource[i];
    }

    try {
      final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
      final box = SecretBox(base64Decode(base64Url), nonce: iv, mac: Mac.empty);
      final clear = await algorithm.decrypt(
        box,
        secretKey: SecretKey(keyBytes),
      );
      return utf8.decode(clear, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  /// Playlist URL inside a decrypted `getSources` payload.
  static String? playlistFromPlain(String plain) {
    dynamic decoded;
    try {
      decoded = jsonDecode(plain);
    } catch (_) {
      return plain.startsWith('http') ? plain : null;
    }
    if (decoded is String) return decoded.startsWith('http') ? decoded : null;
    if (decoded is Map) {
      for (final key in const ['file', 'url', 'sources']) {
        final value = decoded[key];
        if (value is String && value.startsWith('http')) return value;
        if (value is Map) {
          final file = (value['file'] ?? '').toString();
          if (file.startsWith('http')) return file;
        }
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.startsWith('http')) return first;
          if (first is Map) {
            final file = (first['file'] ?? '').toString();
            if (file.startsWith('http')) return file;
          }
        }
      }
    }
    return null;
  }

  Future<http.Response?> _get(Uri uri, {String? referer}) async {
    try {
      return await _client
          .get(
            uri,
            headers: {
              'User-Agent': _ua,
              'Accept': 'text/html,application/json',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': referer ?? '$baseUrl/',
            },
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final response = await _get(searchUri(trimmed));
    if (response == null || response.statusCode != 200) return const [];
    return parseWatchLinks(response.body);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final response = await _get(homeUri(page: page));
    if (response == null || response.statusCode != 200) return const [];
    return parseWatchLinks(response.body);
  }

  Future<List<AnikotoEpisode>> _episodes(String animeId) async {
    final response = await _get(episodesUri(animeId));
    if (response == null || response.statusCode != 200) return const [];
    return parseEpisodeList(response.body);
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final page = await _get(Uri.parse(id));
    if (page == null || page.statusCode != 200) return null;
    final document = html_parser.parse(page.body);
    final animeId =
        document.querySelector('[data-id]')?.attributes['data-id'] ?? '';
    if (animeId.isEmpty) return null;

    final episodes = await _episodes(animeId);
    final title =
        _clean(
          document.querySelector('h1')?.text ??
              document.querySelector('.title')?.text ??
              '',
        ).isEmpty
        ? id.split('/').last
        : _clean(
            document.querySelector('h1')?.text ??
                document.querySelector('.title')?.text ??
                '',
          );
    final poster =
        document.querySelector('.poster img')?.attributes['src'] ??
        document.querySelector('img')?.attributes['src'];

    return MediaDetails(
      id: id,
      title: title,
      mediaType: MediaType.series,
      posterUrl: poster,
      seasons: [
        Season(
          seasonNumber: 1,
          episodeCount: episodes.length,
          episodes: [
            for (final episode in episodes)
              Episode(
                season: 1,
                episode: episode.number,
                title: 'Episode ${episode.number}',
              ),
          ],
        ),
      ],
    );
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
    // A subject from another add-on is an IMDb id, which these sites cannot
    // resolve: their content is keyed by their own ids. Look the title up
    // instead of spending a request on a page that cannot exist.
    var target = subjectId.trim();
    if (RegExp(r'^tt\d{5,}$').hasMatch(target)) {
      final query = title?.trim();
      if (query == null || query.isEmpty) return const [];
      final hits = await search(query);
      if (hits.isEmpty) return const [];
      target = hits.first.id;
    }
    final page = await _get(Uri.parse(target));
    if (page == null || page.statusCode != 200) return const [];
    final document = html_parser.parse(page.body);
    final animeId =
        document.querySelector('[data-id]')?.attributes['data-id'] ?? '';
    if (animeId.isEmpty) return const [];

    final episodes = await _episodes(animeId);
    if (episodes.isEmpty) return const [];
    final wanted = episode ?? 1;
    final match = episodes.firstWhere(
      (entry) => entry.number == wanted,
      orElse: () => episodes.first,
    );

    final serverList = await _get(
      serverListUri(match.dataIds),
      referer: subjectId,
    );
    if (serverList == null || serverList.statusCode != 200) return const [];
    final servers = parseServerList(
      serverList.body,
    ).where((server) => server.isSub).toList();
    if (servers.isEmpty) return const [];

    final results = <StreamSource>[];
    for (final server in servers.take(3)) {
      final embed = await _get(serverUri(server.linkId), referer: subjectId);
      if (embed == null || embed.statusCode != 200) continue;
      final embedUrl = parseServerUrl(embed.body);
      if (embedUrl == null) continue;

      final embedUri = Uri.tryParse(embedUrl);
      if (embedUri == null) continue;
      final host = embedUri.host;

      final embedPage = await _get(embedUri, referer: 'https://$host/');
      if (embedPage == null || embedPage.statusCode != 200) continue;
      final ids = parseEmbedIds(embedPage.body);
      final urlId = RegExp(
        r'/stream/[^/]+/([^/?#]+)',
      ).firstMatch(embedUri.path)?.group(1);

      final candidates = [?ids.dataId, ?ids.realId, ?urlId];
      String? playlist;
      for (final candidate in candidates) {
        for (final type in const ['sub', 'dub']) {
          final sources = await _get(
            sourcesUri(host, candidate, type),
            referer: embedUrl,
          );
          if (sources == null || sources.statusCode != 200) continue;
          dynamic decoded;
          try {
            decoded = jsonDecode(sources.body);
          } catch (_) {
            continue;
          }
          final enc = decoded is Map ? (decoded['enc'] ?? '').toString() : '';
          if (enc.isEmpty) continue;
          final plain = await decryptMegaPlay(enc);
          if (plain == null) continue;
          playlist = playlistFromPlain(plain);
          if (playlist != null) break;
        }
        if (playlist != null) break;
      }
      if (playlist == null) continue;

      results.add(
        StreamSource(
          quality: 'Auto',
          resolution: '',
          format: playlist.contains('.m3u8') ? 'HLS' : 'MP4',
          url: playlist,
          headers: {
            'User-Agent': _ua,
            'Referer': 'https://$host/',
            'Origin': 'https://$host',
          },
          server: server.name,
          providerId: 'anikoto',
          providerName: name,
        ),
      );
      if (results.isNotEmpty) break;
    }
    return results;
  }
}

/// One episode row from Anikoto's episode list.
class AnikotoEpisode {
  const AnikotoEpisode({required this.number, required this.dataIds});

  final int number;
  final String dataIds;
}

/// One stream server from Anikoto's server list.
class AnikotoServer {
  const AnikotoServer({
    required this.linkId,
    required this.name,
    required this.isSub,
  });

  final String linkId;
  final String name;
  final bool isSub;
}
