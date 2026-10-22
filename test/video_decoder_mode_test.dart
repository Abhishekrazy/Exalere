import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/video_decoder_mode.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoDecoderMode', () {
    test('defaults to auto for unknown or missing stored values', () {
      expect(VideoDecoderMode.fromStorage(null), VideoDecoderMode.auto);
      expect(VideoDecoderMode.fromStorage('nonsense'), VideoDecoderMode.auto);
      expect(VideoDecoderMode.fromStorage('auto'), VideoDecoderMode.auto);
      expect(
        VideoDecoderMode.fromStorage('hardware'),
        VideoDecoderMode.hardware,
      );
      expect(
        VideoDecoderMode.fromStorage('software'),
        VideoDecoderMode.software,
      );
    });

    test('maps each mode onto an mpv hwdec value', () {
      // Software must actually disable hardware decoding, otherwise the option
      // would not fix the green/stuttering video it exists for.
      expect(VideoDecoderMode.software.mpvHwdec, 'no');
      expect(VideoDecoderMode.software.usesHardwareAcceleration, isFalse);

      expect(VideoDecoderMode.auto.mpvHwdec, 'auto-safe');
      expect(VideoDecoderMode.auto.usesHardwareAcceleration, isTrue);

      expect(VideoDecoderMode.hardware.usesHardwareAcceleration, isTrue);
      expect(VideoDecoderMode.hardware.mpvHwdec, isNotEmpty);
    });

    test('short label stays compact for badges', () {
      expect(VideoDecoderMode.auto.shortLabel, 'Auto');
      expect(VideoDecoderMode.auto.label, contains('Recommended'));
      expect(
        VideoDecoderMode.auto.shortLabel.length,
        lessThan(VideoDecoderMode.auto.label.length),
      );
    });

    test('every mode has a label and a description', () {
      for (final mode in VideoDecoderMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });
  });

  group('StorageService video decoder persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to auto on a fresh install', () async {
      expect(
        await StorageService().getVideoDecoderMode(),
        VideoDecoderMode.auto,
      );
    });

    test('round-trips every mode', () async {
      final storage = StorageService();
      for (final mode in VideoDecoderMode.values) {
        await storage.setVideoDecoderMode(mode);
        expect(await storage.getVideoDecoderMode(), mode);
      }
    });
  });

  group('AppProvider video decoder setting', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts on auto and notifies only on an actual change', () async {
      final app = AppProvider();
      expect(app.videoDecoderMode, VideoDecoderMode.auto);

      var notifications = 0;
      app.addListener(() => notifications++);

      await app.setVideoDecoderMode(VideoDecoderMode.auto);
      expect(notifications, 0, reason: 'setting the same value is a no-op');

      await app.setVideoDecoderMode(VideoDecoderMode.software);
      expect(app.videoDecoderMode, VideoDecoderMode.software);
      expect(notifications, 1);

      expect(
        await StorageService().getVideoDecoderMode(),
        VideoDecoderMode.software,
      );
    });
  });
}
