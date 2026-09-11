import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'tv_service.dart';

/// Information about an app update retrieved from GitHub Releases.
class UpdateInfo {
  final String tagName;
  final String version;
  final String releaseNotes;
  final DateTime? publishedAt;
  final String htmlUrl;
  final String? downloadUrl;
  final String? assetName;
  final int? assetSize;
  final bool isUpdateAvailable;

  const UpdateInfo({
    required this.tagName,
    required this.version,
    required this.releaseNotes,
    this.publishedAt,
    required this.htmlUrl,
    this.downloadUrl,
    this.assetName,
    this.assetSize,
    required this.isUpdateAvailable,
  });

  String get formattedSize {
    if (assetSize == null || assetSize! <= 0) return '';
    final mb = assetSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  bool get isDirectApk => assetName?.endsWith('.apk') ?? false;
  bool get hasDirectBinary => downloadUrl != null && downloadUrl!.isNotEmpty;

  bool get isV7Apk {
    final name = (assetName ?? '').toLowerCase();
    return name.contains('v7a') ||
        (name.contains('armeabi') && !name.contains('arm64'));
  }

  bool get isV8Apk {
    final name = (assetName ?? '').toLowerCase();
    return name.contains('arm64') || name.contains('v8a');
  }

  String get archLabel {
    final name = (assetName ?? '').toLowerCase();
    if (name.contains('armeabi-v7a') || name.contains('v7a')) {
      return 'ARMv7 (32-bit)';
    }
    if (name.contains('arm64') || name.contains('v8a')) {
      return 'ARM64 (64-bit)';
    }
    if (name.contains('x86_64')) return 'x86_64';
    if (name.contains('universal')) return 'Universal';
    if (name.endsWith('.exe')) return 'Windows Setup';
    if (name.endsWith('.zip')) return 'Windows Portable';
    return '';
  }
}

/// Service that interacts with the GitHub Releases API to check for Exalere updates.
class UpdateService {
  static const String repoOwner = 'Abhishekrazy';
  static const String repoName = 'Exalere';
  static const String defaultAppVersion = '0.5.2';
  static String _dynamicAppVersion = defaultAppVersion;

  /// Returns the current dynamic app version, falling back to [defaultAppVersion].
  static String get currentAppVersion => _dynamicAppVersion;

  /// Manually override or update the dynamic version string.
  static void setDynamicVersion(String version) {
    if (version.isNotEmpty) {
      _dynamicAppVersion = version;
    }
  }

