import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/video_decoder_mode.dart';
import 'package:exalere/services/playback_fallback_policy.dart';
import 'package:exalere/services/playback_profile.dart';

void main() {
  group('PlaybackFallbackPolicy.classify', () {
    test('recognises decoder failures', () {
      for (final message in [
        'Could not open codec.',
        'Failed to initialize a decoder.',
        'error decoding video',
        'No suitable decoder found',
        'hwdec: mediacodec-copy failed',
        'vd-lavc: hardware decoder rejected the stream',
      ]) {
        expect(
          PlaybackFallbackPolicy.classify(message),
          PlaybackFailureKind.decoder,
          reason: message,
        );
      }
    });

    test('recognises network failures', () {
      for (final message in [
        'Connection timed out',
        'HTTP error 503',
        'TLS handshake failed',
        'Could not resolve host',
        'unexpected EOF',
      ]) {
        expect(
          PlaybackFallbackPolicy.classify(message),
          PlaybackFailureKind.network,
          reason: message,
        );
      }
    });

    test('recognises container failures', () {
      for (final message in [
        'Failed to recognize file format',
        'demuxer error: invalid data',
      ]) {
        expect(
          PlaybackFallbackPolicy.classify(message),
          PlaybackFailureKind.container,
          reason: message,
        );
      }
    });

    test('leaves unknown and empty messages alone', () {
      expect(
        PlaybackFallbackPolicy.classify('something odd happened'),
        PlaybackFailureKind.unknown,
      );
      expect(PlaybackFallbackPolicy.classify('   '), PlaybackFailureKind.none);
    });
  });

  group('PlaybackFallbackPolicy retry rules', () {
    test('retries a decoder failure once on a hardware path', () {
      final policy = PlaybackFallbackPolicy(
        decoderMode: VideoDecoderMode.hardware,
        isLive: false,
      );

      expect(policy.shouldRetryWithSoftware('Could not open codec'), isTrue);
      policy.recordSoftwareRetry();
      expect(policy.hasRetriedWithSoftware, isTrue);
      expect(
        policy.shouldRetryWithSoftware('Could not open codec'),
        isFalse,
        reason: 'one retry only: reopening forever would thrash the device',
      );
    });

    test('never retries a network failure', () {
      final policy = PlaybackFallbackPolicy(
        decoderMode: VideoDecoderMode.auto,
        isLive: false,
      );

      expect(policy.shouldRetryWithSoftware('HTTP error 404'), isFalse);
      expect(policy.shouldRetryWithSoftware('Connection reset'), isFalse);
    });

    test('never retries when software decoding is already forced', () {
      final policy = PlaybackFallbackPolicy(
        decoderMode: VideoDecoderMode.software,
        isLive: false,
      );

      expect(policy.shouldRetryWithSoftware('Could not open codec'), isFalse);
      expect(policy.shouldRetryStalledPlayback(), isFalse);
    });

    test('a silent stall is retried once while hardware may be the cause', () {
      final policy = PlaybackFallbackPolicy(
        decoderMode: VideoDecoderMode.hardware,
        isLive: false,
      );

      expect(policy.shouldRetryStalledPlayback(), isTrue);
      policy.recordSoftwareRetry();
      expect(policy.shouldRetryStalledPlayback(), isFalse);
    });

    test('live playback may still retry, at the live edge', () {
      final policy = PlaybackFallbackPolicy(
        decoderMode: VideoDecoderMode.hardware,
        isLive: true,
      );

      expect(
        policy.shouldRetryWithSoftware('Failed to initialize a decoder'),
        isTrue,
        reason: 'a broken hardware decoder is just as broken on live TV',
      );
    });
  });

  group('PlaybackProfile', () {
    test(
      'trims decoder threads and drops late frames on low-power devices',
      () {
        final profile = PlaybackProfile.resolve(
          decoderMode: VideoDecoderMode.auto,
          isTvMode: true,
          is32BitOrLowRam: true,
        );

        expect(profile.decoderThreads, 2);
        expect(profile.framedrop, 'decoder+vo');
        expect(profile.mpvProperties['vd-lavc-threads'], '2');
        expect(profile.mpvProperties['framedrop'], 'decoder+vo');
        expect(profile.mpvProperties['vd-lavc-software-fallback'], 'yes');
        expect(profile.mpvProperties['video-sync'], 'audio');
      },
    );

    test('full-size devices keep the gentler frame-drop policy', () {
      final profile = PlaybackProfile.resolve(
        decoderMode: VideoDecoderMode.hardware,
        isTvMode: false,
        is32BitOrLowRam: false,
      );

      expect(profile.decoderThreads, 4);
      expect(profile.framedrop, 'vo');
    });

    test('never overrides the user\'s decoder choice on the normal path', () {
      for (final mode in VideoDecoderMode.values) {
        final profile = PlaybackProfile.resolve(
          decoderMode: mode,
          isTvMode: false,
          is32BitOrLowRam: false,
        );
        expect(
          profile.mpvProperties.containsKey('hwdec'),
          isFalse,
          reason:
              'hwdec belongs to the controller; overriding it here would make '
              'the VideoDecoderMode setting lie',
        );
      }
    });

    test(
      'the software retry forces CPU decoding regardless of the setting',
      () {
        final profile = PlaybackProfile.resolve(
          decoderMode: VideoDecoderMode.hardware,
          isTvMode: true,
          is32BitOrLowRam: false,
        );

        expect(profile.softwareDecodeProperties['hwdec'], 'no');
        expect(
          profile.softwareDecodeProperties['vd-lavc-software-fallback'],
          'yes',
        );
      },
    );
  });
}
