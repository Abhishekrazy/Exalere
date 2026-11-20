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
    // Back in the badge: m1.multimovies.courses answers again after the 504s
    // (checked 2026-11-20, 1 HLS source through the Cineverse proxy).
    'multimovies',
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
    'extraflix',
    'fourkhdhub',
    'vegamovies',
    // Movy's seed endpoint answers again after returning an empty seed
    // (checked 2026-11-20, 1 HLS source).
    'autoembed',
  };

  /// Providers that are listed in the store but currently resolve nothing.
  /// The store tags them so a user is not promised a stream that a dead mirror
  /// cannot deliver. Re-check with the headless self-test before removing an
  /// entry; add the date and what failed.
  static const Map<String, String> unavailable = {
    'animesalt':
        'Series and episode pages answer again (/series/one-piece is 416 KB with '
        'episode links) but the site exposes no catalogue and its search returns '
        '"No results found", so an add-on has nothing to list (checked 2026-11-20)',
  };

  static String? unavailableReason(String providerId) =>
      unavailable[providerId.toLowerCase()];

  static bool isVerified(String providerId) =>
      ids.contains(providerId.toLowerCase());
}
