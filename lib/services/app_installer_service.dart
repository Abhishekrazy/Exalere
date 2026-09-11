import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Represents progress during an in-app update download.
class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress; // 0.0 to 1.0

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });

  String get formattedProgress => '${(progress * 100).toStringAsFixed(0)}%';

  String get formattedSize {
    final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    if (totalBytes <= 0) return '$recMb MB';
    final totMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$recMb MB / $totMb MB';
  }
}

/// Token to abort an ongoing update download.
class DownloadCancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Service that manages in-app downloading and direct installation of app updates.
///
/// Supports:
/// - Android: In-app APK downloading, REQUEST_INSTALL_PACKAGES check, and native FileProvider launch.
/// - Windows: In-app Setup.exe downloading and direct installer process launching.
class AppInstallerService {
  static const String channelName = 'com.exalere/app_installer';

  final MethodChannel _channel;
  final http.Client _client;

  AppInstallerService({MethodChannel? channel, http.Client? client})
    : _channel = channel ?? const MethodChannel(channelName),
      _client = client ?? http.Client();

  /// Whether direct in-app self update is supported on the current platform.
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isWindows;
  }

  /// Checks if the app currently has permission to request package installation on Android (API 26+).
  /// Always returns true on non-Android platforms.
  Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'canRequestPackageInstalls',
      );
      return res ?? true;
    } catch (e) {
      debugPrint('AppInstallerService: canRequestPackageInstalls failed: $e');
      return true;
    }
  }

  /// Opens the Android system settings screen for "Install unknown apps" for Exalere.
  Future<bool> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'openInstallPermissionSettings',
      );
      return res ?? false;
    } catch (e) {
      debugPrint(
        'AppInstallerService: openInstallPermissionSettings failed: $e',
      );
      return false;
    }
  }

  /// Resolves the storage directory for downloaded updates.
  Future<Directory> getUpdateDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('getUpdateStorageDir');
        if (path != null && path.isNotEmpty) {
          final dir = Directory(path);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (e) {
        debugPrint('AppInstallerService: getUpdateStorageDir failed: $e');
      }
    }

    if (!kIsWeb && Platform.isWindows) {
      final temp = Platform.environment['TEMP'] ?? Directory.systemTemp.path;
      final dir = Directory(
        '$temp${Platform.pathSeparator}Exalere${Platform.pathSeparator}updates',
      );
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final fallback = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}exalere_updates',
    );
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
  }

  /// Downloads an update file from [url] with live progress updates.
  ///
  /// Throws an [Exception] on network failure or if aborted via [cancelToken].
  Future<File> downloadUpdate({
    required String url,
    required String fileName,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    final dir = await getUpdateDirectory();
    final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');

    // Remove existing file if any
    if (await targetFile.exists()) {
      try {
        await targetFile.delete();
      } catch (_) {}
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Exalere-InAppUpdate';
    final response = await _client.send(request);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to download update: HTTP ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }

    final totalBytes = response.contentLength ?? 0;
    int receivedBytes = 0;

    final sink = targetFile.openWrite();

    try {
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          throw Exception('Download cancelled by user');
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final double progress = totalBytes > 0
            ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        onProgress?.call(
          DownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: progress,
          ),
        );
      }

      await sink.flush();
      await sink.close();

      return targetFile;
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      if (await targetFile.exists()) {
        try {
          await targetFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Triggers direct installation of the package at [filePath].
  ///
  /// On Android: uses native FileProvider intent to start Package Installer.
  /// On Windows: executes the installer binary.
  Future<bool> installPackage(String filePath) async {
    if (kIsWeb) return false;

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint(
        'AppInstallerService: installPackage file not found: $filePath',
      );
      return false;
    }

    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('installApk', {
          'filePath': filePath,
        });
        return res ?? false;
      } catch (e) {
        debugPrint('AppInstallerService: installApk failed: $e');
        return false;
      }
    }

    if (Platform.isWindows) {
      try {
        await Process.start(filePath, []);
        return true;
      } catch (e) {
        debugPrint('AppInstallerService: Process.start failed: $e');
        return false;
      }
    }

    return false;
  }

  /// Cleans up old downloaded update files from the update directory.
  Future<void> cleanOldUpdates() async {
    try {
      final dir = await getUpdateDirectory();
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.uri.pathSegments.last.toLowerCase();
            if (name.endsWith('.apk') || name.endsWith('.exe')) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('AppInstallerService: cleanOldUpdates failed: $e');
    }
  }
}
