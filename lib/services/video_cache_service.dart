import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for managing video playback disk-backed stream caching.
///
/// Configures `libmpv` with adaptive RAM caching:
/// - 64-bit systems: 128 MB forward cache / 32 MB backward cache / 180s readahead
/// - 32-bit / ARMv7 systems: 32 MB forward cache / 8 MB backward cache / 60s readahead
/// to prevent memory exhaustion on 1 GB RAM Android TV devices while providing
/// smooth ahead buffering for high-bitrate 1080p and 4K streams.
///
/// Manages the lifecycle of cache files:
/// - Clears cache if a different video is played than the last one.
/// - Clears cache when the video completes.
/// - Clears cache when the player is closed / not playing.
/// - Cleans orphaned cache files on app startup.
class VideoCacheService {
  static final VideoCacheService _instance = VideoCacheService._internal();
  static VideoCacheService get instance => _instance;

  VideoCacheService._internal();

  static const MethodChannel _tvChannel = MethodChannel('com.exalere/tv_mode');

  /// 128 MB maximum forward demuxer RAM cache ceiling for 64-bit systems.
  static const int kMaxCacheSizeBytes = 128 * 1024 * 1024;
  static const int kMaxCacheSizeBytes64 = 128 * 1024 * 1024;

  /// 32 MB maximum forward demuxer RAM cache ceiling for 32-bit / ARMv7 systems.
  static const int kMaxCacheSizeBytes32 = 32 * 1024 * 1024;

  /// 32 MB backward demuxer cache ceiling for 64-bit systems.
  static const int kMaxBackCacheSizeBytes = 32 * 1024 * 1024;
  static const int kMaxBackCacheSizeBytes64 = 32 * 1024 * 1024;

  /// 8 MB backward demuxer cache ceiling for 32-bit / ARMv7 systems.
  static const int kMaxBackCacheSizeBytes32 = 8 * 1024 * 1024;

  /// 180 seconds (3 minutes) maximum proactive readahead window for 64-bit systems.
  static const int kReadaheadSeconds = 180;
  static const int kReadaheadSeconds64 = 180;

  /// 60 seconds (1 minute) maximum proactive readahead window for 32-bit / ARMv7 systems.
  static const int kReadaheadSeconds32 = 60;

  /// 16 MB maximum RAM cache ceiling for Live TV streams (~1 minute forward buffer).
  static const int kMaxLiveCacheSizeBytes = 16 * 1024 * 1024;

  /// 60 seconds (1 minute) maximum forward readahead for Live TV streams.
  static const int kLiveReadaheadSeconds = 60;

  bool? _is32BitOverride;

  /// Allows overriding 32-bit detection in unit tests.
  @visibleForTesting
  void set32BitOverride(bool? value) {
    _is32BitOverride = value;
  }

  /// Returns `true` if running as a 32-bit process (e.g. ARMv7 / armeabi-v7a).
  bool get is32BitOrLowRam {
    if (_is32BitOverride != null) return _is32BitOverride!;
    if (kIsWeb) return false;
    try {
      final currentAbi = Abi.current();
      return currentAbi == Abi.androidArm;
    } catch (_) {
      return false;
    }
  }

  /// Optimal forward cache budget based on device architecture.
  int get maxCacheSizeBytes =>
      is32BitOrLowRam ? kMaxCacheSizeBytes32 : kMaxCacheSizeBytes64;

  /// Optimal backward cache budget based on device architecture.
  int get maxBackCacheSizeBytes =>
      is32BitOrLowRam ? kMaxBackCacheSizeBytes32 : kMaxBackCacheSizeBytes64;

  /// Optimal readahead window in seconds based on device architecture.
  int get readaheadSeconds =>
      is32BitOrLowRam ? kReadaheadSeconds32 : kReadaheadSeconds64;

  /// Tracks the last played media key (e.g. "movie_123" or "show_456_s1_e2").
  String? _lastPlayedMediaKey;
  String? get lastPlayedMediaKey => _lastPlayedMediaKey;

  String? _customCacheDirPath;

  /// Sets an explicit custom cache directory path (used in unit tests or overrides).
  @visibleForTesting
  void setCustomCacheDirPath(String? path) {
    _customCacheDirPath = path;
  }

  /// Root directory dedicated to streaming video cache files.
  Directory get cacheDirectory {
    if (_customCacheDirPath != null) {
      return Directory(_customCacheDirPath!);
    }
    final sep = Platform.pathSeparator;
    return Directory('${Directory.systemTemp.path}${sep}exalere_video_cache');
  }

  /// Path to the dedicated video cache directory.
  String get cacheDirectoryPath => cacheDirectory.path;

