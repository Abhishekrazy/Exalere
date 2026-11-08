/// Works out the quality label to show on the player.
///
/// The label must describe what is *actually* being decoded, not what the source
/// claimed it would be: providers routinely advertise `1080p` and serve a 720p
/// file, and an HLS variant can switch mid-stream. The order of preference is
/// therefore
///
/// 1. the decoded frame size (the player's video state),
/// 2. the source's own quality string, only before the first frame is decoded.
///
/// Anything that does not identify a resolution (`HLS`, `HD`, `Auto`, `Local`) is
/// deliberately not treated as one — showing "HD" beside a 720p stream is the
/// same lie in a smaller font.
library;

import 'package:media_kit/media_kit.dart';

class PlaybackQuality {
  const PlaybackQuality._();

  /// Heights the label is allowed to say, matching the broadcast ladder.
  static const List<int> standards = [
    144,
    240,
    360,
    480,
    576,
    720,
    1080,
    1440,
    2160,
    4320,
  ];

  /// Snaps a decoded frame size to the nearest standard height.
  ///
  /// Cropped widescreen frames report a shorter height than their nominal
  /// quality (a 1920x800 scope encode of a 1080p source), so the retained width
  /// decides the class for those; portrait video uses its long edge.
  static int? heightFor({int? width, int? height}) {
    final h = (height ?? 0) > 0 ? height! : 0;
    if (h == 0) return null;
    final w = (width ?? 0) > 0 ? width! : 0;

    final resolution = w > 0
        ? [
            w < h ? w : h,
            (w > h ? w : h) * 9 / 16,
          ].reduce((a, b) => a > b ? a : b)
        : h.toDouble();

    var nearest = standards.first;
    for (final candidate in standards) {
      if ((candidate - resolution).abs() < (nearest - resolution).abs()) {
        nearest = candidate;
      }
    }
    return nearest;
  }

  /// Parses a source quality string into a standard height, or null.
  ///
  /// Accepts `1080p`, `720`, `2160p60`, `4K`/`2K`/`8K` and `1920x1080`.
  static int? heightFromSource(String? raw) {
    final quality = (raw ?? '').trim();
    if (quality.isEmpty) return null;

    final dimensions = RegExp(
      r'\b(\d{2,5})\s*[x×]\s*(\d{2,5})\b',
      caseSensitive: false,
    ).firstMatch(quality);
    if (dimensions != null) {
      return heightFor(
        width: int.parse(dimensions.group(1)!),
        height: int.parse(dimensions.group(2)!),
      );
    }

    final pixels = RegExp(
      r'^(\d{3,4})p?\d*$',
      caseSensitive: false,
    ).firstMatch(quality);
    if (pixels != null) return heightFor(height: int.parse(pixels.group(1)!));

    final k = RegExp(r'^(2|4|8)k$', caseSensitive: false).firstMatch(quality);
    if (k != null) {
      return switch (k.group(1)) {
        '2' => 1440,
        '4' => 2160,
        _ => 4320,
      };
    }
    return null;
  }

  /// Removes duplicate video renditions from a track list.
  ///
  /// mpv reports the same format several times when a container declares it in
  /// more than one group, which turns the quality list into several identical
  /// rows. Entries are keyed by `width x height : bitrate`; when a duplicate is
  /// found the currently active copy is kept so the selected row stays selected.
  static List<VideoTrack> dedupeVideoTracks(
    List<VideoTrack> tracks, {
    VideoTrack? active,
  }) {
    final byKey = <String, VideoTrack>{};
    for (final track in tracks) {
      final key = '${track.w}x${track.h}:${track.bitrate}';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = track;
        continue;
      }
      if (active != null && track.id == active.id) byKey[key] = track;
    }
    return byKey.values.toList();
  }

  /// The label for the quality half of the source pill.
  ///
  /// Returns null when nothing usable is known, so callers can leave it out of
  /// the pill instead of printing a placeholder.
  static String? label({
    int? decodedWidth,
    int? decodedHeight,
    String? sourceQuality,
  }) {
    final decoded = heightFor(width: decodedWidth, height: decodedHeight);
    if (decoded != null) return '${decoded}p';

    final source = heightFromSource(sourceQuality);
    if (source != null) return '${source}p';

    // Non-resolution metadata: keep something short and honest rather than
    // inventing a number.
    final raw = (sourceQuality ?? '').trim();
    if (raw.isEmpty) return null;
    if (raw.length <= 12) return raw;
    return null;
  }
}
