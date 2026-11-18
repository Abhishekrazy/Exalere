import 'media_item.dart';

/// One discovery row a provider can fill on Home.
///
/// This is how a provider states what it wants to show, the way a Vega provider
/// declares its `catalog` entries: the app asks for the row and the provider
/// returns titles, instead of the app inventing a fixed list of shelves that no
/// provider owns.
///
/// Independent of `MediaProviderPlugin.supportsCatalogFeeds`, which decides
/// whether the provider may *be* the browse catalogue; a row is a narrower
/// claim — "this one feed of mine works".
class ProviderCatalogRow {
  const ProviderCatalogRow({
    required this.id,
    required this.title,
    this.category,
    this.mediaType = MediaType.movie,
  });

  /// Stable row identifier, unique within its provider.
  final String id;

  /// Row title shown on Home, e.g. "Latest releases".
  final String title;

  /// Category / filter handed to the provider's catalog feed. `null` means the
  /// provider's default listing.
  final String? category;

  /// What the row predominantly contains. Used for the row icon and for
  /// de-duplication heuristics, never to hide titles.
  final MediaType mediaType;
}
