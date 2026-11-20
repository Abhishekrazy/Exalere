/// Providers whose end-to-end stream resolution has been verified live.
///
/// The bar is deliberately mechanical: `test/live_vega_probe_test.dart` must
/// list the provider **and** resolve at least one playable source from it
/// (`flutter test test/live_vega_probe_test.dart --dart-define=LIVE=true`).
/// Anything that cannot resolve a stream stays out of this list and out of the
/// store, per the porting rule in AGENTS.md.
///
/// Adding an id here has consequences that `test/verified_providers_test.dart`
/// enforces: a built-in manifest, a community-catalog entry, a Pages docs folder
/// with icon, an entry in docs/plugins.json and a createPlugin branch.
library;

class VerifiedProviders {
  VerifiedProviders._();

  /// Verified provider ids, in the order they were ported.
  static const Set<String> ids = {
    // Wave 1 — HubCloud-family config ports.
    'zeefliz',
    // 'multimovies' is out of the badge while every mirror answers 504
    // (2026-11-20). The store entry stays; the badge returns with the site.
    // Wave 2 — mirror/API engines.
    'internetarchive',
    'torrentio',
    'kisskh',
    // Wave 3 — anime.
    'kickassanime',
    'animestream',
    'animeworld',
    'animesub',
    'anikoto',
    'castle',
    'gokuhd',
    'fourkhdhub',
    'vegamovies',
  };

  /// Providers that are listed in the store but currently resolve nothing.
  /// The store tags them so a user is not promised a stream that a dead mirror
  /// cannot deliver. Re-check with the headless self-test before removing an
  /// entry; add the date and what failed.
  static const Map<String, String> unavailable = {
    // Every mirror (m1/m2/multimovies.courses) answers 504 since 2026-11-20.
    'multimovies': 'All mirrors answer 504 (checked 2026-11-20)',
    'animesalt':
        'Site content removed: search answers "No results found" for every '
        'query and its catalogue parses 0 items (checked 2026-11-20)',
    'autoembed':
        'Movy seed handshake rejects every request '
        '(STREAMCRYPTO_SEED_INVALID, checked 2026-11-20)',
  };

  static String? unavailableReason(String providerId) =>
      unavailable[providerId.toLowerCase()];

  static bool isVerified(String providerId) =>
      ids.contains(providerId.toLowerCase());
}
