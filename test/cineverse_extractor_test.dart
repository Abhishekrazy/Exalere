import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/extractors/cineverse_extractor.dart';
import 'package:exalere/services/scrapers/vega_site_config.dart';

void main() {
  group('CineverseExtractor', () {
    const embed = '''
      <iframe id="playerFrame" src="/proxy.php?p=streamhg&amp;c=8smz&amp;noredirect=1"></iframe>
      <div class="srv-item active"
           data-url="https://multimoviesshg.com/e/8smz"
           data-platform="streamhg"
           data-pname="StreamHG"
           data-code="8smz"></div>
      <div class="srv-item "
           data-url="/proxy.php?p=vidrift&amp;c=1322218%3Amovie"
           data-platform="vidrift"
           data-pname="Vidrift"
           data-code="1322218:movie:0:0"></div>
    ''';

    test('parses server buttons with multi-line attributes', () {
      final servers = CineverseExtractor.parseServers(embed);

      expect(servers, hasLength(2));
      expect(servers.first.platform, 'streamhg');
      expect(servers.first.name, 'StreamHG');
      expect(servers.first.code, '8smz');
      expect(servers.first.embedUrl, 'https://multimoviesshg.com/e/8smz');
      expect(servers.last.platform, 'vidrift');
      expect(servers.last.embedUrl, startsWith('/proxy.php'));
    });

    test('builds the hub proxy URL when a server has no direct player', () {
      final server = CineverseExtractor.parseServers(embed).last;
      final url = CineverseExtractor.proxyUrl(
        'https://rozgarlelo.modiplay.xyz',
        server,
        '',
      );

      expect(url, startsWith('https://rozgarlelo.modiplay.xyz/proxy.php?'));
      expect(url, contains('p=vidrift'));
      expect(url, contains('noredirect=1'));
      expect(url, contains('site_ref='));
    });

    test('extracts the stream_proxy relay and appends seg=direct', () {
      const html = '''
        <script>
          var src="\\/stream_proxy.php?url=https%3A%2F%2Fvibuxer.com%2Fmaster.m3u8&amp;ref=https%3A%2F%2Fvibuxer.com%2Fe%2F8smz&amp;tok=abc";
        </script>
      ''';

      final playlist = CineverseExtractor.extractM3u8(
        html,
        'https://rozgarlelo.modiplay.xyz',
      );

      expect(playlist, isNotNull);
      expect(
        playlist,
        startsWith('https://rozgarlelo.modiplay.xyz/stream_proxy.php?'),
      );
      expect(playlist, contains('seg=direct'));
    });

    test('prefers an explicit directSrc playlist', () {
      const html = '''
        <script>var directSrc="https://cdn.example.com/master.m3u8?token=1";</script>
      ''';
      expect(
        CineverseExtractor.extractM3u8(html, 'https://hub.example'),
        'https://cdn.example.com/master.m3u8?token=1',
      );
    });

    test('returns null when a proxy page carries no playlist', () {
      expect(
        CineverseExtractor.extractM3u8(
          '<html>no player here</html>',
          'https://hub.example',
        ),
        isNull,
      );
    });

    test('collects embed URLs printed on a post page', () {
      const post = '''
        <iframe src="https://rozgarlelo.modiplay.xyz/embed/tmdb/movie?id=1"></iframe>
        <a href="https://vidbolt.xyz/movie/1">VidBolt</a>
        <iframe src="https://rozgarlelo.modiplay.xyz/embed/tmdb/movie?id=1"></iframe>
      ''';

      final urls = CineverseExtractor.collectEmbedUrls(post);
      expect(urls, hasLength(1));
      expect(urls.single, contains('modiplay.xyz/embed/tmdb/movie'));
    });
  });

  group('MultiMovies config', () {
    test('declares trending, search and poster-card grid', () {
      final config = VegaSiteConfig.byId('multimovies')!;

      expect(config.catalogPath(1), '/trending');
      expect(config.catalogPath(2), '/trending/page/2/');
      expect(config.searchPath('avatar', 1), '/search?q=avatar');
      expect(config.cards.container, 'article.poster-card');
      expect(config.cards.linkSelector, 'a.poster-art');
    });
  });
}
