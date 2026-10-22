import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direct_stream_service.dart';
import 'network/network_bypass_service.dart';
import 'provider_registry.dart';
import 'video_cache_service.dart';

/// What an [DataResetService.eraseAllLocalData] call actually removed.
class DataResetResult {
  const DataResetResult({
    required this.preferencesCleared,
    required this.filesDeleted,
    required this.bytesFreed,
    required this.errors,
  });

  final bool preferencesCleared;
  final int filesDeleted;
  final int bytesFreed;
  final List<String> errors;

  bool get isClean => errors.isEmpty;

  String get formattedBytesFreed {
    if (bytesFreed >= 1024 * 1024 * 1024) {
      return '${(bytesFreed / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytesFreed >= 1024 * 1024) {
      return '${(bytesFreed / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytesFreed >= 1024) {
      return '${(bytesFreed / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytesFreed B';
  }

  String get summary {
    final parts = <String>[];
    if (preferencesCleared) parts.add('settings and lists reset');
    if (filesDeleted > 0) {
      parts.add('$filesDeleted file${filesDeleted == 1 ? '' : 's'} removed');
    }
    if (parts.isEmpty && isClean) parts.add('nothing to erase');
    if (bytesFreed > 0) parts.add('$formattedBytesFreed freed');
    if (!isClean) parts.add('${errors.length} item(s) could not be removed');
    return parts.join(' · ');
  }
}

/// Erases everything Exalere stores on this device.
///
/// Distinct from the cache-cleaning actions in storage management: those reclaim
/// space and leave you signed in with your library intact, whereas this returns
/// the app to a first-launch state. Because that is destructive and awkward to
/// undo, it reports precisely what it removed rather than a bare "done".
class DataResetService {
  DataResetService._();

  static final DataResetService instance = DataResetService._();

  /// Clears preferences, provider state, the video cache, and (optionally) every
  /// downloaded media file.
  ///
  /// Never throws: each step is attempted independently, and failures are
  /// collected so a locked file cannot leave the app half-reset with no
  /// explanation.
  Future<DataResetResult> eraseAllLocalData({
    bool deleteDownloads = true,
    Directory? downloadsDirectoryOverride,
  }) async {
    final errors = <String>[];
    var preferencesCleared = false;
    var filesDeleted = 0;
    var bytesFreed = 0;

    // 1. Stop background services FIRST. Shutting them down writes state (for
    //    example the "tunnel was enabled" flag), so doing it after the wipe would
    //    leave fresh keys behind in otherwise-empty preferences.
    try {
      await NetworkBypassService.instance.shutdown();
    } catch (e) {
      errors.add('Network bypass: $e');
    }

    // 2. Preferences and persisted lists (library, history, profiles, settings).
    try {
      final prefs = await SharedPreferences.getInstance();
      preferencesCleared = await prefs.clear();
    } catch (e) {
      errors.add('Preferences: $e');
    }

    // 3. In-memory provider state, so no uninstalled engine keeps answering.
    try {
      ProviderRegistry().clearAll();
    } catch (e) {
      errors.add('Providers: $e');
    }

    // 4. Video stream buffer.
    try {
      await VideoCacheService.instance.clearCache();
    } catch (e) {
      errors.add('Video cache: $e');
    }

    // 4. Downloaded media files.
    if (deleteDownloads) {
      try {
        final dir =
            downloadsDirectoryOverride ??
            await DirectStreamService.instance.getDownloadsDirectory();
        if (await dir.exists()) {
          await for (final entity in dir.list(followLinks: false)) {
            try {
              if (entity is File) {
                final size = await entity.length();
                await entity.delete();
                filesDeleted++;
                bytesFreed += size;
              } else if (entity is Directory) {
                final size = await _directorySize(entity);
                await entity.delete(recursive: true);
                filesDeleted++;
                bytesFreed += size;
              }
            } catch (e) {
              errors.add(
                '${entity.path.split(Platform.pathSeparator).last}: $e',
              );
            }
          }
        }
      } catch (e) {
        errors.add('Downloads folder: $e');
      }
    }

    final result = DataResetResult(
      preferencesCleared: preferencesCleared,
      filesDeleted: filesDeleted,
      bytesFreed: bytesFreed,
      errors: errors,
    );

    if (!result.isClean) {
      debugPrint('[DataResetService] Partial erase: ${errors.join('; ')}');
    }
    return result;
  }

  static Future<int> _directorySize(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }
}
