import '../../models/media_item.dart';

/// One card scraped from a listing grid.
class GridCard {
  const GridCard({required this.title, required this.url, this.imageUrl});

  final String title;
  final String url;
  final String? imageUrl;
}

/// Extracts poster cards from the listing grids these sites use.
///
/// The sites differ in markup — some wrap cards in `<article>`, others in
/// `.layout-masonry` divs — but they agree on the signature that matters: a card
/// is an `<a>` carrying both a `title` and an `href`, followed closely by its
/// `<img>`. Keying off that instead of a container selector means one parser
/// works across sites and is immune to container renaming or nesting changes,
/// which is the usual reason a scraper breaks.
class HtmlGridParser {
  const HtmlGridParser._();

  /// Anchors that carry a title attribute: the card link on every one of these
  /// listing themes.
  static final RegExp _titleAnchor = RegExp(
    r'''<a\s+([^>]*)>''',
    caseSensitive: false,
  );

  static final RegExp _attr = RegExp(
    r'''(\w[\w-]*)=["']([^"']*)["']''',
    caseSensitive: false,
  );

  static final RegExp _img = RegExp(
    r'''<img\s+[^>]*src=["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// How far past an anchor to look for its poster.
  static const int _imageLookahead = 600;

  /// Parses cards from [html], resolving relative links against [baseUrl].
  ///
  /// Cards without a title or without a link are skipped: they render as
  /// unusable entries, and a blank poster row is worse than a shorter one.
  static List<GridCard> parse(String html, {required String baseUrl}) {
    final cards = <GridCard>[];
    final seen = <String>{};

    for (final match in _titleAnchor.allMatches(html)) {
      final attributes = match.group(1) ?? '';
      if (!attributes.toLowerCase().contains('title=')) continue;

      String? title;
      String? href;
      for (final attr in _attr.allMatches(attributes)) {
        final name = attr.group(1)!.toLowerCase();
        final value = attr.group(2) ?? '';
        if (name == 'title') title = value;
        if (name == 'href') href = value;
      }

      if (title == null || title.trim().isEmpty) continue;
      if (href == null || href.trim().isEmpty) continue;
      // Anchors pointing at nothing are navigation chrome, not cards.
      if (href.startsWith('#') || href.startsWith('javascript:')) continue;

      final absolute = _absolute(href, baseUrl);
      if (!seen.add(absolute)) continue;

      final lookaheadEnd = match.end + _imageLookahead < html.length
          ? match.end + _imageLookahead
          : html.length;
      final image = _img
          .firstMatch(html.substring(match.end, lookaheadEnd))
          ?.group(1);

      cards.add(
        GridCard(
          title: title
              .replaceAll(RegExp('Download', caseSensitive: false), '')
              .trim(),
          url: absolute,
          imageUrl: image,
        ),
      );
    }

    return cards;
  }

  /// Converts parsed cards into catalogue items for [providerId].
  static List<MediaItem> toMediaItems(
    List<GridCard> cards, {
    required String providerId,
  }) {
    return [
      for (final card in cards)
        MediaItem(
          id: card.url,
          title: card.title,
          mediaType: mediaTypeFor(card.title),
          year: yearFrom(card.title),
          posterUrl: card.imageUrl,
          provider: ProviderType.plugins,
          providerId: providerId,
        ),
    ];
  }

  /// A season pack is a series; everything else is a movie.
  static MediaType mediaTypeFor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('season') ||
        lower.contains('series') ||
        RegExp(r'\bs\d{1,2}\b').hasMatch(lower)) {
      return MediaType.series;
    }
    return MediaType.movie;
  }

  /// Extracts a `(YYYY)` year from a title, or null.
  static String? yearFrom(String title) {
    final match = RegExp(r'\((19|20)\d{2}\)').firstMatch(title);
    if (match == null) return null;
    return match.group(0)!.replaceAll(RegExp(r'[()]'), '');
  }

  static String _absolute(String href, String baseUrl) {
    final trimmed = href.trim();
    if (trimmed.startsWith('http')) return trimmed;
    if (baseUrl.isEmpty) return trimmed;
    return '$baseUrl${trimmed.startsWith('/') ? '' : '/'}$trimmed';
  }
}
