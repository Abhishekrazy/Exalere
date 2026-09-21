import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for managing video playback disk-backed stream caching.
///
/// Configures `libmpv` to use a dedicated 500 MB forward disk cache to prevent
/// memory exhaustion on low-RAM Android TV devices while providing multi-minute
/// ahead buffering for high-bitrate 1080p and 4K streams.
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

  /// 500 MB maximum forward demuxer cache ceiling.
  static const int kMaxCacheSizeBytes = 500 * 1024 * 1024;

  /// 50 MB backward demuxer cache ceiling (allows instant rewinding).
  static const int kMaxBackCacheSizeBytes = 50 * 1024 * 1024;

  /// 300 seconds (5 minutes) maximum proactive readahead window.
  static const int kReadaheadSeconds = 300;

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

  /// Returns the libmpv property configuration map for 500 MB disk caching
  /// and stream connection resiliency.
  Map<String, String> getMpvCacheProperties() {
    return {
      'cache': 'yes',
      'cache-on-disk': 'yes',
      'demuxer-cache-dir': cacheDirectoryPath,
      'demuxer-max-bytes': '$kMaxCacheSizeBytes',
      'demuxer-max-back-bytes': '$kMaxBackCacheSizeBytes',
      'demuxer-readahead-secs': '$kReadaheadSeconds',
      'cache-secs': '$kReadaheadSeconds',
      'cache-pause': 'no',
      // FFmpeg/libavformat options for stream resilience:
      // - seg_max_retry=5: retry failed HLS segments
      // - reconnect=1: auto reconnect dropped HTTP connections
      // - reconnect_streamed=1: auto reconnect live/progressive streams
      // - reconnect_delay_max=5: max reconnect backoff delay in seconds
      'demuxer-lavf-o': 'seg_max_retry=5,strict=experimental,allowed_extensions=ALL,reconnect=1,reconnect_streamed=1,reconnect_delay_max=5',
    };
  }
}
