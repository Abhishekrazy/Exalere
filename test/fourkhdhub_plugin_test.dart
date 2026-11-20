import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/plugins/fourkhdhub/fourkhdhub_plugin.dart';

/// Callers pass `season`/`episode` optimistically; the engine treats any season
/// as "series" and would look for an episode listing on a movie post. The
/// adapter has to decide from the post, and that decision is what these tests
/// pin (the live self-test caught this: 10 streams direct, 0 through the plugin).
void main() {
  group('4KHDHub series detection', () {
    test('a movie post is not a series', () {
      expect(
        FourKHdHubPlugin.seriesFrom(
          title: 'Avengers Endgame: Encore (2026)',
          subjectId: '/avengers-endgame-encore-movie-8563/',
        ),
        isFalse,
      );
    });

    test('a season or episode post is', () {
      expect(
        FourKHdHubPlugin.seriesFrom(
          title: 'The Rings of Power Season 3',
          subjectId: '/the-rings-of-power-season-3/',
        ),
        isTrue,
      );
      expect(
        FourKHdHubPlugin.seriesFrom(
          title: 'Breaking Bad Episode 5',
          subjectId: '/breaking-bad/',
        ),
        isTrue,
      );
    });

    test('an explicit hint wins', () {
      expect(
        FourKHdHubPlugin.seriesFrom(
          title: 'Season 1',
          subjectId: '/season-1/',
          isSeries: false,
        ),
        isFalse,
      );
    });
  });

  test('IMDb ids are recognised so they are never used as a path', () {
    // Passing one straight through built `https://4khdhub.onett1160419`, a host
    // that cannot exist — and the request was spent on every resolve.
    expect(FourKHdHubPlugin.isImdbId('tt1160419'), isTrue);
    expect(FourKHdHubPlugin.isImdbId(' tt0388629 '), isTrue);
    expect(
      FourKHdHubPlugin.isImdbId('/avengers-endgame-encore-movie-8563/'),
      isFalse,
    );
    expect(FourKHdHubPlugin.isImdbId(''), isFalse);
    expect(FourKHdHubPlugin.isImdbId('tt12'), isFalse);
  });
}
