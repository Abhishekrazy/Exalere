import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/kisskh_provider.dart';

void main() {
  group('KissKh key generation', () {
    // Vectors produced by Vega's original TypeScript implementation.
    test('matches the browser key for episode 145133', () async {
      final key = await KissKhProvider.generateKey(episodeId: 145133);
      expect(
        key,
        'E3F33BA8D34E81C85A26F25E70304C934CC59DA4F37B0E3917CC5E0A9F0E6943'
        '684D867750612A42D0C3CF8843423C3632D5E1B49B9DB821C489AD6AF9B3B43E'
        'D0736B988A6CA1D78A2EA2EADFBCBA6C74D47D9C511FFFE7BB549FFA2DE95169'
        '94C38037A74820ACCA4568465F1653FF64A1E047FDD784C6FFCF3C40422254BE',
      );
    });

    test('matches the browser key for episode 42', () async {
      final key = await KissKhProvider.generateKey(episodeId: 42);
      expect(
        key,
        '69340C9AC35531C29E580BB5EDDB2D501B59F8FA728A7BFDD81E27BDA7FEACAB'
        'D46765D6A9CEA1E904334C8E7C9E97AC2A488A15E27F726075F328B9CC124AF0'
        'B1A55C3B108FBD93419C410CEEBCF1E848CCFD7D02090F451D8D7498DB2B681D'
        '67B2B3C3B7C9F17BCE7C6CFEFDC955A4AE7903A9995461125AE64658FA3538D1',
      );
    });

    test('stringHash is the JS signed 32-bit hash', () {
      expect(KissKhProvider.stringHash(''), '0');
      expect(KissKhProvider.stringHash('a'), '97');
      expect(KissKhProvider.stringHash('kisskh'), '-1131138533');
    });
  });

  group('KissKh parsing', () {
    test('maps search results to series items', () {
      const body = '''
        [{"id":8268,"title":"My Demon","thumbnail":"https://img/x.jpg"},
         {"id":9001,"title":"Another Drama","thumbnail":""}]
      ''';
      final items = KissKhProvider.parseShows(body);

      expect(items, hasLength(2));
      expect(items.first.id, '8268');
      expect(items.first.title, 'My Demon');
      expect(items.first.posterUrl, 'https://img/x.jpg');
      expect(items.last.posterUrl, isNull);
    });

    test('reads the paged drama list payload', () {
      const body = '''
        {"page":1,"pageSize":10,"totalCount":13260,
         "data":[{"id":8268,"title":"My Demon","thumbnail":"https://img/x.jpg"}]}
      ''';
      final items = KissKhProvider.parseShows(body);

      expect(items, hasLength(1));
      expect(items.single.id, '8268');
      expect(items.single.title, 'My Demon');
    });
    test('reads episode ids and numbers from a drama payload', () {
      const body = '''
        {"title":"My Demon","episodes":[
          {"id":145118,"number":1},
          {"id":145133,"number":16}
        ]}
      ''';
      final episodes = KissKhProvider.parseEpisodes(body);

      expect(episodes, hasLength(2));
      expect(episodes.first.id, 145118);
      expect(episodes.last.number, 16);
    });

    test('reads the HLS url from a stream payload', () {
      const body = '''
        {"Video":"https://hls.cdnvideo11.shop/hls07/8268/Ep16_index.m3u8",
         "Type":1}
      ''';
      expect(
        KissKhProvider.parseVideoUrl(body),
        'https://hls.cdnvideo11.shop/hls07/8268/Ep16_index.m3u8',
      );
      expect(KissKhProvider.parseVideoUrl('{"Video":""}'), isNull);
      expect(KissKhProvider.parseVideoUrl('not json'), isNull);
    });
  });
}
