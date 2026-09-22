import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/fourkhdhub_provider.dart';
import 'package:exalere/services/provider_registry.dart';

void main() {
  group('FourKHdHubProvider Tests', () {
    test('parseSeasonEpisode extracts seasons and episodes correctly', () {
      expect(
        FourKHdHubProvider.parseSeasonEpisode(
          'Neagley.S01E01.L.Train.2160p.AMZN.WEB-DL.Multi.DDP5.1.H.265-4kHdHub.Com.mkv',
        ),
        equals((1, 1)),
      );
      expect(
        FourKHdHubProvider.parseSeasonEpisode(
          'Reacher.S02E08.1080p.WEB-DL.mkv',
        ),
        equals((2, 8)),
      );
      expect(
        FourKHdHubProvider.parseSeasonEpisode(
          'Inception.2010.1080p.BluRay.x264.mkv',
        ),
        isNull,
      );
    });

    test('detectQuality and detectCodec parse filenames correctly', () {
      const fn4k =
          'Neagley.S01E01.L.Train.2160p.AMZN.WEB-DL.Multi.DDP5.1.DV.HDR.H.265-4kHdHub.Com.mkv';
      expect(FourKHdHubProvider.detectQuality(fn4k), equals('4K (2160p)'));
      expect(FourKHdHubProvider.detectCodec(fn4k), equals('HEVC • DV HDR'));

      const fn1080 =
          'Neagley.S01E01.L.Train.1080p.AMZN.WEB-DL.Multi.DDP5.1.AV1-4kHdHub.Com.mkv';
      expect(FourKHdHubProvider.detectQuality(fn1080), equals('1080p (FHD)'));
      expect(FourKHdHubProvider.detectCodec(fn1080), equals('AV1'));

      const fn720 = 'Neagley.S01E01.720p.H.264-4kHdHub.Com.mkv';
      expect(FourKHdHubProvider.detectQuality(fn720), equals('720p (HD)'));
      expect(FourKHdHubProvider.detectCodec(fn720), equals('H.264'));
    });

    test('parseSizeBytes parses GB, MB, KB values', () {
      expect(
        FourKHdHubProvider.parseSizeBytes('6.62 GB'),
        equals((6.62 * 1024 * 1024 * 1024).toInt()),
      );
      expect(
        FourKHdHubProvider.parseSizeBytes('885 MB'),
        equals((885 * 1024 * 1024).toInt()),
      );
      expect(
        FourKHdHubProvider.parseSizeBytes('500 KB'),
        equals((500 * 1024).toInt()),
      );
      expect(FourKHdHubProvider.parseSizeBytes('Unknown'), isNull);
    });

    test('rot13 decodes character substitution properly', () {
      expect(FourKHdHubProvider.rot13('uryyb'), equals('hello'));
      expect(FourKHdHubProvider.rot13('URYYB'), equals('HELLO'));
      expect(FourKHdHubProvider.rot13('123!?'), equals('123!?'));
    });

    test('decodeGreenmotorsPayload unpacks multi-stage obfuscated payload', () {
      const payload =
          'Y214WE0xWjNZbXRhVUdwMmIxQldObFo2ZFRCeFZVOXRRbmxxYVV0UU9XRndla2w1YjNveGFYRlVPV3h3YkRWM2IxVkpka3RRT1dKdk1qRjViMVJUYUUxVVNXeExVRGgyV1ZCWGFWWjNZblpNU0hWR1dsUkJWa2RIVFZweVIzbHBUVk54V0c1NlYxVkNSMU51UkcxSmFreHRRVVZ4ZVdOV1JtRlBlRzlKU1RKSFNIRjRjbFJKVlhCVU9YVktValJ0VEhveFRWcFRlRzFLUzNSMmMwUTlQUT09';

      final targetUrl = FourKHdHubProvider.decodeGreenmotorsPayload(payload);
      expect(targetUrl, equals('https://hubcloud.ist/drive/0gqxjhiswnf4cv1'));
    });

    test('pixeldrainApiUrl formats download endpoint correctly', () {
      expect(
        FourKHdHubProvider.pixeldrainApiUrl(
          'https://pixeldrain.dev/u/r18URQ3F',
        ),
        equals('https://pixeldrain.com/api/file/r18URQ3F?download'),
      );
      expect(
        FourKHdHubProvider.pixeldrainApiUrl(
          'https://pixeldrain.com/api/file/negn6f',
        ),
        equals('https://pixeldrain.com/api/file/negn6f?download'),
      );
      expect(
        FourKHdHubProvider.pixeldrainApiUrl('https://otherdomain.com/u/abc'),
        isNull,
      );
    });

    test('unwrapWatchOnlineUrl decodes base64 url parameter from pages.dev', () {
      const pagesUrl =
          'https://vdplay.pages.dev/?u=aHR0cHM6Ly9jZG4uZXhhbXBsZS5jb20vdmlkZW8ubWt2';
      expect(
        FourKHdHubProvider.unwrapWatchOnlineUrl(pagesUrl),
        equals('https://cdn.example.com/video.mkv'),
      );
    });

    test('parseReleases filters by season and episode', () {
      const sampleHtml = '''
<div class="episode-download-item">
  <div class="episode-file-title">
    Neagley.S01E01.L.Train.2160p.AMZN.WEB-DL.Multi.DDP5.1.DV.HDR.H.265-4kHdHub.Com.mkv
  </div>
  <div class="episode-file-info">
    <span class="badge-size">6.62 GB</span>
  </div>
  <div class="episode-links">
    <a href="https://greenmotors.club/?id=link1" class="btn">Download HubCloud</a>
    <a href="https://greenmotors.club/?id=link2" class="btn">Download HubDrive</a>
  </div>
</div>
<div class="episode-download-item">
  <div class="episode-file-title">
    Neagley.S01E02.Team.2160p.AMZN.WEB-DL.Multi.DDP5.1.H.265-4kHdHub.Com.mkv
  </div>
  <div class="episode-file-info">
    <span class="badge-size">5.40 GB</span>
  </div>
  <div class="episode-links">
    <a href="https://greenmotors.club/?id=link3" class="btn">Download HubCloud</a>
  </div>
</div>
''';

      final ep1Releases = FourKHdHubProvider.parseReleases(
        sampleHtml,
        season: 1,
        episode: 1,
      );
      expect(ep1Releases.length, equals(1));
      expect(ep1Releases.first.season, equals(1));
      expect(ep1Releases.first.episode, equals(1));
      expect(ep1Releases.first.quality, equals('4K (2160p)'));
      expect(ep1Releases.first.mirrors.length, equals(2));

      final ep2Releases = FourKHdHubProvider.parseReleases(
        sampleHtml,
        season: 1,
        episode: 2,
      );
      expect(ep2Releases.length, equals(1));
      expect(ep2Releases.first.episode, equals(2));

      final ep3Releases = FourKHdHubProvider.parseReleases(
        sampleHtml,
        season: 1,
        episode: 3,
      );
      expect(ep3Releases, isEmpty);
    });

    test(
      'parseSearchResults parses movie cards with series tag and providerId',
      () {
        const searchHtml = '''
<div class="card-grid">
  <a href="/neagley-series-8117/" class="movie-card">
    <div class="movie-card-title">Neagley</div>
    <div class="movie-card-meta">2026 Series</div>
    <img src="https://image.tmdb.org/t/p/w500/poster.jpg" />
  </a>
  <a href="/avatar-movie-1234/" class="movie-card">
    <div class="movie-card-title">Avatar</div>
    <div class="movie-card-meta">2009 Movie</div>
  </a>
</div>
''';

        final items = FourKHdHubProvider().parseSearchResults(searchHtml);
        expect(items.length, equals(2));

        final seriesItem = items.first;
        expect(seriesItem.title, equals('Neagley'));
        expect(seriesItem.isSeries, isTrue);
        expect(seriesItem.year, equals('2026'));
        expect(seriesItem.provider, equals(ProviderType.fourKHdHub));
        expect(seriesItem.providerId, equals('fourkhdhub'));

        final movieItem = items[1];
        expect(movieItem.title, equals('Avatar'));
        expect(movieItem.isSeries, isFalse);
        expect(movieItem.year, equals('2009'));
      },
    );

    test('FourKHdHubAdapter declares support for both movies and series', () {
      final adapter = FourKHdHubAdapter();
      expect(adapter.id, equals('fourkhdhub'));
      expect(adapter.supportsMovies, isTrue);
      expect(adapter.supportsSeries, isTrue);
      expect(adapter.supportsSearch, isTrue);
      expect(adapter.priority, equals(50));
    });

    test('scoreCandidate ranks R2/Google highest and PixelDrain lowest', () {
      expect(
        FourKHdHubProvider.scoreCandidate(
          'https://cb28.r2.cloudflarestorage.com/hub/video.mkv',
        ),
        equals(0),
      );
      expect(
        FourKHdHubProvider.scoreCandidate(
          'https://video.googleusercontent.com/stream.mp4',
        ),
        equals(0),
      );
      expect(
        FourKHdHubProvider.scoreCandidate(
          'https://storage.googleapis.com/bucket/video.mp4',
        ),
        equals(1),
      );
      expect(
        FourKHdHubProvider.scoreCandidate('https://somecdn.com/video.mp4'),
        equals(2),
      );
      expect(
        FourKHdHubProvider.scoreCandidate(
          'https://pixeldrain.com/api/file/abc?download',
        ),
        equals(3),
      );
    });

    test('getHeadersForUrl strips Referer for R2/AWS presigned URLs', () {
      final r2Headers = FourKHdHubProvider.getHeadersForUrl(
        'https://cb28.r2.cloudflarestorage.com/hub/video.mkv?X-Amz-Signature=123',
      );
      expect(r2Headers.containsKey('Referer'), isFalse);
      expect(r2Headers['User-Agent'], isNotEmpty);

      final standardHeaders = FourKHdHubProvider.getHeadersForUrl(
        'https://hubcloud.ist/download/video.mkv',
      );
      expect(standardHeaders['Referer'], equals('https://4khdhub.one'));
    });
  });
}
