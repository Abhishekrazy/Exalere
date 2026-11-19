import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/torrentio_provider.dart';

void main() {
  group('Torrentio URL builder', () {
    test('movie and series URLs follow the Stremio add-on shape', () {
      expect(
        TorrentioProvider.streamUrl(imdbId: 'tt0133093'),
        'https://torrentio.strem.fun/stream/movie/tt0133093.json',
      );
      expect(
        TorrentioProvider.streamUrl(imdbId: 'tt0944947', season: 1, episode: 2),
        'https://torrentio.strem.fun/stream/series/tt0944947:1:2.json',
      );
    });
  });

  group('Torrentio stream parsing', () {
    const payload = '''
      {"streams":[
        {"name":"Torrentio\\n1080p","title":"The Matrix [1080p]\\n👤 200 💾 2.1 GB",
         "infoHash":"61065ea115b7cc3e8db9fb5ab1f6f327f08bd1c9","fileIdx":0,
         "behaviorHints":{"filename":"The.Matrix.1999.1080p.mkv"},
         "sources":["tracker:udp://tracker.opentrackr.org:1337/announce",
                    "dht:61065ea115b7cc3e8db9fb5ab1f6f327f08bd1c9"]},
        {"name":"Torrentio\\n4k","title":"The Matrix [2160p]","infoHash":"61065ea115b7cc3e8db9fb5ab1f6f327f08bd1c9"},
        {"name":"Torrentio","title":"No hash entry"},
        {"name":"Torrentio\\n720p","title":"HD","infoHash":"ffffffffffffffffffffffffffffffffffffffff",
         "sources":[]}
      ]}
    ''';

    test('builds magnet links with trackers from sources', () {
      final magnet = TorrentioProvider.magnetFor({
        'infoHash': '61065EA115B7CC3E8DB9FB5AB1F6F327F08BD1C9',
        'behaviorHints': {'filename': 'The.Matrix.1999.1080p.mkv'},
        'sources': [
          'tracker:udp://tracker.opentrackr.org:1337/announce',
          'dht:abc',
        ],
      });

      expect(magnet, isNotNull);
      expect(magnet, startsWith('magnet:?xt=urn:btih:61065ea1'));
      expect(magnet, contains('The.Matrix.1999.1080p.mkv'));
      expect(magnet, contains('tr=udp%3A%2F%2Ftracker.opentrackr.org'));
    });

    test('rejects entries without a valid info hash', () {
      expect(TorrentioProvider.magnetFor({'infoHash': 'short'}), isNull);
      expect(TorrentioProvider.magnetFor({'title': 'none'}), isNull);
    });

    test('derives quality labels from name and title', () {
      expect(
        TorrentioProvider.qualityFor({
          'name': 'Torrentio',
          'title': '2160p DV',
        }),
        '2160p',
      );
      expect(
        TorrentioProvider.qualityFor({'name': 'Torrentio 720p', 'title': ''}),
        '720p',
      );
      expect(
        TorrentioProvider.qualityFor({'name': 'Torrentio', 'title': '4K HDR'}),
        '2160p',
      );
      expect(
        TorrentioProvider.qualityFor({'name': 'Torrentio', 'title': 'WEB-DL'}),
        'Auto',
      );
    });

    test('parses streams, dedupes hashes, sorts by quality and caps', () {
      final streams = TorrentioProvider.parseStreams(payload, limit: 2);

      expect(streams, hasLength(2));
      expect(streams.first.quality, '2160p');
      expect(streams.first.url, startsWith('magnet:?xt=urn:btih:'));
      expect(streams.first.format, 'P2P');
      expect(streams.first.server, 'Torrentio');
      expect(streams.last.quality, '1080p');
      // The duplicate 4K entry and the hash-less one are dropped.
      expect(streams.where((s) => s.url.contains('61065ea1')), hasLength(2));
    });

    test('malformed payloads yield no streams', () {
      expect(TorrentioProvider.parseStreams('not json'), isEmpty);
      expect(TorrentioProvider.parseStreams('{"streams":{}}'), isEmpty);
    });
  });
}
