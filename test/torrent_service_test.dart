import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/torrent_service.dart';

/// These cover the Dart half of the P2P path. The libtorrent side is native and
/// cannot run here, so what is asserted is the parsing, formatting, engine
/// selection and graceful degradation the player depends on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Engine choice is cached, so reset it between tests.
    await TorrentService.instance.refreshEngineConfiguration();
  });

  group('TorrentService.normalizeBaseUrl', () {
    test('accepts a bare host and port', () {
      expect(
        TorrentService.normalizeBaseUrl('127.0.0.1:8090'),
        'http://127.0.0.1:8090',
      );
    });

    test('trims trailing slashes and surrounding whitespace', () {
      expect(
        TorrentService.normalizeBaseUrl('  127.0.0.1:8090/  '),
        'http://127.0.0.1:8090',
      );
      expect(
        TorrentService.normalizeBaseUrl('http://localhost:9000///'),
        'http://localhost:9000',
      );
    });

    test('preserves an explicit scheme', () {
      expect(
        TorrentService.normalizeBaseUrl('https://engine.local'),
        'https://engine.local',
      );
      expect(
        TorrentService.normalizeBaseUrl('http://10.0.2.2:8090'),
        'http://10.0.2.2:8090',
      );
    });
  });

  group('TorrentService engine selection', () {
    test('no engine is configured on a fresh install of a host test', () async {
      expect(await StorageService().getP2pEngineUrl(), '');
      await TorrentService.instance.refreshEngineConfiguration();
      // Tests run on the host: there is no Android engine and no external URL.
      expect(TorrentService.instance.engineKind, TorrentEngineKind.none);
      expect(TorrentService.instance.externalEngineUrl, isNull);
    });

    test('an external URL selects the external engine', () async {
      await StorageService().setP2pEngineUrl('127.0.0.1:8090');
      await TorrentService.instance.refreshEngineConfiguration();

      expect(TorrentService.instance.engineKind, TorrentEngineKind.external);
      expect(
        TorrentService.instance.externalEngineUrl,
        'http://127.0.0.1:8090',
      );
    });

    test('clearing the URL falls back to the bundled engine', () async {
      final storage = StorageService();
      await storage.setP2pEngineUrl('127.0.0.1:8090');
      await TorrentService.instance.refreshEngineConfiguration();
      expect(TorrentService.instance.engineKind, TorrentEngineKind.external);

      await storage.setP2pEngineUrl('   ');
      await TorrentService.instance.refreshEngineConfiguration();
      expect(TorrentService.instance.externalEngineUrl, isNull);
      // Host tests have no bundled engine available.
      expect(TorrentService.instance.engineKind, TorrentEngineKind.none);
    });

    test('stream URL points at the configured external engine', () async {
      await StorageService().setP2pEngineUrl('127.0.0.1:8090');
      await TorrentService.instance.refreshEngineConfiguration();

      final url = await TorrentService.instance.streamUrl(
        'abc123',
        fileIndex: 2,
      );
      expect(url, 'http://127.0.0.1:8090/stream/abc123/2');
    });
  });

  group('TorrentService.isMagnetUrl', () {
    test('recognises magnet links', () {
      expect(
        TorrentService.isMagnetUrl(
          'magnet:?xt=urn:btih:4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
        ),
        isTrue,
      );
      expect(
        TorrentService.isMagnetUrl('  MAGNET:?xt=urn:btih:ABCDEF1234'),
        isTrue,
        reason: 'scheme comparison must be case insensitive',
      );
    });

    test('rejects ordinary stream URLs', () {
      expect(TorrentService.isMagnetUrl('https://cdn.example/a.mp4'), isFalse);
      expect(TorrentService.isMagnetUrl('https://cdn.example/a.m3u8'), isFalse);
      expect(TorrentService.isMagnetUrl(''), isFalse);
    });
  });

  group('TorrentService platform degradation', () {
    test('reports unavailable off Android instead of throwing', () async {
      // Tests run on the host, where there is no Android torrent engine.
      expect(TorrentService.instance.isPlatformCandidate, isFalse);
      expect(await TorrentService.instance.isAvailable(), isFalse);
    });

    test('openMagnet returns null rather than failing', () async {
      final target = await TorrentService.instance.openMagnet(
        'magnet:?xt=urn:btih:4a73752e25d2b7814b62db1dbb16b47c0b4d45be',
      );
      expect(target, isNull);
    });

    test('releasing an unknown torrent is a no-op', () async {
      await TorrentService.instance.release('deadbeef');
      await TorrentService.instance.shutdown();
    });
  });

  group('TorrentStats', () {
    test('parses a native stats map', () {
      final stats = TorrentStats.fromMap({
        'found': true,
        'state': 'downloading',
        'progress': 0.42,
        'downloadRate': 2 * 1024 * 1024,
        'uploadRate': 1024,
        'numPeers': 18,
        'numSeeds': 3,
        'totalDone': 100,
        'totalWanted': 240,
        'hasMetadata': true,
      });

      expect(stats.found, isTrue);
      expect(stats.state, 'downloading');
      expect(stats.progress, 0.42);
      expect(stats.numPeers, 18);
      expect(stats.hasMetadata, isTrue);
      expect(stats.isActive, isTrue);
      expect(stats.summary, contains('2.0 MB/s'));
      expect(stats.summary, contains('18 peers'));
    });

    test('treats a missing torrent as not found', () {
      final stats = TorrentStats.fromMap({'found': false});
      expect(stats.found, isFalse);
      expect(stats.isActive, isFalse);
      expect(stats.summary, isEmpty);
    });

    test('a finished torrent is no longer active', () {
      final stats = TorrentStats.fromMap({
        'found': true,
        'state': 'finished',
        'progress': 1.0,
      });
      expect(stats.isActive, isFalse);
    });

    test('formats sub-megabyte rates without crashing', () {
      final stats = TorrentStats.fromMap({'found': true, 'downloadRate': 512});
      expect(stats.summary, contains('512 B/s'));
    });

    test('singularises one peer', () {
      final stats = TorrentStats.fromMap({'found': true, 'numPeers': 1});
      expect(stats.summary, contains('1 peer'));
      expect(stats.summary, isNot(contains('1 peers')));
    });
  });

  group('TorrentFileInfo', () {
    test('parses a native file entry', () {
      final file = TorrentFileInfo.fromMap({
        'index': 2,
        'name': 'Movie.mkv',
        'path': 'Movie.mkv',
        'size': 3 * 1024 * 1024 * 1024,
      });

      expect(file.index, 2);
      expect(file.name, 'Movie.mkv');
      expect(file.formattedSize, '3.00 GB');
    });

    test('formats a megabyte-scale file', () {
      final file = TorrentFileInfo.fromMap({'size': 700 * 1024 * 1024});
      expect(file.formattedSize, '700 MB');
    });

    test('survives a malformed entry', () {
      final file = TorrentFileInfo.fromMap({});
      expect(file.index, 0);
      expect(file.name, 'file');
      expect(file.formattedSize, isEmpty);
    });
  });

  group('TorrentHandleInfo', () {
    test('selects the file the engine chose', () {
      final handle = TorrentHandleInfo(
        infoHash: 'abc',
        name: 'Example',
        totalSize: 100,
        selectedFileIndex: 1,
        files: const [
          TorrentFileInfo(
            index: 0,
            name: 'sample.mkv',
            path: 'sample.mkv',
            size: 5,
          ),
          TorrentFileInfo(
            index: 1,
            name: 'feature.mkv',
            path: 'f/feature.mkv',
            size: 95,
          ),
        ],
      );

      expect(handle.selectedFile?.name, 'feature.mkv');
    });

    test('falls back to the first file when the index is unknown', () {
      final handle = TorrentHandleInfo(
        infoHash: 'abc',
        name: 'Example',
        totalSize: 10,
        selectedFileIndex: 99,
        files: const [
          TorrentFileInfo(
            index: 0,
            name: 'only.mp4',
            path: 'only.mp4',
            size: 10,
          ),
        ],
      );

      expect(handle.selectedFile?.name, 'only.mp4');
    });

    test('handles a torrent with no files listed', () {
      const handle = TorrentHandleInfo(
        infoHash: 'abc',
        name: 'Example',
        totalSize: 0,
        selectedFileIndex: 0,
        files: [],
      );
      expect(handle.selectedFile, isNull);
    });
  });

  group('TorrentStreamTarget', () {
    test('formats its size for the server label', () {
      const target = TorrentStreamTarget(
        url: 'http://127.0.0.1:1234/stream/abc/0/Movie.mkv',
        infoHash: 'abc',
        fileIndex: 0,
        name: 'Movie.mkv',
        size: 1500 * 1024 * 1024,
      );
      expect(target.formattedSize, '1.46 GB');
      expect(target.url, startsWith('http://127.0.0.1:'));
    });
  });
}
