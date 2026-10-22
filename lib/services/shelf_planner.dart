import '../models/media_item.dart';

/// Plans which titles each home shelf may show.
///
/// Home is built from several independent feeds — trending, popular, movies,
/// series, and one per genre. Those feeds are largely drawn from the same
/// catalogue, so without a planner the same film appears in four consecutive
/// rows and the page reads as if it has less content than it does.
///
/// The planner walks the shelves in display order and lets the first (most
/// prominent) shelf claim a title. Later shelves lose it. A shelf that would be
/// emptied by that rule reports `isEmpty`, so the caller can drop the row
/// entirely instead of showing a near-empty carousel.
class ShelfPlanner {
  ShelfPlanner({this.maxItemsPerShelf = 20});

  /// Upper bound for a single shelf, so one prolific feed cannot dominate.
  final int maxItemsPerShelf;

  /// Identity keys already shown.
  final Set<String> _claimed = {};

  int get claimedCount => _claimed.length;

  /// Identity for de-duplication.
  ///
  /// Title plus year is used rather than the provider id, because the same film
  /// arriving from two providers carries two different ids and would otherwise
  /// be shown twice. Normalisation keeps punctuation and spacing differences
  /// from defeating the match.
  static String identityOf(MediaItem item) {
    final title = _normalize(item.title);
    final year = item.year?.trim() ?? '';
    if (title.isEmpty) {
      // No usable title: fall back to whatever identifier exists.
      return 'id:${item.effectiveProviderId}:${item.id}';
    }
    return '$title|$year';
  }

  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        // Strip the kind of decorations providers bolt onto titles.
        .replaceAll(RegExp(r'\(\s*\d{4}\s*\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  /// Filters [items] down to titles not yet claimed by an earlier shelf.
  ///
  /// Ordering within the shelf is preserved, and the result is capped at
  /// [maxItemsPerShelf] after filtering — capping before filtering would return
  /// short rows whenever the first few titles were already claimed.
  List<MediaItem> next(List<MediaItem> items) {
    final result = <MediaItem>[];
    for (final item in items) {
      if (result.length >= maxItemsPerShelf) break;
      final identity = identityOf(item);
      if (!_claimed.add(identity)) continue;
      result.add(item);
    }
    return result;
  }

  /// True when [items] contains at least one title no earlier shelf claimed,
  /// without claiming anything. Useful for deciding whether to render a shelf at
  /// all before consuming its entries.
  bool hasFreshTitles(List<MediaItem> items) {
    for (final item in items) {
      if (!_claimed.contains(identityOf(item))) return true;
    }
    return false;
  }
}
