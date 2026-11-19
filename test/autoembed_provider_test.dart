import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/autoembed_provider.dart';
import 'package:exalere/services/extractors/movy_extractor.dart';

void main() {
  group('Movy keystream', () {
    test('is deterministic for a seed and media id', () {
      final first = MovyExtractor.keyStream('59837630.LqiqJsV2', '693134', 64);
      final second = MovyExtractor.keyStream('59837630.LqiqJsV2', '693134', 64);
      expect(first, second);
      expect(first, hasLength(64));
      expect(first.any((byte) => byte != 0), isTrue);
    });

    test('different seeds produce different streams', () {
      final a = MovyExtractor.keyStream('seed-a', '1', 32);
      final b = MovyExtractor.keyStream('seed-b', '1', 32);
      expect(a, isNot(equals(b)));
    });
  });

  group('Movy payload decoding', () {
    /// Encrypts like the service does so the decoder can be checked in isolation.
    String encrypt(String json, String seed, String mediaId) {
      final body = [109, 118, 109, 49, ...utf8.encode(json)];
      final stream = MovyExtractor.keyStream(seed, mediaId, body.length);
      final cipher = Uint8List(body.length);
      for (var i = 0; i < body.length; i++) {
        cipher[i] = body[i] ^ stream[i];
      }
      return base64Url.encode(cipher).replaceAll('=', '');
    }

    test('round-trips a sources payload', () {
      const json = '{"playlist":"https://cdn/x/master.m3u8","subtitles":[]}';
      final cipher = encrypt(json, 'seed-1', '693134');

      expect(MovyExtractor.decodePayload(cipher, 'seed-1', '693134'), json);
    });

    test('rejects a payload decoded with the wrong seed', () {
      const json = '{"playlist":"https://cdn/x/master.m3u8"}';
      final cipher = encrypt(json, 'seed-1', '693134');

      expect(MovyExtractor.decodePayload(cipher, 'seed-2', '693134'), isNull);
      expect(MovyExtractor.decodePayload('not base64 !!!', 's', '1'), isNull);
    });
  });

  group('AutoEmbed Cinemeta parsing', () {
    test('maps catalogue metas with their type', () {
      const body = '''
        {"metas":[
          {"id":"tt1160419","imdb_id":"tt1160419","type":"movie","name":"Dune",
           "releaseInfo":"2021","poster":"https://images.metahub.space/p.jpg"},
          {"id":"tt0944947","type":"series","name":"Game of Thrones"}
        ]}
      ''';
      final items = AutoEmbedProvider.parseCatalog(body);

      expect(items, hasLength(2));
      expect(items.first.id, 'tt1160419');
      expect(items.first.mediaType.name, 'movie');
      expect(items.first.posterUrl, contains('metahub'));
      expect(items.last.mediaType.name, 'series');
    });

    test('reads the TMDb id, title and year from meta', () {
      const body = '''
        {"meta":{"imdb_id":"tt15239678","moviedb_id":693134,
                 "name":"Dune: Part Two","releaseInfo":"2024-02-27"}}
      ''';
      final meta = AutoEmbedProvider.parseMeta(body);

      expect(meta, isNotNull);
      expect(meta!.tmdbId, '693134');
      expect(meta.title, 'Dune: Part Two');
      expect(meta.year, '2024');
      expect(AutoEmbedProvider.parseMeta('{"meta":{}}')!.tmdbId, isNull);
    });

    test('builds Cinemeta URLs', () {
      expect(
        AutoEmbedProvider.searchUri('dune').toString(),
        'https://v3-cinemeta.strem.io/catalog/movie/top/search=dune.json',
      );
      expect(
        AutoEmbedProvider.metaUri('movie', 'tt1').toString(),
        'https://v3-cinemeta.strem.io/meta/movie/tt1.json',
      );
      expect(
        AutoEmbedProvider.searchUri('star wars').toString(),
        contains('search=star%20wars'),
      );
    });
  });
}
