import 'media_item.dart';

/// A Home shelf filled from one provider's own catalogue.
///
/// Vega's home screen is built this way: every catalogue the active provider
/// declares becomes one row, fetched in parallel, and a row that fails is
/// dropped without blanking the page. Keeping the provider and the row identity
/// lets Home say where the titles come from and lets a failing provider be
/// reported instead of silently disappearing.
class HomeProviderRow {
  const HomeProviderRow({
    required this.providerId,
    required this.providerName,
    required this.rowId,
    required this.title,
    required this.items,
  });

  /// Provider that served this row.
  final String providerId;

  /// Human-readable provider name.
  final String providerName;

  /// The provider's own row identifier.
  final String rowId;

  /// Row title as declared by the provider.
  final String title;

  final List<MediaItem> items;

  /// Header text used on Home: the row title plus the provider it came from,
  /// because several providers now contribute rows side by side.
  String get displayTitle => '$title · $providerName';

  /// Prefix for this row's hero tags and focus ids.
  String get shelfPrefix => 'provider_${providerId}_$rowId';
}
