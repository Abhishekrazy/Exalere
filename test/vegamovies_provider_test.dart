import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/vegamovies_provider.dart';

/// A trimmed copy of a real `/wp-json/wp/v2/posts` payload.
const _payload = '''
[
  {
    "id": 265134,
    "link": "https://vegamovies.latino/download-marrow-2026-hindi-org-english-480p-720p-1080p-web-dl/",
    "title": {"rendered": "Download Marrow (2026) Dual Audio {Hindi-English} WEB-DL 480p [350MB]"},
    "fifu_image_url": "https://image.tmdb.org/t/p/w500/marrow.jpg",
    "content": {"rendered": "<a href=\\"https://nexdrive.fit/abc\\">1080p</a>"}
  },
  {
    "id": 265135,
    "link": "https://vegamovies.latino/download-the-rings-of-power-season-3/",
    "title": {"rendered": "Download The Rings of Power (2026) Season 3 Hindi Dubbed"},
    "yoast_head_json": {"og_image": [{"url": "https://vegamovies.latino/og/rings.jpg"}]}
  },
  {
    "id": 265136,
    "link": "",
    "title": {"rendered": "No link, must be skipped"}
  }
]
''';

void main() {
  group('VegaMovies listing JSON', () {
    test('turns posts into cards and drops entries without a link', () {
      final items = VegaMoviesProvider.parseListingJson(_payload);

      expect(items, hasLength(2));
      expect(items.first.id, startsWith('https://vegamovies.latino/download-'));
      expect(items.first.title, startsWith('Marrow (2026)'));
      expect(items.first.title, isNot(contains('Download ')));
      expect(items.first.year, '2026');
      expect(items.first.mediaType, MediaType.movie);
    });

    test('reads the poster from fifu, then from Yoast', () {
      final items = VegaMoviesProvider.parseListingJson(_payload);

      expect(items.first.posterUrl, contains('marrow.jpg'));
      expect(items[1].posterUrl, endsWith('rings.jpg'));
    });

    test('recognises a season as a series', () {
      final items = VegaMoviesProvider.parseListingJson(_payload);

      expect(items[1].mediaType, MediaType.series);
      expect(items[1].title, contains('Season 3'));
    });

    test('malformed or empty payloads yield nothing instead of throwing', () {
      expect(VegaMoviesProvider.parseListingJson(null), isEmpty);
      expect(VegaMoviesProvider.parseListingJson(''), isEmpty);
      expect(VegaMoviesProvider.parseListingJson('not json'), isEmpty);
      expect(VegaMoviesProvider.parseListingJson('{"oops": true}'), isEmpty);
      expect(VegaMoviesProvider.parseListingJson('[]'), isEmpty);
    });

    test('cleans markup and entities out of a title', () {
      expect(
        VegaMoviesProvider.cleanTitle(
          '<h1>Download <b>Dune</b> &#039;Part Two&#039; (2024)</h1>',
        ),
        // Entities are dropped rather than decoded: the title reads fine and
        // no apostrophe ends up in a Dart string literal.
        'Dune Part Two (2024)',
      );
      expect(VegaMoviesProvider.yearFrom('Dune (2024)'), '2024');
      expect(VegaMoviesProvider.yearFrom('No year here'), isNull);
    });
  });

  test('a catalogue that answers empty once is retried', () async {
    var calls = 0;
    final provider = VegaMoviesProvider(
      baseUrl: 'https://vegamovies.test',
      client: MockClient((request) async {
        calls++;
        // First answer mimics the empty-body case, second serves the payload.
        return http.Response(calls == 1 ? '' : _payload, 200);
      }),
    );

    final items = await provider.getCatalog();

    expect(calls, 2);
    expect(items, hasLength(2));
  });
}
