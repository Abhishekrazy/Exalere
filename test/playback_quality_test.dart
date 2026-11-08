import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:exalere/ui/screens/player/playback_quality.dart';

/// The pill must describe what is actually decoded. These cases come from real
/// provider behaviour: a stream labelled 1080p that serves 720p, a scope encode
/// whose frame is shorter than its class, and metadata that is not a resolution
/// at all.
void main() {
  group('heightFor', () {
    test('snaps decoded frames to the standard ladder', () {
      expect(PlaybackQuality.heightFor(width: 1280, height: 720), 720);
      expect(PlaybackQuality.heightFor(width: 1920, height: 1080), 1080);
      expect(PlaybackQuality.heightFor(width: 3840, height: 2160), 2160);
      expect(PlaybackQuality.heightFor(width: 640, height: 360), 360);
    });

    test('classifies cropped widescreen encodes by retained width', () {
      // A 1920x800 scope print is a 1080p class encode, not 720p.
      expect(PlaybackQuality.heightFor(width: 1920, height: 800), 1080);
      expect(PlaybackQuality.heightFor(width: 1280, height: 536), 720);
    });

    test('classifies portrait video by its short edge', () {
      // A 1080x1920 vertical clip is full-HD class, not 2160p: the retained
      // short edge names the class, the same rule the reference implementation
      // applies to cropped widescreen frames.
      expect(PlaybackQuality.heightFor(width: 1080, height: 1920), 1080);
    });

    test('returns null when nothing is decoded', () {
      expect(PlaybackQuality.heightFor(width: null, height: null), isNull);
      expect(PlaybackQuality.heightFor(width: 0, height: 0), isNull);
    });
  });

  group('heightFromSource', () {
    test('parses the labels providers actually use', () {
      expect(PlaybackQuality.heightFromSource('1080p'), 1080);
      expect(PlaybackQuality.heightFromSource('2160p'), 2160);
      expect(PlaybackQuality.heightFromSource('720'), 720);
      expect(PlaybackQuality.heightFromSource('4K'), 2160);
      expect(PlaybackQuality.heightFromSource('1920x1080'), 1080);
      expect(PlaybackQuality.heightFromSource('1080p60'), 1080);
    });

    test('refuses labels that are not resolutions', () {
      expect(PlaybackQuality.heightFromSource('HLS'), isNull);
      expect(PlaybackQuality.heightFromSource('HD'), isNull);
      expect(PlaybackQuality.heightFromSource('Auto'), isNull);
      expect(PlaybackQuality.heightFromSource(''), isNull);
      expect(PlaybackQuality.heightFromSource(null), isNull);
    });
  });

  group('label', () {
    test('decoded resolution wins over the advertised one', () {
      expect(
        PlaybackQuality.label(
          decodedWidth: 1280,
          decodedHeight: 720,
          sourceQuality: '1080p',
        ),
        '720p',
      );
    });

    test('falls back to source metadata before the first frame', () {
      expect(
        PlaybackQuality.label(
          decodedWidth: 0,
          decodedHeight: 0,
          sourceQuality: '1080p',
        ),
        '1080p',
      );
    });

    test('keeps a short honest label when neither side is a resolution', () {
      expect(PlaybackQuality.label(sourceQuality: 'HLS'), 'HLS');
      expect(PlaybackQuality.label(sourceQuality: null), isNull);
    });
  });
  group('dedupeVideoTracks', () {
    VideoTrack track(String id, int w, int h, int bitrate) =>
        VideoTrack(id, id, 'eng', w: w, h: h, bitrate: bitrate);

    test('collapses identical renditions and keeps the active copy', () {
      final a = track('1', 1920, 1080, 5000);
      final duplicate = track('2', 1920, 1080, 5000);
      final other = track('3', 1280, 720, 2500);

      final deduped = PlaybackQuality.dedupeVideoTracks([
        a,
        duplicate,
        other,
      ], active: duplicate);

      expect(deduped.length, 2);
      expect(deduped.first.id, '2', reason: 'the selected copy must survive');
      expect(deduped.last.id, '3');
    });

    test('keeps renditions that differ only by bitrate', () {
      final low = track('1', 1920, 1080, 3000);
      final high = track('2', 1920, 1080, 8000);

      expect(PlaybackQuality.dedupeVideoTracks([low, high]).length, 2);
    });
  });
}
