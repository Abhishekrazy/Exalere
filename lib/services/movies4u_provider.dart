import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'extractors/html_grid_parser.dart';
import 'extractors/hubcloud_extractor.dart';
import 'extractors/stream_extractors.dart';
import 'media_provider_plugin.dart';
import 'scrapers/hubcloud_site_scraper.dart';

/// Native provider for Movies4U.
///
/// Two differences from the other HubCloud sites:
///  * **Listing cards are not `a[title]`** — the anchor carries an `aria-label`
///    and wraps the poster, so the listing parser is overridden.
///  * **The post page links to a gateway, not to HubCloud.** Each quality button
///    points at `mdrive.cloud/mdisk/<id>`, and that page is the one that lists
///    the actual mirrors (HubCloud, GDFlix, FastDL, vCloud, …). One extra hop is
///    therefore needed before the shared resolution tail applies.
class Movies4UProvider extends HubCloudSiteScraper {
  Movies4UProvider({super.client, super.baseUrl});

  static const String providerIdValue = 'movies4u';
  static const String fallbackBaseUrlValue = 'https://movies4u.cr';

  /// Hosts that publish only the mirror list for a single release.
  ///
  /// The same gateway pattern is used by the sibling sites (nexdrive, vglist),
  /// so the list is data rather than a hardcoded `if`.
  static const List<String> gatewayHosts = [
    'mdrive.cloud',
    'nexdrive.',
    'vglist.',
  ];

  @override
  String get domainKey => 'movies4u';

  @override
  String get providerId => providerIdValue;

  @override
  String get displayName => 'Movies4U';

  @override
  String get fallbackBaseUrl => fallbackBaseUrlValue;

  @override
  String catalogPath(int page) => '/page/$page/';

  /// WordPress search with pagination appended once past the first page.
  @override
  String searchPath(String encodedQuery, int page) =>
      page <= 1 ? '/?s=$encodedQuery' : '/page/$page/?s=$encodedQuery';

