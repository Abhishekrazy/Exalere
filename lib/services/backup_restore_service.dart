import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final int profileCount;
  final int totalFavorites;
  final int totalHistoryItems;
  final String exportDate;
  final String? exportedDevice;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.profileCount = 0,
    this.totalFavorites = 0,
    this.totalHistoryItems = 0,
    this.exportDate = '',
    this.exportedDevice,
  });
}

class BackupRestoreResult {
  final bool success;
  final String message;
  final int restoredProfiles;
  final int restoredFavorites;
  final int restoredHistory;

  const BackupRestoreResult({
    required this.success,
    required this.message,
    this.restoredProfiles = 0,
    this.restoredFavorites = 0,
    this.restoredHistory = 0,
  });
}

class BackupFileInfo {
  final String fileName;
  final String filePath;
  final DateTime modifiedTime;
  final int fileSizeBytes;
  final int profileCount;
  final int itemCount;

  const BackupFileInfo({
    required this.fileName,
    required this.filePath,
    required this.modifiedTime,
    required this.fileSizeBytes,
    this.profileCount = 0,
    this.itemCount = 0,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Standalone offline backup and restore service for Exalere.
class BackupRestoreService {
  static final BackupRestoreService _instance =
      BackupRestoreService._internal();
  factory BackupRestoreService() => _instance;
  BackupRestoreService._internal();

  final StorageService _storageService = StorageService();

  /// Resolves the storage directory for storing backup files.
  Future<Directory> getBackupDirectory() async {
    Directory dir;
    if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\';
      dir = Directory(
        '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}Exalere${Platform.pathSeparator}Backups',
      );
    } else if (!kIsWeb && Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/Exalere/Backups');
    } else {
      dir = Directory(
        '${Directory.current.path}${Platform.pathSeparator}ExalereBackups',
      );
    }

    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        debugPrint('[BackupRestoreService] Error creating backup dir: $e');
      }
    }
    return dir;
  }

  /// Creates a complete JSON-encodable backup bundle containing profiles,
  /// profile-scoped user libraries, and settings.
  Future<Map<String, dynamic>> createBackupBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _storageService.getDeviceId();
    final deviceName = await _storageService.getCustomDeviceName();
    final profiles = await _storageService.getProfiles();
    final activeProfileId = await _storageService.getActiveProfileId();

    final profileDataMap = <String, dynamic>{};
    for (final profile in profiles) {
      final favs = await _storageService.getFavorites(profileId: profile.id);
      final already = await _storageService.getAlreadyWatched(
        profileId: profile.id,
      );
      final hist = await _storageService.getWatchHistory(profileId: profile.id);
      final eps = await _storageService.getAllWatchedEpisodes(
        profileId: profile.id,
      );

      profileDataMap[profile.id] = {
        'favorites': favs.map((i) => i.toJson()).toList(),
        'alreadyWatched': already.map((i) => i.toJson()).toList(),
        'watchHistory': hist.map((h) => h.toJson()).toList(),
        'watchedEpisodes': eps.map((k, v) => MapEntry(k, v.toList())),
      };
    }

