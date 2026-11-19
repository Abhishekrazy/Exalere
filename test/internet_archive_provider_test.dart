import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/internet_archive_provider.dart';

void main() {
  group('InternetArchiveProvider URLs', () {
    test('search asks advancedsearch for the rendered fields', () {
      final url = InternetArchiveProvider.searchUrl('metropolis');

      expect(url, startsWith('https://archive.org/advancedsearch.php?q='));
      expect(url, contains('mediatype%3A(movies)'));
      expect(url, contains('fl[]=identifier'));
      expect(url, contains('fl[]=title'));
      expect(url, contains('output=json'));
    });

    test('catalog restricts to public-domain and Creative Commons items', () {
      final url = InternetArchiveProvider.catalogUrl(page: 2);

      expect(url, contains('licenseurl%3A*publicdomain*'));
      expect(url, contains('licenseurl%3A*creativecommons*'));
      expect(url, contains('page=2'));
    });
  });

  group('InternetArchiveProvider parsing', () {
    const searchJson = '''
      {"response":{"numFound":2,"docs":[
        {"identifier":"metropolis_1927","title":"Metropolis","year":"1927","downloads":12345},
        {"identifier":"night_of_the_living_dead","title":"Night of the Living Dead","year":"1968"}
      ]}}
    ''';

    test('maps advanced-search docs to media items', () {
      final items = InternetArchiveProvider.parseSearchJson(searchJson);

      expect(items, hasLength(2));
      expect(items.first.id, 'metropolis_1927');
      expect(items.first.title, 'Metropolis');
      expect(items.first.year, '1927');
      expect(
        items.first.posterUrl,
        'https://archive.org/services/img/metropolis_1927',
      );
      expect(items.first.providerId, 'internetarchive');
    });

    test('skips duplicated identifiers and malformed payloads', () {
      const duplicated =
          '{"response":{"docs":[{"identifier":"a"},{"identifier":"a"}]}}';
      expect(InternetArchiveProvider.parseSearchJson(duplicated), hasLength(1));
      expect(InternetArchiveProvider.parseSearchJson('not json'), isEmpty);
    });

    test('picks the tallest mp4 and ignores artwork', () {
      final file = InternetArchiveProvider.pickVideoFile([
        {'name': 'metropolis_thumb.jpg', 'size': '9000'},
        {'name': 'metropolis_512kb.mp4', 'height': '480', 'size': '400000000'},
        {'name': 'metropolis_1080.mp4', 'height': '1080', 'size': '900000000'},
        {'name': 'metropolis.ogv', 'size': '500000000'},
      ]);

      expect(file, isNotNull);
      expect(file!['name'], 'metropolis_1080.mp4');
    });

    test('falls back to the largest file when heights are missing', () {
      final file = InternetArchiveProvider.pickVideoFile([
        {'name': 'copy-small.mp4', 'size': '100'},
        {'name': 'copy-large.mp4', 'size': '900'},
      ]);

      expect(file!['name'], 'copy-large.mp4');
    });

    test('builds a playable download URL with quality from the file', () {
      const metadata = '''
        {"files":[
          {"name":"Metropolis (1927) 1080p.mp4","height":"1080","size":"900"}
        ]}
      ''';

      final streams = InternetArchiveProvider.streamsFromMetadata(
        metadata,
        identifier: 'metropolis_1927',
      );

      expect(streams, hasLength(1));
      expect(streams.single.quality, '1080p');
      expect(streams.single.format, 'MP4');
      expect(streams.single.server, 'Archive.org');
      expect(
        streams.single.url,
        'https://archive.org/download/metropolis_1927/'
        'Metropolis%20(1927)%201080p.mp4',
      );
    });

    test('an item with no video files yields no streams', () {
      expect(
        InternetArchiveProvider.streamsFromMetadata(
          '{"files":[{"name":"cover.jpg"}]}',
          identifier: 'x',
        ),
        isEmpty,
      );
    });
  });

  test('registry creates the engine from its built-in config', () {
    final plugin = createPlugin(
      ExalerePluginConfig(
        id: 'internetarchive',
        name: 'Internet Archive',
        baseUrl: 'https://archive.org',
        addedAt: DateTime(2026),
      ),
    );

    expect(plugin, isA<InternetArchivePlugin>());
    expect(plugin.supportsStreams, isTrue);
    expect(plugin.supportsMetadata, isFalse);
    expect(plugin.catalogs.single.id, 'public_domain');
  });
}
