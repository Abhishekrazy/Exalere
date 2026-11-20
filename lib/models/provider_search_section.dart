import 'media_item.dart';

/// What a single provider has done with the current search query.
enum ProviderSearchStatus {
  /// The provider has been asked and has not answered yet.
  searching,

  /// The provider answered with at least one title.
  loaded,

  /// The provider answered, but knows nothing for this query.
  empty,

  /// The provider failed recently and is being skipped for a few minutes, so
  /// it was not asked this time. Distinct from [failed]: the app knows nothing
  /// happened, because it deliberately kept quiet.
  coolingDown,

  /// The provider errored or timed out. Distinct from [empty] on purpose: an
  /// empty answer is the provider working correctly and simply not having the
  /// title, while a failure means the app cannot say whether the title exists
  /// there — the two must never be shown as the same thing.
  failed,
}

/// One provider's slice of a global search.
///
/// Exalere used to merge every provider's answer into a single list behind one
/// spinner, which hid both where a title is available and which provider was
/// slow or broken. A search now carries one section per provider, so the UI can
/// show every provider at once and report each one's own outcome.
class ProviderSearchSection {
  const ProviderSearchSection({
    required this.providerId,
    required this.providerName,
    required this.priority,
    required this.status,
    this.items = const [],
    this.error,
    this.elapsed = Duration.zero,
  });

  /// Stable provider identifier, matching `MediaProviderPlugin.id`.
  final String providerId;

  /// Human-readable provider name shown in the UI.
  final String providerName;

  /// Provider priority, higher first. Keeps the merged list in a stable order
  /// no matter which provider answers first.
  final int priority;

  final ProviderSearchStatus status;

  /// Titles this provider returned, already filtered to safe content.
  final List<MediaItem> items;

  /// Reason the provider failed, when [status] is [ProviderSearchStatus.failed].
  final String? error;

  /// How long the provider took to answer.
  final Duration elapsed;

  bool get isSearching => status == ProviderSearchStatus.searching;

  bool get hasResults => items.isNotEmpty;

  bool get hasFailed => status == ProviderSearchStatus.failed;

  int get count => items.length;

  /// Short label for a provider filter chip: a count when there is something to
  /// count, otherwise the reason there is not.
  String get statusLabel {
    switch (status) {
      case ProviderSearchStatus.searching:
        return 'searching';
      case ProviderSearchStatus.loaded:
        return '$count';
      case ProviderSearchStatus.empty:
        return 'none';
      case ProviderSearchStatus.failed:
        return 'failed';
      case ProviderSearchStatus.coolingDown:
        return 'backing off';
    }
  }

  ProviderSearchSection copyWith({
    ProviderSearchStatus? status,
    List<MediaItem>? items,
    String? error,
    Duration? elapsed,
  }) {
    return ProviderSearchSection(
      providerId: providerId,
      providerName: providerName,
      priority: priority,
      status: status ?? this.status,
      items: items ?? this.items,
      error: error ?? this.error,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}
