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
    'animesalt',
    'animeworld',
    'animesub',
    'anikoto',
    'castle',
  };

  static bool isVerified(String providerId) =>
      ids.contains(providerId.toLowerCase());
}
