import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/moviebox_provider.dart';
import 'package:exalere/models/stream_source.dart';

void main() {
  group('MovieBox Resolution & Quality Tests', () {
    test('parseResolutions parses multi-resolution comma-separated string', () {
      final (top, formatted, qualities) = MovieBoxProvider.parseResolutions(
        '1080,720,480',
      );
      expect(top, equals('1080p'));
      expect(formatted, equals('1080p • 720p • 480p'));
      expect(qualities, equals(['1080p', '720p', '480p']));
    });

    test('parseResolutions parses unsorted resolutions and deduplicates', () {
      final (top, formatted, qualities) = MovieBoxProvider.parseResolutions(
        '480,1080,720,480',
      );
      expect(top, equals('1080p'));
      expect(formatted, equals('1080p • 720p • 480p'));
      expect(qualities, equals(['1080p', '720p', '480p']));
    });

    test('parseResolutions parses 4K, 720, 480', () {
      final (top, formatted, qualities) = MovieBoxProvider.parseResolutions(
        '2160,1080,720',
      );
      expect(top, equals('2160p'));
      expect(formatted, equals('2160p • 1080p • 720p'));
      expect(qualities, equals(['2160p', '1080p', '720p']));
    });

    test('parseResolutions handles single resolution', () {
      final (top, formatted, qualities) = MovieBoxProvider.parseResolutions(
        '480',
      );
      expect(top, equals('480p'));
      expect(formatted, equals('480p'));
      expect(qualities, equals(['480p']));
    });

    test(
      'parseResolutions handles null or empty input with sensible fallback',
      () {
        final (top, formatted, qualities) = MovieBoxProvider.parseResolutions(
          null,
        );
        expect(top, equals('1080p'));
        expect(formatted, equals('1080p • 720p • 480p'));
        expect(qualities, equals(['1080p', '720p', '480p']));
      },
    );

    test(
      'StreamSource serializes and deserializes availableQualities correctly',
      () {
        const source = StreamSource(
          quality: 'Auto (Up to 1080p)',
          resolution: '1080p • 720p • 480p',
          format: 'DASH',
          url: 'https://example.com/manifest.mpd',
          availableQualities: ['1080p', '720p', '480p'],
        );

        final json = source.toJson();
        expect(json['availableQualities'], equals(['1080p', '720p', '480p']));

        final restored = StreamSource.fromJson(json);
        expect(restored.quality, equals('Auto (Up to 1080p)'));
        expect(restored.availableQualities, equals(['1080p', '720p', '480p']));
      },
    );

    test('StreamSource copyWith correctly modifies quality and fields', () {
      const source = StreamSource(
        quality: 'Auto (Up to 1080p)',
        resolution: '1080p • 720p • 480p',
        format: 'DASH',
        url: 'https://example.com/manifest.mpd',
        availableQualities: ['1080p', '720p', '480p'],
      );

      final updated = source.copyWith(quality: '720p');
      expect(updated.quality, equals('720p'));
      expect(updated.resolution, equals('1080p • 720p • 480p'));
      expect(updated.format, equals('DASH'));
      expect(updated.url, equals('https://example.com/manifest.mpd'));
      expect(updated.availableQualities, equals(['1080p', '720p', '480p']));
    });
  });
}