    // Capture all app settings
    final settingsMap = <String, dynamic>{};
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      // Capture preferences that are not profile-specific lists
      if (!key.startsWith('user_favorites') &&
          !key.startsWith('user_already_watched') &&
          !key.startsWith('user_watch_history') &&
          !key.startsWith('user_watched_episodes') &&
          key != 'user_profiles_list' &&
          key != 'user_active_profile_id') {
        final val = prefs.get(key);
        if (val != null) {
          settingsMap[key] = val;
        }
      }
    }

    return {
      'app': 'Exalere',
      'formatVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedDevice': {
        'id': deviceId,
        'name': deviceName ?? Platform.operatingSystem,
      },
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'activeProfileId': activeProfileId,
      'dataByProfile': profileDataMap,
      'settings': settingsMap,
    };
  }

  /// Validates the structure and content of a backup bundle.
  BackupValidationResult validateBackupBundle(Map<String, dynamic> bundle) {
    if (bundle['app'] != 'Exalere') {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Invalid file format: Not an Exalere backup bundle.',
      );
    }

    final profilesRaw = bundle['profiles'] as List<dynamic>?;
    if (profilesRaw == null || profilesRaw.isEmpty) {
      return const BackupValidationResult(
        isValid: false,
        errorMessage: 'Backup file contains no user profiles.',
      );
    }

    final rawDataByProfile = bundle['dataByProfile'];
    final dataByProfile = rawDataByProfile is Map ? rawDataByProfile : const {};
    int favCount = 0;
    int histCount = 0;

    for (final pEntry in dataByProfile.values) {
      if (pEntry is Map) {
        final favList = pEntry['favorites'] as List<dynamic>? ?? [];
        final histList = pEntry['watchHistory'] as List<dynamic>? ?? [];
        favCount += favList.length;
        histCount += histList.length;
      }
    }

    final devMap = bundle['exportedDevice'] is Map
        ? bundle['exportedDevice'] as Map
        : null;
    final devName = devMap?['name'] as String?;

    return BackupValidationResult(
      isValid: true,
      profileCount: profilesRaw.length,
      totalFavorites: favCount,
      totalHistoryItems: histCount,
      exportDate: bundle['exportedAt'] as String? ?? 'Unknown',
      exportedDevice: devName,
    );
  }

  /// Exports the backup bundle to a file on local storage.
  Future<String> exportBackupToFile({String? customFileName}) async {
    final bundle = await createBackupBundle();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);

    final dir = await getBackupDirectory();
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final fileName = customFileName ?? 'exalere_backup_$dateStr.json';
    final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    await targetFile.writeAsString(jsonStr);

    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', targetFile.path]);
      } catch (_) {}
    }

    return targetFile.path;
  }

  /// Copies the backup JSON string to system clipboard.
  Future<void> copyBackupToClipboard() async {
    final bundle = await createBackupBundle();
    final jsonStr = jsonEncode(bundle);
    await Clipboard.setData(ClipboardData(text: jsonStr));
  }

  /// Reads and validates a backup JSON bundle from system clipboard.
  Future<Map<String, dynamic>?> readBackupFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.trim().isEmpty) return null;
      final parsed = jsonDecode(data.text!.trim());
      if (parsed is Map && parsed['app'] == 'Exalere') {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (_) {}
    return null;
  }

  /// Lists available backup files saved in the local backup folder.
  Future<List<BackupFileInfo>> listLocalBackups() async {
    final dir = await getBackupDirectory();
    if (!await dir.exists()) return [];

    final result = <BackupFileInfo>[];
    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.json')) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final stat = entity.statSync();

          int pCount = 0;
          int iCount = 0;
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            if (json is Map && json['app'] == 'Exalere') {
              final val = validateBackupBundle(Map<String, dynamic>.from(json));
              pCount = val.profileCount;
              iCount = val.totalFavorites + val.totalHistoryItems;
            }
          } catch (_) {}

          result.add(
            BackupFileInfo(
              fileName: fileName,
              filePath: entity.path,
              modifiedTime: stat.modified,
              fileSizeBytes: stat.size,
              profileCount: pCount,
              itemCount: iCount,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[BackupRestoreService] Error scanning backups: $e');
    }

    result.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    return result;
  }

  /// Reads a backup file directly from [filePath].
  Future<Map<String, dynamic>?> readBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (e) {
      debugPrint('[BackupRestoreService] Error reading file: $e');
    }
    return null;
  }

  /// Restores data from [bundle].
  /// If [mergeWithExisting] is true, merges profiles, watch history, and favorites.
  /// If [mergeWithExisting] is false, completely overrides all profiles and libraries.
  Future<BackupRestoreResult> restoreBackupBundle(
    Map<String, dynamic> bundle, {
    bool mergeWithExisting = false,
  }) async {
    final validation = validateBackupBundle(bundle);
    if (!validation.isValid) {
      return BackupRestoreResult(
        success: false,
        message: validation.errorMessage ?? 'Invalid backup bundle.',
      );
    }

    final prefs = await SharedPreferences.getInstance();

    final profilesRaw = bundle['profiles'] as List<dynamic>;
    final importedProfiles = profilesRaw
        .map((p) {
          try {
            if (p is Map) {
              return UserProfile.fromJson(Map<String, dynamic>.from(p));
            }
            return null;
          } catch (_) {
            return null;
          }
        })
        .whereType<UserProfile>()
        .toList();

    if (importedProfiles.isEmpty) {
      return const BackupRestoreResult(
        success: false,
        message: 'No valid profiles found in backup.',
      );
    }

    final activeId = bundle['activeProfileId'] as String? ?? 'default';
    final rawDataByProfile = bundle['dataByProfile'];
    final dataByProfile = rawDataByProfile is Map ? rawDataByProfile : const {};

    int totalFavs = 0;
    int totalHist = 0;

    if (!mergeWithExisting) {
      // 1. Full Overwrite: save profiles
      await _storageService.saveProfiles(importedProfiles);
      await _storageService.setActiveProfileId(activeId);

      // 2. Overwrite profile scoped data
      for (final profile in importedProfiles) {
        final rawPData = dataByProfile[profile.id];
        final pData = rawPData is Map ? rawPData : null;
        if (pData != null) {
          // Favorites
          final favsRaw = pData['favorites'] as List<dynamic>? ?? [];
          final favs = favsRaw
              .map((i) {
                try {
                  if (i is Map) {
                    return MediaItem.fromJson(Map<String, dynamic>.from(i));
                  }
                  return null;
                } catch (_) {
                  return null;
                }
              })
              .whereType<MediaItem>()
              .toList();
          await _storageService.saveFavorites(favs, profileId: profile.id);
          totalFavs += favs.length;

          // Already Watched
          final alreadyRaw = pData['alreadyWatched'] as List<dynamic>? ?? [];
          final already = alreadyRaw
              .map((i) {
                try {
                  if (i is Map) {
                    return MediaItem.fromJson(Map<String, dynamic>.from(i));
                  }
                  return null;
                } catch (_) {
                  return null;
                }
              })
              .whereType<MediaItem>()
              .toList();
          await _storageService.saveAlreadyWatched(
            already,
            profileId: profile.id,
          );

          // Watch History
          final histRaw = pData['watchHistory'] as List<dynamic>? ?? [];
          final hist = histRaw
              .map((h) {
                try {
                  if (h is Map) {
                    return WatchHistoryItem.fromJson(
                      Map<String, dynamic>.from(h),
                    );
                  }
                  return null;
                } catch (_) {
                  return null;
                }
              })
              .whereType<WatchHistoryItem>()
              .toList();
          await _storageService.saveWatchHistory(hist, profileId: profile.id);
          totalHist += hist.length;

          // Watched Episodes
          final rawEps = pData['watchedEpisodes'];
          if (rawEps is Map) {
            final eps = <String, Set<String>>{};
            for (final entry in rawEps.entries) {
              if (entry.value is List) {
                eps[entry.key.toString()] = (entry.value as List)
                    .map((e) => e.toString())
                    .toSet();
              }
            }
            await _storageService.saveAllWatchedEpisodes(
              eps,
              profileId: profile.id,
            );
          }
        }
      }

      // 3. Overwrite settings
      final rawSettings = bundle['settings'];
      final settings = rawSettings is Map
          ? Map<String, dynamic>.from(rawSettings)
          : <String, dynamic>{};
      for (final entry in settings.entries) {
        final val = entry.value;
        if (val is bool) {
          await prefs.setBool(entry.key, val);
        } else if (val is int) {
          await prefs.setInt(entry.key, val);
        } else if (val is double) {
          await prefs.setDouble(entry.key, val);
        } else if (val is String) {
          await prefs.setString(entry.key, val);
        } else if (val is List) {
          await prefs.setStringList(entry.key, val.cast<String>());
        }
      }
    } else {
      // Merge Strategy: Combine profiles & libraries
      final currentProfiles = await _storageService.getProfiles();
      final profileMap = {for (var p in currentProfiles) p.id: p};

      for (final imp in importedProfiles) {
        if (!profileMap.containsKey(imp.id)) {
          currentProfiles.add(imp);
        }
      }
      await _storageService.saveProfiles(currentProfiles);

      for (final imp in importedProfiles) {
        final rawPData = dataByProfile[imp.id];
        final pData = rawPData is Map ? rawPData : null;
        if (pData != null) {
          // Merge Favorites
          final currentFavs = await _storageService.getFavorites(
            profileId: imp.id,
          );
          final currentFavIds = currentFavs.map((i) => i.id).toSet();
          final favsRaw = pData['favorites'] as List<dynamic>? ?? [];
          for (final raw in favsRaw) {
            try {
              if (raw is Map) {
                final item = MediaItem.fromJson(Map<String, dynamic>.from(raw));
                if (!currentFavIds.contains(item.id)) {
                  currentFavs.add(item);
                  currentFavIds.add(item.id);
                }
              }
            } catch (_) {}
          }
          await _storageService.saveFavorites(currentFavs, profileId: imp.id);
          totalFavs += currentFavs.length;

          // Merge Watch History
          final currentHist = await _storageService.getWatchHistory(
            profileId: imp.id,
          );
          final histMap = <String, WatchHistoryItem>{};
          for (final h in currentHist) {
            final key = '${h.item.id}_${h.season ?? 0}_${h.episode ?? 0}';
            histMap[key] = h;
          }
          final histRaw = pData['watchHistory'] as List<dynamic>? ?? [];
          for (final raw in histRaw) {
            try {
              if (raw is Map) {
                final item = WatchHistoryItem.fromJson(
                  Map<String, dynamic>.from(raw),
                );
                final key =
                    '${item.item.id}_${item.season ?? 0}_${item.episode ?? 0}';
                if (!histMap.containsKey(key) ||
                    item.lastWatchedTimestamp >
                        histMap[key]!.lastWatchedTimestamp) {
                  histMap[key] = item;
                }
              }
            } catch (_) {}
          }
          final mergedHist = histMap.values.toList()
            ..sort(
              (a, b) =>
                  b.lastWatchedTimestamp.compareTo(a.lastWatchedTimestamp),
            );
          await _storageService.saveWatchHistory(mergedHist, profileId: imp.id);
          totalHist += mergedHist.length;

          // Merge Watched Episodes
          final currentEps = await _storageService.getAllWatchedEpisodes(
            profileId: imp.id,
          );
          final rawEps = pData['watchedEpisodes'];
          if (rawEps is Map) {
            for (final entry in rawEps.entries) {
              final set = currentEps[entry.key.toString()] ?? <String>{};
              if (entry.value is List) {
                for (final ep in (entry.value as List)) {
                  set.add(ep.toString());
                }
              }
              currentEps[entry.key.toString()] = set;
            }
            await _storageService.saveAllWatchedEpisodes(
              currentEps,
              profileId: imp.id,
            );
          }
        }
      }
    }

    return BackupRestoreResult(
      success: true,
      message:
          'Successfully restored ${importedProfiles.length} profiles, $totalFavs favorites, and $totalHist history items.',
      restoredProfiles: importedProfiles.length,
      restoredFavorites: totalFavs,
      restoredHistory: totalHist,
    );
  }
}
