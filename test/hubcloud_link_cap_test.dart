import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/extractors/hubcloud_extractor.dart';
import 'package:exalere/services/scrapers/hubcloud_site_scraper.dart';

void main() {
  group('linksToTry', () {
    List<ScrapedLink> links(int count, {bool duplicate = false}) => [
      for (var i = 0; i < count; i++)
        ScrapedLink(title: '1080p #$i', url: 'https://cdn.example/$i'),
      if (duplicate)
        const ScrapedLink(title: '1080p again', url: 'https://cdn.example/0'),
    ];

    test('caps a long page', () {
      expect(HubCloudSiteScraper.linksToTry(links(100)), hasLength(8));
    });

    test('keeps order and drops duplicate urls', () {
      final picked = HubCloudSiteScraper.linksToTry(links(3, duplicate: true));
      expect(picked.map((link) => link.url), [
        'https://cdn.example/0',
        'https://cdn.example/1',
        'https://cdn.example/2',
      ]);
    });

    test('passes short pages through untouched', () {
      expect(HubCloudSiteScraper.linksToTry(links(2)), hasLength(2));
      expect(HubCloudSiteScraper.linksToTry(const []), isEmpty);
    });
  });

  group('parseEpisodeLinks', () {
    test('skips telegram buttons but keeps the mirror next to them', () {
      // hubdrive.blog prints a Telegram button ahead of the real mirror, and the
      // extractor used to pick the Telegram link — which can never resolve.
      const html = """
        <h4><a href="https://hubcloud.mov/tg/go?id=abc123">Join</a></h4>
        <h5><a class="btn" href="https://hubcloud.mov/drive/vsur13sas4qsffu">[HubCloud Server]</a></h5>
        <a href="https://t.me/somechannel">Telegram</a>
      """;

      final links = HubCloudExtractor.parseEpisodeLinks(html);

      expect(links.map((link) => link.url), [
        'https://hubcloud.mov/drive/vsur13sas4qsffu',
      ]);
    });

    test('reads a plain drive anchor with no quality label', () {
      const html =
          '<div><a href="https://hubdrive.blog/file/1862402834">Mirror</a></div>'
          '<h5><a href="https://hubcloud.mov/drive/abc">Server</a></h5>';

      final links = HubCloudExtractor.parseEpisodeLinks(html);

      expect(
        links.map((link) => link.url),
        contains('https://hubcloud.mov/drive/abc'),
      );
    });
  });
}