  /// Dynamically queries native platform build information from [PackageInfo].
  static Future<void> initVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _dynamicAppVersion = info.version;
      }
    } catch (e) {
      debugPrint('UpdateService: PackageInfo resolution skipped: $e');
    }
  }

  static const String _releasesApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static Abi? _overrideAbi;

  @visibleForTesting
  static void setOverrideAbi(Abi? abi) {
    _overrideAbi = abi;
  }

  /// Returns the current running process binary ABI.
  static Abi get currentProcessAbi {
    if (_overrideAbi != null) return _overrideAbi!;
    if (!kIsWeb) {
      try {
        return Abi.current();
      } catch (e) {
        debugPrint('UpdateService: Error getting Abi.current(): $e');
      }
    }
    return Abi.androidArm64;
  }

  /// Determines the best matching target architecture for Android updates.
  ///
  /// Logic:
  /// 1. If currently running as a 32-bit ARM process (Abi.androidArm), we must stay
  ///    on 'armeabi-v7a' (e.g. armeabi-v7a APK was installed).
  /// 2. If running on Android, check the native OS supported ABIs via [TvService.getSupportedAbis].
  ///    If the device lacks 64-bit support (e.g. 32-bit Android TV / Fire Stick OS),
  ///    we strictly target 'armeabi-v7a'.
  /// 3. If currently running as 64-bit ARM (Abi.androidArm64), target 'arm64-v8a'.
  /// 4. If currently running as x86_64 (Abi.androidX64), target 'x86_64'.
  /// 5. Otherwise fall back to the highest priority supported ABI or 'arm64-v8a'.
  static Future<String> getTargetAndroidAbi() async {
    final abi = currentProcessAbi;

    // 1. If running process is 32-bit ARM, preserve armeabi-v7a
    if (abi == Abi.androidArm) {
      return 'armeabi-v7a';
    }

    // 2. Query hardware / OS supported ABIs on Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final supported = await TvService.getSupportedAbis();
        if (supported.isNotEmpty) {
          final has64 = supported.any(
            (a) =>
                a.toLowerCase().contains('arm64') ||
                a.toLowerCase().contains('v8a'),
          );
          final hasV7 = supported.any(
            (a) =>
                a.toLowerCase().contains('v7a') ||
                a.toLowerCase().contains('armeabi'),
          );
          // If device does not support arm64, it must download 32-bit v7a
          if (!has64 && hasV7) {
            return 'armeabi-v7a';
          }
        }
      } catch (_) {}
    }

    // 3. Process is 64-bit ARM
    if (abi == Abi.androidArm64) {
      return 'arm64-v8a';
    }

    // 4. Process is x86_64
    if (abi == Abi.androidX64) {
      return 'x86_64';
    }

    // 5. Fallback check from supported ABIs
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final supported = await TvService.getSupportedAbis();
        if (supported.isNotEmpty) {
          final first = supported.first.toLowerCase();
          if (first.contains('arm64') || first.contains('v8a')) {
            return 'arm64-v8a';
          }
          if (first.contains('v7a') || first.contains('armeabi')) {
            return 'armeabi-v7a';
          }
          if (first.contains('x86_64')) {
            return 'x86_64';
          }
        }
      } catch (_) {}
    }

    return 'arm64-v8a';
  }

  /// Selects the best Android APK asset from release assets matching [targetAbi].
  ///
  /// Avoids selecting 64-bit ARM APKs for 32-bit devices, and avoids selecting
  /// 32-bit APKs when 64-bit is explicitly required.
  static Map<String, dynamic>? selectAndroidAsset(
    List<dynamic> assets, {
    String? targetAbi,
    bool isTv = false,
  }) {
    if (assets.isEmpty) return null;

    final normalizedTarget = targetAbi?.toLowerCase();

    bool isV7(String name) =>
        name.contains('armeabi-v7a') ||
        (name.contains('v7a') &&
            !name.contains('arm64') &&
            !name.contains('v8a'));

    bool isV8(String name) =>
        name.contains('arm64-v8a') ||
        name.contains('arm64') ||
        (name.contains('v8a') && !name.contains('v7a'));

    bool isX86(String name) => name.contains('x86_64');

    bool isUniversal(String name) => name.contains('universal');

    bool isTvApk(String name) =>
        name.contains('tv') || name.contains('leanback');

    Map<String, dynamic>? tvMatchedAsset;
    Map<String, dynamic>? matchedAsset;
    Map<String, dynamic>? universalAsset;
    Map<String, dynamic>? fallbackApk;

    for (final raw in assets) {
      if (raw is! Map) continue;
      final asset = Map<String, dynamic>.from(raw);
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      if (!name.endsWith('.apk')) continue;

      fallbackApk ??= asset;

      if (isUniversal(name)) {
        universalAsset ??= asset;
      }

      bool matchesTarget = false;
      if (normalizedTarget == 'armeabi-v7a' || normalizedTarget == 'v7a') {
        matchesTarget = isV7(name);
      } else if (normalizedTarget == 'arm64-v8a' ||
          normalizedTarget == 'arm64' ||
          normalizedTarget == 'v8a') {
        matchesTarget = isV8(name);
      } else if (normalizedTarget == 'x86_64' || normalizedTarget == 'x64') {
        matchesTarget = isX86(name);
      }

      if (matchesTarget) {
        if (isTv && isTvApk(name)) {
          tvMatchedAsset ??= asset;
        } else {
          matchedAsset ??= asset;
        }
      }
    }

    if (isTv && tvMatchedAsset != null) return tvMatchedAsset;
    if (matchedAsset != null) return matchedAsset;
    if (universalAsset != null) return universalAsset;

    // If target was specifically 32-bit ARM (v7a), NEVER fall back to arm64 or any APK
    if (normalizedTarget == 'armeabi-v7a' || normalizedTarget == 'v7a') {
      return null;
    }

    return fallbackApk;
  }

  /// Compares two semver strings (e.g. "0.2.0" and "0.3.0").
  /// Returns `true` if [remoteVersion] is strictly newer than [currentVersion].
  static bool isNewerVersion(String currentVersion, String remoteVersion) {
    List<int> parse(String ver) {
      final cleaned = ver
          .toLowerCase()
          .replaceAll(RegExp(r'^v'), '')
          .split(RegExp(r'[\+\-]'))
          .first;
      return cleaned.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    }

    final cParts = parse(currentVersion);
    final rParts = parse(remoteVersion);

    final maxLen = cParts.length > rParts.length
        ? cParts.length
        : rParts.length;
    for (int i = 0; i < maxLen; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final r = i < rParts.length ? rParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Checks GitHub for the latest release and compares it against [currentAppVersion].
  Future<UpdateInfo?> checkLatestRelease({bool isTv = false}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(_releasesApiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Exalere-App',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint(
          'UpdateService: GitHub API returned status ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final tagName = data['tag_name'] as String? ?? '';
      final version = tagName.replaceAll(RegExp(r'^v'), '');
      final releaseNotes = data['body'] as String? ?? '';
      final htmlUrl =
          data['html_url'] as String? ??
          'https://github.com/$repoOwner/$repoName/releases';
      final publishedStr = data['published_at'] as String?;
      final publishedAt = publishedStr != null
          ? DateTime.tryParse(publishedStr)
          : null;

      final assets = (data['assets'] as List<dynamic>?) ?? [];

      String? downloadUrl;
      String? assetName;
      int? assetSize;

      // Platform-aware asset resolution
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          final targetAbi = await getTargetAndroidAbi();
          final androidAsset = selectAndroidAsset(
            assets,
            targetAbi: targetAbi,
            isTv: isTv,
          );
          if (androidAsset != null) {
            downloadUrl = androidAsset['browser_download_url'] as String?;
            assetName = androidAsset['name'] as String?;
            assetSize = androidAsset['size'] as int?;
          }
        } else if (Platform.isWindows) {
          // Windows setup exe or zip
          for (final raw in assets) {
            if (raw is! Map) continue;
            final asset = Map<String, dynamic>.from(raw);
            final name = (asset['name']?.toString() ?? '').toLowerCase();
            if (name.endsWith('.exe')) {
              downloadUrl = asset['browser_download_url'] as String?;
              assetName = asset['name'] as String?;
              assetSize = asset['size'] as int?;
              break;
            } else if (name.endsWith('.zip') && downloadUrl == null) {
              downloadUrl = asset['browser_download_url'] as String?;
              assetName = asset['name'] as String?;
              assetSize = asset['size'] as int?;
            }
          }
        }
      }

      final hasUpdate = isNewerVersion(currentAppVersion, version);

      return UpdateInfo(
        tagName: tagName,
        version: version,
        releaseNotes: releaseNotes,
        publishedAt: publishedAt,
        htmlUrl: htmlUrl,
        downloadUrl: downloadUrl ?? htmlUrl,
        assetName: assetName,
        assetSize: assetSize,
        isUpdateAvailable: hasUpdate,
      );
    } catch (e) {
      debugPrint('UpdateService: Error checking for updates: $e');
      return null;
    }
  }
}
