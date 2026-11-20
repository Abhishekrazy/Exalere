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
}
