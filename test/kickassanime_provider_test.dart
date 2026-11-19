import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/kickassanime_provider.dart';

void main() {
  group('KickAssAnime parsing', () {
    test('maps trending results to series items with posters', () {
      const body = '''
        {"result":[
          {"slug":"bungo-stray-dogs-5-af88","title":"Bungou Stray Dogs 5th Season",
           "title_en":"Bungo Stray Dogs 5","poster":{"hq":"abc123"}},
          {"slug":"other-show","title":"Other","poster":{"url":"/img/x.webp"}}
        ]}
      ''';
      final items = KickAssAnimeProvider.parseShows(body);

      expect(items, hasLength(2));
      expect(items.first.id, 'bungo-stray-dogs-5-af88');
      expect(items.first.title, 'Bungo Stray Dogs 5');
      expect(items.first.posterUrl, 'https://kaa.lt/image/poster/abc123.webp');
      expect(items.last.posterUrl, 'https://kaa.lt/img/x.webp');
    });

    test('reads episode numbers and slugs', () {
      const body = '''
        {"result":[
          {"episode_string":"1","slug":"ecbaee"},
          {"episode_string":"2","slug":"ffa11b"}
        ]}
      ''';
      final episodes = KickAssAnimeProvider.parseEpisodes(body);

      expect(episodes, hasLength(2));
      expect(episodes.first.number, '1');
      expect(episodes.first.slug, 'ecbaee');
      expect(episodes.last.number, '2');
    });

    test('extracts the escaped manifest from a player page', () {
      const html = '''
        <script>self.__next_f.push([1,"{\\"manifest\\":[1,\\"https:\\/\\/hls.krussdomi.com\\/manifest\\/abc\\/master.m3u8\\"]}"])</script>
      ''';
      expect(
        KickAssAnimeProvider.parseManifest(
          html,
          'https://krussdomi.com/cat-player/player?id=1',
        ),
        'https://hls.krussdomi.com/manifest/abc/master.m3u8',
      );
    });

    test('resolves protocol-relative and rooted manifests', () {
      expect(
        KickAssAnimeProvider.parseManifest(
          '&quot;manifest&quot;:[1,&quot;//cdn.example/master.m3u8&quot;]',
          'https://player.example/cat-player/player',
        ),
        'https://cdn.example/master.m3u8',
      );
      expect(
        KickAssAnimeProvider.parseManifest(
          '"manifest":[1,"/hls/master.m3u8"]',
          'https://player.example/cat-player/player',
        ),
        'https://player.example/hls/master.m3u8',
      );
      expect(
        KickAssAnimeProvider.parseManifest('no player here', 'https://x'),
        isNull,
      );
    });

    test('lists servers, swapping the ad wrapper for the real player', () {
      const body = '''
        {"servers":[
          {"name":"VidStreaming","src":"https://krussdomi.com/cat-player/vast?id=1"},
          {"name":"BirdStream","src":"/cat-player/player?id=2"},
          {"name":"Empty","src":""}
        ]}
      ''';
      final urls = KickAssAnimeProvider.playerUrls(body);

      expect(urls, hasLength(2));
      expect(urls.first, 'https://krussdomi.com/cat-player/player?id=1');
      expect(urls.last, 'https://kaa.lt/cat-player/player?id=2');
    });
  });
}
