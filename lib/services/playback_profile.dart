import '../models/video_decoder_mode.dart';

/// libmpv options chosen for this device class.
///
/// The cache map in `VideoCacheService` answers "how much should be buffered".
/// This answers the other half of "why does the picture stutter": how many
/// threads decode, whether frames may be dropped when the decoder falls behind,
/// and whether mpv is allowed to fall back to software on its own. Keeping it a
/// value object means the choice can be tested without a player or a TV.
class PlaybackProfile {
  const PlaybackProfile({
    required this.decoderMode,
    required this.isTv,
    required this.isLowPower,
    required this.decoderThreads,
    required this.framedrop,
    required this.videoSync,
  });

  /// The user's decoder choice. Hardware/software is still theirs to make; this
  /// profile only tunes around it.
  final VideoDecoderMode decoderMode;

  final bool isTv;
  final bool isLowPower;

  /// `vd-lavc-threads`. Low-power boxes do worse with more threads than cores:
  /// contention makes them drop frames, not decode faster.
  final int decoderThreads;

  /// `framedrop`. `decoder+vo` lets mpv discard late frames before rendering,
  /// which keeps audio in sync on a TV that cannot keep up. Desktop and phones
  /// keep the gentler `vo` policy.
  final String framedrop;

  /// `video-sync`. Audio-mastered sync is what every platform player does and
  /// keeps the remote's seek and pause behaviour predictable.
  final String videoSync;

  /// Resolves the profile for the current device.
  factory PlaybackProfile.resolve({
    required VideoDecoderMode decoderMode,
    required bool isTvMode,
    required bool is32BitOrLowRam,
  }) {
    return PlaybackProfile(
      decoderMode: decoderMode,
      isTv: isTvMode,
      isLowPower: is32BitOrLowRam,
      decoderThreads: is32BitOrLowRam ? 2 : 4,
      framedrop: (isTvMode || is32BitOrLowRam) ? 'decoder+vo' : 'vo',
      videoSync: 'audio',
    );
  }

  /// Options applied to the native player before the file is opened.
  ///
  /// Deliberately excludes `hwdec`: the user's [VideoDecoderMode] is applied by
  /// the controller, and changing it behind their back here would make the
  /// setting lie.
  Map<String, String> get mpvProperties => {
    'vd-lavc-threads': '$decoderThreads',
    'vd-lavc-software-fallback': 'yes',
    'framedrop': framedrop,
    'video-sync': videoSync,
  };

  /// Options used when retrying a failed hardware decode on the CPU.
  ///
  /// No hardware decoder is left enabled: the retry exists precisely because the
  /// hardware path is not working on this device.
  Map<String, String> get softwareDecodeProperties => {
    ...mpvProperties,
    'hwdec': 'no',
    'vd-lavc-software-fallback': 'yes',
    // The CPU is now doing all the work, so give it the full thread budget even
    // on a box whose profile normally trims it.
    'vd-lavc-threads': '${isLowPower ? 2 : 4}',
  };
}
