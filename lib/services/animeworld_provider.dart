import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/provider_catalog_row.dart';
import '../models/stream_source.dart';
import '../services/extractors/zypter_extractor.dart';
import '../services/media_provider_plugin.dart';

/// AnimeWorld (watchanimeworld.one) — ported from Vega's `animeworld`.
///
/// Series pages print `data-post`/`data-season`, and WordPress handles the
/// episode list through `admin-ajax.php?action=action_select_season`. Episode
/// pages embed a Zypter/ZephyrFlick player, which [ZypterExtractor] resolves to
/// the signed HLS playlist.
class AnimeWorldProvider extends MediaProviderPlugin {
  AnimeWorldProvider({http.Client? client, this.providerNameOverride})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String? providerNameOverride;

  static const String baseUrl = 'https://watchanimeworld.one';

  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  @override
  String get id => 'animeworld';

  @override
  String get name => providerNameOverride ?? 'AnimeWorld';

  @override
  int get priority => 59;

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
    ProviderCatalogRow(id: 'latest', title: 'Latest on AnimeWorld'),
  ];

  static List<MediaItem> parseCards(String html) {
    final document = html_parser.parse(html);
    final items = <MediaItem>[];
    final seen = <String>{};
    const selectors = [
      '.anime-blog',
      'article',
      'li.post',
      '.swiper-slide li',
      '.latest-movies-series-swiper-slide li',
      'ul.post-lst li',
    ];

    for (final selector in selectors) {
      for (final card in document.querySelectorAll(selector)) {
        final anchor =
            card.querySelector('a.lnk-blk[href]') ??
            card.querySelector('.action-overlay a[href]') ??
            card.querySelector('a[href]');
        final href = anchor?.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final uri = Uri.tryParse(href);
        if (uri == null) continue;
        final resolved = href.startsWith('http') ? href : '$baseUrl$href';
        if (!seen.add(resolved)) continue;

        final img = card.querySelector('img');
        var title =
            (card.querySelector('h2.entry-title')?.text ??
                    card.querySelector('.entry-title')?.text ??
                    img?.attributes['alt'] ??
                    '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
        title = title.replaceFirst(RegExp(r'^Image\s+'), '').trim();
        if (title.isEmpty) continue;

        final image =
            img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
        items.add(
          MediaItem(
            id: resolved,
            title: title,
            mediaType:
                resolved.contains('/movies/') || resolved.contains('/movie/')
                ? MediaType.movie
                : MediaType.series,
            posterUrl: image.isEmpty
                ? null
                : (image.startsWith('http') ? image : '$baseUrl$image'),
            providerId: 'animeworld',
          ),
        );
      }
      if (items.isNotEmpty) break;
    }
    return items;
  }

  /// `data-post` id and the season numbers a series prints.
  static ({String? postId, List<int> seasons}) parseSeriesMeta(String html) {
    final document = html_parser.parse(html);
    final postAnchor = document.querySelector(
      '.choose-season .aa-cnt li a[data-post]',
    );
    var postId = postAnchor?.attributes['data-post'];
    postId ??= document
        .querySelector('article.post')
        ?.attributes['id']
        ?.replaceFirst('post-', '');
    if (postId != null && postId.isEmpty) postId = null;

    final seasons = <int>[];
    for (final anchor in document.querySelectorAll(
      '.choose-season .aa-cnt li a[data-season]',
    )) {
      final value = int.tryParse(anchor.attributes['data-season'] ?? '');
      if (value != null && value > 0 && !seasons.contains(value)) {
        seasons.add(value);
      }
    }
    seasons.sort();
    return (postId: postId, seasons: seasons);
  }

  /// AJAX episode HTML → (season, number, URL).
  static List<AnimeWorldEpisode> parseAjaxEpisodes(
    String html,
    String pageUrl,
  ) {
    final document = html_parser.parse(html);
    final episodes = <AnimeWorldEpisode>[];
    final seen = <String>{};

    for (final li in document.querySelectorAll('li')) {
      final article = li.querySelector('article.episodes');
      final card = article ?? li;
      final anchor = card.querySelector('a.lnk-blk') ?? card.querySelector('a');
      final href = anchor?.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final resolved = href.startsWith('http')
          ? href
          : Uri.parse(pageUrl).resolve(href).toString();
      if (!seen.add(resolved)) continue;

      final label = card.querySelector('.num-epi')?.text ?? '';
      final match = RegExp(r'(\d+)x(\d+)').firstMatch(label);
      if (match == null) continue;
      episodes.add(
        AnimeWorldEpisode(
          season: int.parse(match.group(1)!),
          number: int.parse(match.group(2)!),
          url: resolved,
        ),
      );
    }
    return episodes;
  }

  static List<String> parseIframes(String html) {
    final document = html_parser.parse(html);
    final urls = <String>[];
    for (final frame in document.querySelectorAll('iframe')) {
      final src = frame.attributes['data-src'] ?? frame.attributes['src'] ?? '';
      if (src.startsWith('http') && !urls.contains(src)) urls.add(src);
    }
    return urls;
  }

  Future<String?> _get(String url, {String? referer}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _ua,
              'Accept': 'text/html,application/xhtml+xml',
              'Referer': referer ?? '$baseUrl/',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return response.body;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _ajaxEpisodesHtml(
    String postId,
    int season, {
    required String referer,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/wp-admin/admin-ajax.php'),
            headers: {
              'User-Agent': _ua,
              'Accept': 'application/json, text/html',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Referer': referer,
              'X-Requested-With': 'XMLHttpRequest',
            },
            body: {
              'action': 'action_select_season',
              'post': postId,
              'season': '$season',
            },
          )
          .timeout(const Duration(seconds: 20));
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
    final html = await _get('$baseUrl/?s=${Uri.encodeQueryComponent(trimmed)}');
    if (html == null) return const [];
    return parseCards(html);
  }

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    final html = await _get(page > 1 ? '$baseUrl/page/$page/' : '$baseUrl/');
    if (html == null) return const [];
    return parseCards(html);
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    final html = await _get(id);
    if (html == null) return null;

    final meta = parseSeriesMeta(html);
    if (meta.postId == null) return null;

    final seasons = <Season>[];
    for (final number in meta.seasons.take(3)) {
      final ajax = await _ajaxEpisodesHtml(meta.postId!, number, referer: id);
      if (ajax == null) continue;
      final episodes = parseAjaxEpisodes(
        ajax,
        id,
      ).where((entry) => entry.season == number).toList();
      if (episodes.isEmpty) continue;
      seasons.add(
        Season(
          seasonNumber: number,
          episodeCount: episodes.length,
          episodes: [
            for (final episode in episodes)
              Episode(
                season: number,
                episode: episode.number,
                title: 'Episode ${episode.number}',
              ),
          ],
        ),
      );
    }
    if (seasons.isEmpty) return null;

    return MediaDetails(
      id: id,
      title: id.split('/').where((s) => s.isNotEmpty).last.replaceAll('-', ' '),
      mediaType: MediaType.series,
      seasons: seasons,
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
    final seriesPage = await _get(subjectId);
    if (seriesPage == null) return const [];

    final meta = parseSeriesMeta(seriesPage);
    if (meta.postId == null) return const [];

    final wantedSeason =
        season ?? meta.seasons.firstWhere((value) => true, orElse: () => 1);
    final targetSeason = meta.seasons.contains(wantedSeason)
        ? wantedSeason
        : (meta.seasons.isEmpty ? 1 : meta.seasons.first);

    final ajax = await _ajaxEpisodesHtml(
      meta.postId!,
      targetSeason,
      referer: subjectId,
    );
    if (ajax == null) return const [];

    final episodes = parseAjaxEpisodes(
      ajax,
      subjectId,
    ).where((entry) => entry.season == targetSeason).toList();
    if (episodes.isEmpty) return const [];

    final wantedEpisode = episode ?? 1;
    final match = episodes.firstWhere(
      (entry) => entry.number == wantedEpisode,
      orElse: () => episodes.first,
    );

    final episodePage = await _get(match.url);
    if (episodePage == null) return const [];

    final results = <StreamSource>[];
    for (final frame in parseIframes(episodePage)) {
      if (!ZypterExtractor.isZypterHost(frame)) continue;
      final playlist = await ZypterExtractor.resolveUrl(frame, client: _client);
      if (playlist == null) continue;
      final origin = Uri.tryParse(frame)?.origin ?? baseUrl;
      results.add(
        StreamSource(
          quality: 'Auto',
          resolution: '',
          format: playlist.contains('.m3u8') || playlist.contains('/hls/')
              ? 'HLS'
              : 'MP4',
          url: playlist,
          headers: {
            'User-Agent': ZypterExtractor.userAgent,
            'Referer': origin,
            'Origin': origin,
          },
          server: 'AnimeWorld',
          providerId: 'animeworld',
          providerName: name,
        ),
      );
    }
    return results;
  }
}

/// One episode row from AnimeWorld's season AJAX response.
class AnimeWorldEpisode {
  const AnimeWorldEpisode({
    required this.season,
    required this.number,
    required this.url,
  });

  final int season;
  final int number;
  final String url;
}