  @override
  List<MediaItem> parseListingHtml(String html) =>
      parseEntryCards(html, baseUrl: baseUrl, providerId: providerId);

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    bool? isSeries,
  }) async {
    final pageUrl = subjectId.startsWith('http')
        ? subjectId
        : '$baseUrl${subjectId.startsWith('/') ? '' : '/'}$subjectId';

    final html = await fetch(pageUrl);
    if (html == null) return [];

    final gateways = parseGatewayLinks(html);
    if (gateways.isEmpty) {
      // The site may switch back to posting HubCloud links directly; the shared
      // implementation handles that shape, so fall back instead of giving up.
      return super.getStreams(
        subjectId: subjectId,
        title: title,
        year: year,
        isSeries: isSeries,
      );
    }

    final results = <StreamSource>[];
    for (final gateway in gateways) {
      results.addAll(
        await resolveGateway(gateway.url, quality: gateway.quality),
      );
    }
    return dedupe(results);
  }

  /// Resolves one gateway page into playable sources.
  ///
  /// The gateway lists several hosts for the same release. HubCloud links are
  /// followed to their CDN file, which is what actually streams; when none are
  /// present the page's own direct hosts are used.
  Future<List<StreamSource>> resolveGateway(
    String url, {
    required String quality,
  }) async {
    final html = await fetch(url);
    if (html == null) return [];

    final label = StreamExtractors.guessQuality(quality);
    final results = <StreamSource>[];

    for (final drive in HubCloudExtractor.parseDriveLinks(html)) {
      final page = await fetch(drive.url);
      if (page == null) continue;
      results.addAll(await streamsFromHubCloudPage(page, quality: label));
    }

    if (results.isEmpty) {
      results.addAll(
        streamsFromServers(
          HubCloudExtractor.sortServers(HubCloudExtractor.parseServers(html)),
          quality: label,
        ),
      );
    }
    return results;
  }

  /// True when [url] points at a mirror-listing page rather than a real host.
  static bool isGatewayPage(String url) {
    final lower = url.toLowerCase();
    return gatewayHosts.any(lower.contains);
  }

  /// Forwarding static so callers and tests keep a site-scoped entry point.
  static bool isShortlinkGated(String url) =>
      HubCloudSiteScraper.isShortlinkGated(url);

  /// Parses the `.entry-card` grid.
  ///
  /// The card anchor carries the title in `aria-label` and the poster in a child
  /// `<img>`, and neither the attribute order nor the container class is
  /// guaranteed — so the anchor is located by its poster-container class and the
  /// attributes are read from the tag itself.
  static List<MediaItem> parseEntryCards(
    String html, {
    required String baseUrl,
    required String providerId,
  }) {
    final items = <MediaItem>[];
    final seen = <String>{};

    final cardPattern = RegExp(
      r'''<a\s+[^>]*(?:ct-media-container|entry-card)[^>]*>''',
      caseSensitive: false,
    );
    final attrPattern = RegExp(
      r'''(\w[\w-]*)=["']([^"']*)["']''',
      caseSensitive: false,
    );
    final imgPattern = RegExp(
      r'''<img\s+[^>]*src=["']([^"']+)["']''',
      caseSensitive: false,
    );

    for (final card in cardPattern.allMatches(html)) {
      final tag = card.group(0) ?? '';
      String? href;
      String? label;
      for (final attr in attrPattern.allMatches(tag)) {
        final name = attr.group(1)!.toLowerCase();
        if (name == 'href') href = attr.group(2);
        if (name == 'aria-label') label = attr.group(2);
      }
      if (href == null || href.isEmpty) continue;
      if (href.startsWith('#') || href.startsWith('javascript:')) continue;

      final windowEnd = card.end + 600 < html.length
          ? card.end + 600
          : html.length;
      final inner = html.substring(card.end, windowEnd);
      final image = imgPattern.firstMatch(inner)?.group(1);

      // Without an aria-label fall back to the poster's alt text, and only skip
      // the card when neither exists.
      final rawTitle = (label ?? '').trim().isNotEmpty
          ? label!.trim()
          : (RegExp(r'''alt=["']([^"']+)["']''').firstMatch(inner)?.group(1) ??
                    '')
                .trim();
      if (rawTitle.isEmpty) continue;

      final absolute = href.startsWith('http')
          ? href
          : '$baseUrl${href.startsWith('/') ? '' : '/'}$href';
      if (!seen.add(absolute)) continue;

      items.add(
        MediaItem(
          id: absolute,
          title: cleanTitle(rawTitle),
          mediaType: HtmlGridParser.mediaTypeFor(rawTitle),
          year: HtmlGridParser.yearFrom(rawTitle),
          posterUrl: image,
          provider: ProviderType.plugins,
          providerId: providerId,
        ),
      );
    }
    return items;
  }

  /// Strips the release tags these titles carry so the card reads as a title.
  static String cleanTitle(String raw) {
    var title = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Marketing prefixes and suffixes: "Download … Full Movie …".
    title = title.replaceAll(
      RegExp(r'^(download|watch)\s+', caseSensitive: false),
      '',
    );
    final cut = RegExp(
      r'\s+(480p|720p|1080p|2160p|4k|web[- ]?dl|hdtc|hq|predvd|dual audio|'
      r'hindi|english|tamil|telugu|eps?|season)\b',
      caseSensitive: false,
    ).firstMatch(title);
    if (cut != null && cut.start > 0) {
      title = title.substring(0, cut.start);
    }
    return title.trim();
  }

  /// Links on a post page that point at a gateway, with the quality stated in
  /// the heading above each button.
  static List<HubCloudQualityLink> parseGatewayLinks(String html) {
    final links = <HubCloudQualityLink>[];
    final seen = <String>{};

    final anchorPattern = RegExp(
      r'''<a\s+[^>]*href=["'](https?://[^"']+)["']''',
      caseSensitive: false,
    );

    for (final match in anchorPattern.allMatches(html)) {
      final url = match.group(1)!;
      if (!isGatewayPage(url)) continue;
      if (!seen.add(url)) continue;

      // The quality lives in the heading just above the button.
      final start = match.start - 300 < 0 ? 0 : match.start - 300;
      final context = html.substring(start, match.start);
      links.add(
        HubCloudQualityLink(
          quality: StreamExtractors.guessQuality(context),
          url: url,
        ),
      );
    }

    links.sort(
      (a, b) => HubCloudExtractor.qualityRank(
        b.quality,
      ).compareTo(HubCloudExtractor.qualityRank(a.quality)),
    );
    return links;
  }
}

/// Registry adapter so the scraper behaves like any other provider.
class Movies4UPlugin extends MediaProviderPlugin {
  Movies4UPlugin({Movies4UProvider? provider})
    : _provider = provider ?? Movies4UProvider();

  final Movies4UProvider _provider;

  @override
  String get id => Movies4UProvider.providerIdValue;

  @override
  String get name => 'Movies4U';

  @override
  int get priority => 61;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => false;

  @override
  bool get supportsStreams => true;

  /// Resolves a post page straight to a stream; there is no metadata endpoint.
  @override
  bool get supportsMetadata => false;

  @override
  Future<List<MediaItem>> search(String query) => _provider.search(query);

  @override
  Future<List<MediaItem>> getCatalogFeed({String? category, int page = 1}) =>
      _provider.getCatalog(page: page);

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    int? season,
    int? episode,
    String? imdbId,
    String? originProviderId,
    bool? isSeries,
  }) => _provider.getStreams(
    subjectId: subjectId,
    title: title,
    year: year,
    isSeries: isSeries,
  );
}
