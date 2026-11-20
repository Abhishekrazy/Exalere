/// Remembers which providers just failed, so the app stops asking a site that
/// is plainly not answering.
///
/// A dead or blocked provider used to cost its full timeout on every Home load
/// and every search. Backing off for a few minutes costs nothing the user can
/// see (the add-on is listed as cooling down instead of empty) and stops us
/// hammering a site that is already refusing us.
class ProviderCooldown {
  ProviderCooldown({
    this.base = const Duration(minutes: 2),
    this.max = const Duration(minutes: 20),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// First failure cools a provider for this long.
  final Duration base;

  /// The ceiling for repeated failures.
  final Duration max;

  final DateTime Function() _clock;
  final Map<String, _CooldownEntry> _entries = {};

  /// Whether [providerId] is inside its backoff window right now.
  bool isCooling(String providerId) {
    final entry = _entries[providerId];
    if (entry == null) return false;
    if (_clock().isBefore(entry.until)) return true;
    // Expired: forget it so the next failure starts from the base again.
    _entries.remove(providerId);
    return false;
  }

  /// How long is left of the window, for a UI that wants to say so.
  Duration remaining(String providerId) {
    final entry = _entries[providerId];
    if (entry == null) return Duration.zero;
    final left = entry.until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// A working provider clears any previous failures.
  void recordSuccess(String providerId) => _entries.remove(providerId);

  /// A failed provider backs off further each time, up to [max].
  void recordFailure(String providerId) {
    final previous = _entries[providerId];
    final failures = (previous?.failures ?? 0) + 1;
    var window = base;
    for (var i = 1; i < failures && window < max; i++) {
      window *= 2;
    }
    if (window > max) window = max;
    _entries[providerId] = _CooldownEntry(
      failures: failures,
      until: _clock().add(window),
    );
  }

  void clear() => _entries.clear();

  /// Snapshot for diagnostics: provider id -> failures.
  Map<String, int> get failures => {
    for (final entry in _entries.entries) entry.key: entry.value.failures,
  };
}

class _CooldownEntry {
  const _CooldownEntry({required this.failures, required this.until});

  final int failures;
  final DateTime until;
}
