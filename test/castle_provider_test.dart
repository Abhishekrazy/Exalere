import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/castle_provider.dart';

void main() {
  group('Castle key derivation', () {
    test('expands the security key with the suffix to 16 bytes', () {
      // Live sample: ZkpBVG0qa2dmSg== -> base64 bytes + "T!BgJB".
      final key = CastleProvider.deriveKey('ZkpBVG0qa2dmSg==');
      expect(
        key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        '664a41546d2a6b67664a542142674a42',
      );
      expect(key, hasLength(16));
    });

    test('truncates a long security key to 16 bytes', () {
      final key = CastleProvider.deriveKey(base64Encode(List.filled(32, 0x11)));
      expect(key, hasLength(16));
      expect(key.every((b) => b == 0x11), isTrue);
    });
  });

  group('Castle envelopes', () {
    test('reads rows and their contents', () {
      final envelope = {
        'data': {
          'rows': [
            {
              'name': 'Watch Popular Movies',
              'contents': [
                {
                  'title': 'Jailer 2',
                  'redirectId': '10078138216859170',
                  'coverImage': 'https://img/x.jpg',
                  'movieType': 2,
                },
                {'title': 'A Series', 'redirectId': '42', 'movieType': 1},
              ],
            },
          ],
        },
      };
      final rows = CastleProvider.rowsFrom(envelope);
      expect(rows, hasLength(1));
      final items = CastleProvider.parseItems(
        CastleProvider.contentsFrom(rows.first),
      );

      expect(items, hasLength(2));
      expect(items.first.id, '10078138216859170');
      expect(items.first.mediaType.name, 'movie');
      expect(items.last.mediaType.name, 'series');
    });

    test('reads search hits from the nested data list', () {
      final envelope = {
        'data': {
          'data': [
            {'title': 'Dune', 'redirectId': '7', 'movieType': 2},
          ],
        },
      };
      final items = CastleProvider.parseSearch(envelope);
      expect(items.single.title, 'Dune');
      expect(items.single.id, '7');
    });

    test('reads episodes and their resolutions', () {
      final envelope = {
        'data': {
          'data': {
            'title': 'Jailer 2',
            'coverVerticalImage': 'https://img/p.jpg',
            'episodes': [
              {
                'id': '10220624516432876',
                'title': 'Jailer 2',
                'number': 1,
                'videos': [
                  {'resolution': 1},
                  {'resolution': 3},
                ],
              },
            ],
          },
        },
      };
      final details = CastleProvider.parseDetails(envelope);

      expect(details, isNotNull);
      expect(details!.title, 'Jailer 2');
      expect(details.episodes.single.resolutions, ['1', '3']);
    });

    test('reads the playback url', () {
      expect(
        CastleProvider.parseVideoUrl({
          'data': {'videoUrl': 'https://img1.hscow.com/hls/x/index.m3u8?sig=1'},
        }),
        startsWith('https://img1.hscow.com/hls/x/index.m3u8'),
      );
      expect(CastleProvider.parseVideoUrl({'data': {}}), isNull);
      expect(CastleProvider.parseVideoUrl(null), isNull);
    });

    test('quotes bare numeric ids before parsing', () {
      final decoded = CastleProvider.decodeJson(
        '{"redirectId":10078138216859170,"title":"X"}',
      );
      expect(decoded, isNotNull);
      expect('${decoded['redirectId']}', '10078138216859170');
    });
  });

  group('Castle decryption', () {
    test(
      'decrypts an AES-128-CBC payload with the derived key as IV',
      () async {
        final key = CastleProvider.deriveKey('ZkpBVG0qa2dmSg==');
        const plain = '{"code":200,"data":{"rows":[]}}';

        final algorithm = AesCbc.with128bits(macAlgorithm: MacAlgorithm.empty);
        final box = await algorithm.encrypt(
          utf8.encode(plain),
          secretKey: SecretKey(key),
          nonce: key,
        );
        final cipher = base64Encode(box.cipherText);

        final provider = CastleProvider();
        // ignore: invalid_use_of_visible_for_testing_member
        final decrypted = await provider.decryptForTest(
          cipher,
          Uint8List.fromList(key),
        );
        expect(decrypted, plain);
      },
    );
  });
}
