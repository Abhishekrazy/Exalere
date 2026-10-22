import 'dart:io';

/// How the player decodes video.
///
/// Exposed because the right answer depends on the device: hardware decoding
/// saves battery and handles 4K, but some Android TV boxes and older phones
/// produce green frames or stutter on it, and only software decoding fixes that.
enum VideoDecoderMode {
  /// Let mpv's safe auto-detection choose. Correct for almost everyone.
  auto,

  /// Force the platform hardware decoder (MediaCodec on Android).
  hardware,

  /// Force software decoding. Slower and heavier on battery, but the reliable
  /// fallback when a device's hardware decoder is broken.
  software;

  static const String _storageKeyValue = 'video_decoder_mode_v1';

  /// Stable value used for persistence.
  String get storageValue => name;

  String get label {
    switch (this) {
      case VideoDecoderMode.auto:
        return 'Auto (Recommended)';
      case VideoDecoderMode.hardware:
        return 'Hardware';
      case VideoDecoderMode.software:
        return 'Software';
    }
  }

  /// Compact form for badges next to a setting, where [label] is too long.
  String get shortLabel {
    switch (this) {
      case VideoDecoderMode.auto:
        return 'Auto';
      case VideoDecoderMode.hardware:
        return 'Hardware';
      case VideoDecoderMode.software:
        return 'Software';
    }
  }

  String get description {
    switch (this) {
      case VideoDecoderMode.auto:
        return 'Let the player pick the best decoder for this device';
      case VideoDecoderMode.hardware:
        return 'GPU decoding: smoother 4K and lower battery use';
      case VideoDecoderMode.software:
        return 'CPU decoding: use if video is green, stuttering or blank';
    }
  }

  /// Value passed to mpv's `hwdec` option.
  String get mpvHwdec {
    switch (this) {
      case VideoDecoderMode.auto:
        return 'auto-safe';
      case VideoDecoderMode.hardware:
        return Platform.isAndroid ? 'mediacodec' : 'auto-safe';
      case VideoDecoderMode.software:
        return 'no';
    }
  }

  bool get usesHardwareAcceleration => this != VideoDecoderMode.software;

  static VideoDecoderMode fromStorage(String? raw) {
    if (raw == null) return VideoDecoderMode.auto;
    for (final mode in VideoDecoderMode.values) {
      if (mode.storageValue == raw) return mode;
    }
    return VideoDecoderMode.auto;
  }

  /// Key used by [StorageService].
  static String get preferenceKey => _storageKeyValue;
}
