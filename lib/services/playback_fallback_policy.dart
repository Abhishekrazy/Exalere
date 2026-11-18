import '../models/video_decoder_mode.dart';

/// What went wrong with playback, as far as the player can tell.
enum PlaybackFailureKind {
  /// The decoder itself failed: no codec, hardware decoder rejected the stream,
  /// or frames could not be produced. Only this class is worth a software retry.
  decoder,

  /// The stream could not be fetched: DNS, TLS, timeout, 4xx/5xx, EOF.
  network,

  /// The container or format is unreadable for mpv, or the URL is not media.
  container,

  none,
  unknown,
}

/// Decides when to retry a failed playback on the CPU decoder.
///
/// Vega solves this with its player-engine layer (ExoPlayer decoder selection).
/// We use libmpv, where the fix is to reopen the same file with `hwdec=no`. That
/// is cheap once, and harmful in a loop: reopening forever would turn one broken
/// stream into a thrashing TV, so the policy allows exactly one software retry
/// per playback and reports a real error after it.
class PlaybackFallbackPolicy {
  PlaybackFallbackPolicy({
    required this.decoderMode,
    required this.isLive,
    this.maxSoftwareRetries = 1,
  });

  /// The user's decoder setting at player creation.
  final VideoDecoderMode decoderMode;

  /// Live TV has no resume position, but it has the same risk of a broken
  /// hardware decoder, so a retry is still allowed — it just restarts at the
  /// live edge.
  final bool isLive;

  final int maxSoftwareRetries;

  int _softwareRetries = 0;

  int get softwareRetries => _softwareRetries;

  bool get hasRetriedWithSoftware => _softwareRetries >= maxSoftwareRetries;

  /// True when a message describes a decoder problem rather than a network one.
  ///
  /// mpv's messages are free text, so this is a keyword classifier, not a
  /// parser. Unknown messages stay [PlaybackFailureKind.unknown] and are never
  /// retried: guessing would reopen streams that are simply offline.
  static PlaybackFailureKind classify(String message) {
    final text = message.toLowerCase();
    if (text.trim().isEmpty) return PlaybackFailureKind.none;

    const decoderSignals = [
      'decoder',
      'codec',
      'hwdec',
      'mediacodec',
      'videotoolbox',
      'no suitable',
      'error decoding',
      'failed to initialize',
      'hardware',
      'avcodec',
      'lavc',
    ];
    if (decoderSignals.any(text.contains)) return PlaybackFailureKind.decoder;

    const networkSignals = [
      'timeout',
      'timed out',
      'connection',
      'connect',
      'network',
      'tls',
      'handshake',
      'http',
      'https',
      'unreachable',
      'socket',
      'eof',
      'resolve',
      '404',
      '403',
      '410',
      '500',
      '502',
      '503',
    ];
    if (networkSignals.any(text.contains)) return PlaybackFailureKind.network;

    const containerSignals = [
      'demux',
      'format',
      'recognize',
      'unrecognized',
      'invalid data',
      'mp4',
      'matroska',
    ];
    if (containerSignals.any(text.contains)) {
      return PlaybackFailureKind.container;
    }

    return PlaybackFailureKind.unknown;
  }

  /// Whether an explicit error message should trigger one software retry.
  ///
  /// Software decoding is already active: retrying would change nothing.
  bool shouldRetryWithSoftware(String message) {
    if (decoderMode == VideoDecoderMode.software) return false;
    if (hasRetriedWithSoftware) return false;
    return classify(message) == PlaybackFailureKind.decoder;
  }

  /// Whether a playback that never produced a frame should be retried on the
  /// CPU.
  ///
  /// A silent stall is not an error message — a broken hardware decoder often
  /// just produces nothing — so it cannot be classified, and without this the TV
  /// sits on a spinner forever. It is only retried while hardware decoding could
  /// still be the cause.
  bool shouldRetryStalledPlayback() {
    if (decoderMode == VideoDecoderMode.software) return false;
    return !hasRetriedWithSoftware;
  }

  /// Records that the one allowed software retry was spent.
  void recordSoftwareRetry() {
    _softwareRetries++;
  }
}
