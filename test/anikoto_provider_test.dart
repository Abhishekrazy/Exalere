import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/anikoto_provider.dart';

void main() {
  group('Anikoto request guard', () {
    test('RC4 matches the reference implementation', () {
      // Classic vector: RC4("Key", "Plaintext") = BBF316E8D940AF0AD3.
      final cipher = AnikotoProvider.rc4('Key', 'Plaintext');
      expect(
        cipher.codeUnits
            .map((c) => c.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase(),
        'BBF316E8D940AF0AD3',
      );
    });

    test('vrf is base64 of the RC4 output', () {
      final vrf = AnikotoProvider.encodeVrf('6224');
      expect(
        vrf,
        base64Encode(AnikotoProvider.rc4('simple-hash', '6224').codeUnits),
      );
      expect(vrf, isNotEmpty);
    });
  });

  group('Anikoto listing parsing', () {
    test('reads watch cards with titles and posters', () {
      const html = '''
        <div class="item">
          <a href="https://anikototv.to/watch/solo-leveling-ilh08/ep-1">
            <img src="https://img/solo.jpg" alt="Solo Leveling">
          </a>
          <a class="name d-title" data-jp="Ore dake Level Up na Ken">Solo Leveling</a>
        </div>
        <div class="item">
          <a href="/watch/other-anime-1a2b3c/ep-1"><span>Other Anime</span></a>
        </div>
      ''';
      final items = AnikotoProvider.parseWatchLinks(html);

      expect(items, hasLength(2));
      expect(
        items.first.id,
        'https://anikototv.to/watch/solo-leveling-ilh08/ep-1',
      );
      expect(items.first.title, 'Ore dake Level Up na Ken');
      expect(items.first.posterUrl, 'https://img/solo.jpg');
      expect(items.last.title, 'Other Anime');
    });
  });

  group('Anikoto AJAX payloads', () {
    test('reads ordered episodes with their data-ids', () {
      final body = jsonEncode({
        'status': 200,
        'result':
            '<ul class="ep-range">'
            '<li><a data-num="2" data-ids="SECOND">2</a></li>'
            '<li><a data-num="1" data-ids="FIRST">1</a></li>'
            '</ul>',
      });
      final episodes = AnikotoProvider.parseEpisodeList(body);

      expect(episodes.map((e) => e.number), [1, 2]);
      expect(episodes.first.dataIds, 'FIRST');
      expect(AnikotoProvider.parseEpisodeList('{"status":500}'), isEmpty);
    });

    test('reads servers and their sub/dub kind', () {
      final body = jsonEncode({
        'status': 200,
        'result':
            '<div class="servers">'
            '<div class="type" data-type="sub"><ul><li data-link-id="SUB1">HD-1</li></ul></div>'
            '<div class="type" data-type="dub"><ul><li data-link-id="DUB1">HD-1</li></ul></div>'
            '</div>',
      });
      final servers = AnikotoProvider.parseServerList(body);

      expect(servers, hasLength(2));
      expect(servers.first.linkId, 'SUB1');
      expect(servers.first.isSub, isTrue);
      expect(servers.last.isSub, isFalse);
    });

    test('reads the embed url and embed ids', () {
      final body = jsonEncode({
        'status': 200,
        'result': {'url': 'https://megaplay.buzz/stream/s-2/114721/sub?s=tcdn'},
      });
      expect(
        AnikotoProvider.parseServerUrl(body),
        'https://megaplay.buzz/stream/s-2/114721/sub?s=tcdn',
      );
      expect(AnikotoProvider.parseServerUrl('{"status":500}'), isNull);

      final ids = AnikotoProvider.parseEmbedIds(
        '<div data-id="10490" data-realid="114721"></div>',
      );
      expect(ids.dataId, '10490');
      expect(ids.realId, '114721');
    });
  });

  group('Anikoto MegaPlay decryption', () {
    test('decrypts an AES-256-CBC payload with the zero-padded key', () async {
      const plain = '{"file":"https://megap.shiora.top/53ad/master.m3u8"}';
      final key = Uint8List(32)
        ..setRange(0, 16, utf8.encode('i?LMTAx0Q6,:}50U'));
      final iv = Uint8List(16)
        ..setRange(0, 16, utf8.encode("W0;27ToaUpl_P%'c"));

      final algorithm = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);
      final box = await algorithm.encrypt(
        utf8.encode(plain),
        secretKey: SecretKey(key),
        nonce: iv,
      );
      // base64url without padding, as the site sends it.
      final enc = base64Url.encode(box.cipherText).replaceAll('=', '');

      final decrypted = await AnikotoProvider.decryptMegaPlay(enc);
      expect(decrypted, plain);
      expect(
        AnikotoProvider.playlistFromPlain(decrypted!),
        'https://megap.shiora.top/53ad/master.m3u8',
      );
    });

    test('reads playlists from the shapes the API returns', () {
      expect(
        AnikotoProvider.playlistFromPlain('https://cdn/x.m3u8'),
        'https://cdn/x.m3u8',
      );
      expect(
        AnikotoProvider.playlistFromPlain(
          '{"sources":[{"file":"https://cdn/a.m3u8"}]}',
        ),
        'https://cdn/a.m3u8',
      );
      expect(AnikotoProvider.playlistFromPlain('{"nothing":true}'), isNull);
      expect(AnikotoProvider.playlistFromPlain('not json'), isNull);
    });
  });
}
