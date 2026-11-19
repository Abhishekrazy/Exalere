import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/animeworld_provider.dart';

void main() {
  group('AnimeWorldProvider parsing', () {
    test('maps catalogue cards with posters', () {
      const html = '''
        <div class="anime-blog">
          <a class="lnk-blk" href="https://watchanimeworld.one/series/arifureta/">
            <img data-src="https://img/arifureta.jpg" alt="Arifureta">
          </a>
          <h2 class="entry-title">Arifureta</h2>
        </div>
        <div class="anime-blog">
          <a class="lnk-blk" href="https://watchanimeworld.one/movies/one-movie/">
            <img src="https://img/movie.jpg" alt="Image One Movie">
          </a>
        </div>
      ''';
      final items = AnimeWorldProvider.parseCards(html);

      expect(items, hasLength(2));
      expect(items.first.id, contains('/series/arifureta/'));
      expect(items.first.posterUrl, 'https://img/arifureta.jpg');
      expect(items.last.title, 'One Movie');
      expect(items.last.mediaType.name, 'movie');
    });

    test('reads post id and seasons from a series page', () {
      const html = '''
        <article id="post-2066" class="post">
          <div class="choose-season">
            <ul class="aa-cnt">
              <li><a data-post="2066" data-season="1">S1</a></li>
              <li><a data-post="2066" data-season="2">S2</a></li>
              <li><a data-post="2066" data-season="3">S3</a></li>
            </ul>
          </div>
        </article>
      ''';
      final meta = AnimeWorldProvider.parseSeriesMeta(html);

      expect(meta.postId, '2066');
      expect(meta.seasons, [1, 2, 3]);
    });

    test('reads episodes from a season AJAX payload', () {
      const html = '''
        <li>
          <article class="episodes">
            <a class="lnk-blk" href="https://watchanimeworld.one/episode/show-1x1/"></a>
            <span class="num-epi">1x1</span>
          </article>
        </li>
        <li>
          <article class="episodes">
            <a class="lnk-blk" href="/episode/show-1x2/"></a>
            <span class="num-epi">1x2</span>
          </article>
        </li>
      ''';
      final episodes = AnimeWorldProvider.parseAjaxEpisodes(
        html,
        'https://watchanimeworld.one/series/show/',
      );

      expect(episodes, hasLength(2));
      expect(episodes.first.season, 1);
      expect(episodes.first.number, 1);
      expect(
        episodes.last.url,
        'https://watchanimeworld.one/episode/show-1x2/',
      );
    });

    test('collects player iframes only', () {
      const html = '''
        <iframe data-src="https://play.zephyrix.org/video/abc"></iframe>
        <iframe src="about:blank"></iframe>
        <iframe src="https://ravok.buzz/video/def"></iframe>
      ''';
      expect(AnimeWorldProvider.parseIframes(html), [
        'https://play.zephyrix.org/video/abc',
        'https://ravok.buzz/video/def',
      ]);
    });
  });
}
