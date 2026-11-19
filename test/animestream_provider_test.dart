import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/animestream_provider.dart';

void main() {
  group('AnimeStream parsing', () {
    test('maps the trending listing', () {
      const body = '''
        {"data":[
          {"content_id":"vx_1f8efhouge5","title":"How dare you!? Season 2",
           "image":"https://media.uniquestream.net/anime/images/series/x.jpg"},
          {"content_id":"vx_second","title":"Second","image":""}
        ]}
      ''';
      final items = AnimeStreamProvider.parseListing(body);

      expect(items, hasLength(2));
      expect(items.first.id, 'vx_1f8efhouge5');
      expect(items.first.title, 'How dare you!? Season 2');
      expect(items.first.posterUrl, contains('media.uniquestream.net'));
      expect(items.last.posterUrl, isNull);
    });

    test('merges series and movies from a search payload', () {
      const body = '''
        {"series":[{"content_id":"vx_s1","title":"Series"}],
         "movies":[{"content_id":"vx_m1","title":"Movie"}]}
      ''';
      final items = AnimeStreamProvider.parseSearch(body);

      expect(items.map((item) => item.id), ['vx_s1', 'vx_m1']);
    });

    test('reads seasons and episodes', () {
      const series = '''
        {"content_id":"vx_show","title":"Show",
         "seasons":[{"content_id":"vx_show_s1","season_number":1}]}
      ''';
      const season = '''
        [{"title":"Episode 1","episode":"1","content_id":"vx_ep1",
          "episode_number":1.0},
         {"title":"Episode 2","content_id":"vx_ep2","episode_number":2.0}]
      ''';

      final seasons = AnimeStreamProvider.parseSeasons(series);
      final episodes = AnimeStreamProvider.parseEpisodes(season);

      expect(seasons.single.contentId, 'vx_show_s1');
      expect(seasons.single.number, 1);
      expect(episodes, hasLength(2));
      expect(episodes.first.contentId, 'vx_ep1');
      expect(episodes.last.number, 2);
    });

    test('reads the signed HLS playlist from a media payload', () {
      const body = '''
        {"content_id":"vx_ep1","dash":null,
         "hls":{"locale":"zh-CN",
                "playlist":"https://yte.mediacache.cc/vx/24nfjckpau8/master.m3u8?exp=1&sig=abc&subs=1",
                "subtitles":null}}
      ''';
      expect(
        AnimeStreamProvider.parsePlaylist(body),
        startsWith('https://yte.mediacache.cc/vx/24nfjckpau8/master.m3u8'),
      );
      expect(AnimeStreamProvider.parsePlaylist('{"hls":{}}'), isNull);
      expect(AnimeStreamProvider.parsePlaylist('not json'), isNull);
    });

    test('builds API URLs', () {
      expect(
        AnimeStreamProvider.listingUri(page: 2).toString(),
        'https://anime.uniquestream.net/api/v1/videos/trending?page=2&limit=20&type=all',
      );
      expect(
        AnimeStreamProvider.searchUri('one piece').toString(),
        'https://anime.uniquestream.net/api/v1/search?query=one+piece',
      );
      expect(
        AnimeStreamProvider.mediaUri('vx_ep1', 'ja-JP').toString(),
        'https://anime.uniquestream.net/api/v1/episode/vx_ep1/media/dash/ja-JP',
      );
    });
  });
}
