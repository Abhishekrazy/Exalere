import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/scrapers/vega_site_scraper.dart';

/// These sites key their posts by URL. When a title comes from another add-on or
/// from TMDB, the id is an IMDb id or a bare number, and fetching it as a page
/// only spends a request on a URL that cannot exist — the same defect 4KHDHub
/// had. The decision is pure, so it is tested without the network.
void main() {
  group('foreign subject ids', () {
    test('an IMDb id or bare number needs a title lookup', () {
      expect(VegaSitePlugin.subjectNeedsLookup('tt1160419'), isTrue);
      expect(VegaSitePlugin.subjectNeedsLookup('438631'), isTrue);
      expect(VegaSitePlugin.subjectNeedsLookup('  tt0388629 '), isTrue);
      expect(VegaSitePlugin.subjectNeedsLookup(''), isTrue);
    });

    test('a post URL or absolute path is used as is', () {
      expect(
        VegaSitePlugin.subjectNeedsLookup(
          'https://vegamovies.latino/download-marrow-2026/',
        ),
        isFalse,
      );
      expect(
        VegaSitePlugin.subjectNeedsLookup('/naruto-shippuden-season-3/'),
        isFalse,
      );
      expect(
        VegaSitePlugin.subjectNeedsLookup('https://gokuhd.nl/a-post/'),
        isFalse,
      );
    });
  });
}
