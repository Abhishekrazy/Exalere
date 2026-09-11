import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
}

/// Service that interacts with the GitHub Releases API to check for Exalere updates.
class UpdateService {
  static const String repoOwner = 'Abhishekrazy';
  static const String repoName = 'Exalere';
  static const String defaultAppVersion = '0.5.1';
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
          if (isTv) {
            // Prefer Android TV Leanback APK
            final tvAsset = assets.firstWhere(
              (a) =>
                  (a['name'] as String? ?? '').toLowerCase().contains('tv') ||
                  (a['name'] as String? ?? '').toLowerCase().contains(
                    'leanback',
                  ),
              orElse: () => null,
            );
            if (tvAsset != null) {
              downloadUrl = tvAsset['browser_download_url'] as String?;
              assetName = tvAsset['name'] as String?;
              assetSize = tvAsset['size'] as int?;
            }
          }

          // Fallback to Mobile/Universal/ARM64 APK
          if (downloadUrl == null) {
            final mobileAsset = assets.firstWhere(
              (a) =>
                  (a['name'] as String? ?? '').toLowerCase().contains(
                    'universal',
                  ) ||
                  (a['name'] as String? ?? '').toLowerCase().contains(
                    'arm64',
                  ) ||
                  (a['name'] as String? ?? '').toLowerCase().contains('mobile'),
              orElse: () => null,
            );
            if (mobileAsset != null) {
              downloadUrl = mobileAsset['browser_download_url'] as String?;
              assetName = mobileAsset['name'] as String?;
              assetSize = mobileAsset['size'] as int?;
            }
          }

          // Generic APK fallback
          if (downloadUrl == null) {
            final anyApk = assets.firstWhere(
              (a) => (a['name'] as String? ?? '').endsWith('.apk'),
              orElse: () => null,
            );
            if (anyApk != null) {
              downloadUrl = anyApk['browser_download_url'] as String?;
              assetName = anyApk['name'] as String?;
              assetSize = anyApk['size'] as int?;
            }
          }
        } else if (Platform.isWindows) {
          // Windows setup exe or zip
          final exeAsset = assets.firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.exe'),
            orElse: () => null,
          );
          if (exeAsset != null) {
            downloadUrl = exeAsset['browser_download_url'] as String?;
            assetName = exeAsset['name'] as String?;
            assetSize = exeAsset['size'] as int?;
          } else {
            final zipAsset = assets.firstWhere(
              (a) => (a['name'] as String? ?? '').endsWith('.zip'),
              orElse: () => null,
            );
            if (zipAsset != null) {
              downloadUrl = zipAsset['browser_download_url'] as String?;
              assetName = zipAsset['name'] as String?;
              assetSize = zipAsset['size'] as int?;
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
