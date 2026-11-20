import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/services/animesalt_provider.dart';
import 'package:exalere/services/extractors/zypter_extractor.dart';

void main() {
  group('ZypterExtractor', () {
    test('reads the signed playlist from the data endpoint', () {
      const body =
          '{"hls":true,"videoSource":"https:\\/\\/ravok.buzz\\/cdn\\/hls\\/abc'
          '\\/master.m3u8?md5=x&expires=1","securedLink":""}';
      expect(
        ZypterExtractor.parseResponse(body),
        'https://ravok.buzz/cdn/hls/abc/master.m3u8?md5=x&expires=1',
      );
    });

    test('falls back to securedLink and rejects junk', () {
      expect(
        ZypterExtractor.parseResponse(
          '{"securedLink":"https://cdn.example/master.m3u8"}',
        ),
        'https://cdn.example/master.m3u8',
      );
      expect(ZypterExtractor.parseResponse('{"hls":false}'), isNull);
      expect(ZypterExtractor.parseResponse('not json'), isNull);
    });

    test('extracts player hashes and recognises hosts', () {
      const html = '''
        <iframe src="https://ravok.buzz/video/8757150decbd89b0f5442ca3db4d0e0e"></iframe>
        <iframe src="https://ravok.buzz/video/8757150decbd89b0f5442ca3db4d0e0e"></iframe>
      ''';
      expect(ZypterExtractor.videoHashes(html), [
        '8757150decbd89b0f5442ca3db4d0e0e',
      ]);
      expect(
        ZypterExtractor.isZypterHost('https://ravok.buzz/video/x'),
        isTrue,
      );
      expect(
        ZypterExtractor.isZypterHost('https://zephyrix.org/video/x'),
        isTrue,
      );
      expect(ZypterExtractor.isZypterHost('https://example.com'), isFalse);
    });
  });

  group('AnimeSaltProvider parsing', () {
    test('maps series cards to media items', () {
      const html = '''
        <div class="card">
          <a class="play-butn" href="https://animesalt.in/series/one-piece">PLAY NOW</a>
          <img src="https://img/one.jpg" alt="One Piece">
        </div>
        <div class="card">
          <a class="play-butn" href="https://animesalt.in/series/black-clover">PLAY NOW</a>
        </div>
      ''';
      final items = AnimeSaltProvider.parseSeries(html);

      expect(items, hasLength(2));
      expect(items.first.id, 'series/one-piece');
      expect(items.first.posterUrl, 'https://img/one.jpg');
      expect(items.first.title, 'One Piece');
      expect(items.last.title, 'black clover');
    });

    test('reads ordered episode slugs', () {
      const html = '''
        <a href="https://animesalt.in/episode/one-piece-1x1">1</a>
        <a href="https://animesalt.in/episode/one-piece-1x2">2</a>
        <a href="https://animesalt.in/episode/one-piece-1x1">duplicate</a>
      ''';
      expect(AnimeSaltProvider.parseEpisodeSlugs(html), [
        'one-piece-1x1',
        'one-piece-1x2',
      ]);
    });

    test('reads player iframes', () {
      const html = '''
        <iframe data-src="https://ravok.buzz/video/abc"></iframe>
        <iframe src="https://zephyrix.org/video/def"></iframe>
        <iframe src="about:blank"></iframe>
      ''';
      expect(AnimeSaltProvider.parseIframes(html), [
        'https://ravok.buzz/video/abc',
        'https://zephyrix.org/video/def',
      ]);
    });
  });

  test('a search that answers empty once is retried', () async {
    // The site returns 200 with no cards while its cache is cold; two of three
    // runs used to fail here, which is what made the self-test flaky.
    var calls = 0;
    final provider = AnimeSaltProvider(
      client: MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('<html><body></body></html>', 200);
        return http.Response(
          '<html><body><a href="https://animesalt.in/series/one-piece/">'
          'One Piece</a></body></html>',
          200,
        );
      }),
    );

    final hits = await provider.search('one piece');

    expect(calls, greaterThanOrEqualTo(2));
    expect(hits, isNotEmpty);
    expect(hits.first.title, contains('One Piece'));
  });
}