  /// Ensures the video cache directory exists and resolves native Android cache path if applicable.
  Future<Directory> ensureCacheDirectory() async {
    if (_customCacheDirPath == null && !kIsWeb && Platform.isAndroid) {
      try {
        final path = await _tvChannel.invokeMethod<String>('getVideoCacheDir');
        if (path != null && path.isNotEmpty) {
          _customCacheDirPath = path;
        }
      } catch (e) {
        debugPrint('VideoCacheService: getVideoCacheDir channel error: $e');
      }
    }

    final dir = cacheDirectory;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns whether the cache should be cleared for a new video.
  /// If the current video key differs from the last played video,
  /// returns `true` and updates the internal tracked key.
  bool shouldClearForNewVideo(String currentMediaKey) {
    if (_lastPlayedMediaKey == null) {
      _lastPlayedMediaKey = currentMediaKey;
      return true;
    }
    if (_lastPlayedMediaKey != currentMediaKey) {
      _lastPlayedMediaKey = currentMediaKey;
      return true;
    }
    return false;
  }

  /// Marks the current video key as active without checking.
  void setActiveMediaKey(String currentMediaKey) {
    _lastPlayedMediaKey = currentMediaKey;
  }

  /// Resets the last played media key.
  void resetActiveMediaKey() {
    _lastPlayedMediaKey = null;
  }

  /// Deletes all files within the video cache directory.
  /// Handles file locking gracefully and retries once after a brief delay if needed.
  Future<void> clearCache({bool retryOnLocked = true}) async {
    try {
      final dir = await ensureCacheDirectory();
      if (!await dir.exists()) return;

      final entities = dir.listSync(recursive: false);
      for (final entity in entities) {
        try {
          if (await entity.exists()) {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          }
        } catch (e) {
          // File may be temporarily held by libmpv demuxer during closure
          debugPrint(
            'VideoCacheService: Notice deleting cache item ${entity.path}: $e',
          );
        }
      }

      // If any files remain and retry is enabled, schedule a deferred cleanup pass
      if (retryOnLocked) {
        Future.delayed(const Duration(milliseconds: 600), () async {
          try {
            if (await dir.exists()) {
              final remaining = dir.listSync();
              for (final f in remaining) {
                try {
                  if (f is File) {
                    await f.delete();
                  } else if (f is Directory) {
                    await f.delete(recursive: true);
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('VideoCacheService: clearCache error: $e');
    }
  }

  /// Calculates the total size in bytes of all files currently in the cache directory.
  Future<int> getCacheSizeBytes() async {
    try {
      final dir = await ensureCacheDirectory();
      if (!await dir.exists()) return 0;

      int total = 0;
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (e) {
      debugPrint('VideoCacheService: getCacheSizeBytes error: $e');
      return 0;
    }
  }

  /// Returns the libmpv property configuration map with architecture-adaptive RAM caching
  /// (128 MB on 64-bit / 32 MB on 32-bit ARMv7) and connection resiliency.
  ///
  /// For Live TV ([isLive] == true), caches strictly in RAM with a maximum 16 MB forward
  /// buffer (1 minute ahead), ZERO backward cache (to eliminate storage/memory bloat),
  /// and disables seeking to lock playback to the real-time live edge.
  Map<String, String> getMpvCacheProperties({bool isLive = false}) {
    if (isLive) {
      return {
        'cache': 'yes',
        // Stream strictly in RAM - zero disk write
        'cache-on-disk': 'no',
        'demuxer-max-bytes': '$kMaxLiveCacheSizeBytes',
        // Zero backward cache: discard played chunks immediately to prevent storage bloat
        'demuxer-max-back-bytes': '0',
        'demuxer-readahead-secs': '$kLiveReadaheadSeconds',
        'cache-secs': '$kLiveReadaheadSeconds',
        // Responsive live buffering without lagging behind broadcast edge
        'cache-pause': 'yes',
        'cache-pause-initial': 'yes',
        'cache-pause-wait': '3',
        'force-seekable': 'no',
        'hr-seek': 'no',
        'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_on_http_error=4xx,5xx,reconnect_on_network_error=1,reconnect_delay_max=5,multiple_requests=1',
        'demuxer-lavf-o': 'seg_max_retry=5,strict=experimental,allowed_extensions=ALL,reconnect=1,reconnect_streamed=1,reconnect_on_http_error=4xx,5xx,reconnect_on_network_error=1,reconnect_delay_max=5,multiple_requests=1',
      };
    }

    final forwardBytes = maxCacheSizeBytes;
    final backBytes = maxBackCacheSizeBytes;
    final readaheadSec = readaheadSeconds;

    return {
      'cache': 'yes',
      // Stream directly from high-speed RAM to eliminate flash/disk I/O latency stalls
      'cache-on-disk': 'no',
      'demuxer-max-bytes': '$forwardBytes',
      'demuxer-max-back-bytes': '$backBytes',
      'demuxer-readahead-secs': '$readaheadSec',
      'cache-secs': '$readaheadSec',
      // Buffer smoothly when buffer drops low instead of violently dropping video frames
      'cache-pause': 'yes',
      'cache-pause-initial': 'yes',
      'cache-pause-wait': '10',
      'hr-seek': 'default',
      // FFmpeg/libavformat stream-level network protocol options:
      // Enables HTTP keep-alive and robust auto-reconnection on TLS/socket drops or 4xx/5xx errors
      'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_on_http_error=4xx,5xx,reconnect_on_network_error=1,reconnect_delay_max=5,multiple_requests=1',
      // FFmpeg/libavformat demuxer-level options:
      // - seg_max_retry=5: retry failed HLS/DASH segments
      // - multiple_requests=1: keep HTTP connection open across segments
      // - reconnect flags: retry dropped or throttled CDN segment requests
      'demuxer-lavf-o': 'seg_max_retry=5,strict=experimental,allowed_extensions=ALL,reconnect=1,reconnect_streamed=1,reconnect_on_http_error=4xx,5xx,reconnect_on_network_error=1,reconnect_delay_max=5,multiple_requests=1',
    };
  }
}
