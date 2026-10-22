/// Helpers for choosing an image size that matches how it will be displayed.
///
/// TMDB serves the same artwork at several fixed widths. Providers and cached
/// JSON hand back whatever size they stored — commonly `/w500/` or `/w342/` —
/// which looks soft when a detail page paints it into a large hero slot. Asking
/// for a bigger source is free (TMDB resizes server-side), so this upgrades the
/// request instead of shipping a blurry poster.
class ImageUrls {
  const ImageUrls._();

  /// Widths TMDB will serve. Anything else is not a valid replacement.
  static const Set<int> tmdbWidths = {92, 154, 185, 300, 342, 500, 780, 1280};

  /// Sensible source width for a detail-page poster or backdrop.
  static const int detailWidth = 780;

  /// Pattern for a TMDB size segment, e.g. `/t/p/w500/` or `/t/p/original/`.
  static final RegExp _sizeSegment = RegExp(r'/t/p/(w\d+|original)/');

  /// Returns [url] upgraded to at least [minWidth] on TMDB, or unchanged.
  ///
  /// Non-TMDB URLs are returned untouched, `original` is left alone (already the
  /// largest), and an already-large enough size is not rewritten — so callers can
  /// apply this unconditionally without causing needless re-downloads.
  static String? upgrade(String? url, {int minWidth = detailWidth}) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('image.tmdb.org/t/p/')) return trimmed;

    final match = _sizeSegment.firstMatch(trimmed);
    if (match == null) return trimmed;

    final segment = match.group(1)!;
    if (segment == 'original') return trimmed;

    final currentWidth = int.tryParse(segment.substring(1));
    if (currentWidth != null && currentWidth >= minWidth) return trimmed;

    // Only rewrite to a width TMDB actually serves.
    final target = _resolveTarget(minWidth);
    return trimmed.replaceRange(match.start, match.end, '/t/p/w$target/');
  }

  /// Picks the smallest served width that satisfies [minWidth].
  static int _resolveTarget(int minWidth) {
    final candidates = tmdbWidths.toList()..sort();
    for (final width in candidates) {
      if (width >= minWidth) return width;
    }
    return candidates.last;
  }

  /// True when [url] points at TMDB artwork.
  static bool isTmdb(String? url) =>
      url != null && url.contains('image.tmdb.org/t/p/');
}
