import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'app_installer_service.dart' show DownloadCancelToken;

enum DownloadTaskStatus { queued, downloading, completed, failed, cancelled }

/// Represents a single video download task initiated by the user.
class VideoDownloadTask {
  final String id;
  final String url;
  final String title;
  final String fileName;
  final String filePath;
  final int totalBytes;
  final int receivedBytes;
  final double progress;
  final double speedBytesPerSec;
  final DownloadTaskStatus status;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const VideoDownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.fileName,
    required this.filePath,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.progress = 0.0,
    this.speedBytesPerSec = 0.0,
    this.status = DownloadTaskStatus.queued,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  VideoDownloadTask copyWith({
    int? totalBytes,
    int? receivedBytes,
    double? progress,
    double? speedBytesPerSec,
    DownloadTaskStatus? status,
    String? errorMessage,
    DateTime? completedAt,
  }) {
    return VideoDownloadTask(
      id: id,
      url: url,
      title: title,
      fileName: fileName,
      filePath: filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      progress: progress ?? this.progress,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get formattedProgress => '${(progress * 100).toStringAsFixed(1)}%';

  String get formattedSpeed {
    if (speedBytesPerSec <= 0) return '0 KB/s';
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  String get formattedSize {
    final bytes = totalBytes > 0 ? totalBytes : receivedBytes;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// Represents a local downloaded video file on disk.
class DownloadedVideoFile {
  final String path;
  final String fileName;
  final int sizeBytes;
  final DateTime modifiedAt;

  const DownloadedVideoFile({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// A stored entry of a previously entered direct stream URL.
class RecentStreamUrl {
  final String url;
  final String title;
  final int timestamp;

  const RecentStreamUrl({
    required this.url,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'timestamp': timestamp,
  };

  factory RecentStreamUrl.fromJson(Map<String, dynamic> json) =>
      RecentStreamUrl(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );
}

/// Manages direct stream playback, streaming file downloads,
/// local video file scanning, and recent URL history.
class DirectStreamService extends ChangeNotifier {
  static final DirectStreamService instance = DirectStreamService._internal();
  factory DirectStreamService() => instance;
  DirectStreamService._internal();

  static const String _recentUrlsKey = 'user_direct_stream_recent_urls';
  static const MethodChannel _installerChannel = MethodChannel(
    'com.exalere/app_installer',
  );

  final http.Client _client = http.Client();
  final Map<String, VideoDownloadTask> _tasks = {};
  final Map<String, DownloadCancelToken> _cancelTokens = {};

  List<VideoDownloadTask> get tasks => _tasks.values.toList().reversed.toList();
  VideoDownloadTask? get activeTask =>
      _tasks.values.cast<VideoDownloadTask?>().firstWhere(
        (t) => t?.status == DownloadTaskStatus.downloading,
        orElse: () => null,
      );

  /// Resolves the storage directory for downloaded videos.
  Future<Directory> getDownloadsDirectory() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final path = await _installerChannel.invokeMethod<String>(
          'getDownloadsStorageDir',
        );
        if (path != null && path.isNotEmpty) {
          final dir = Directory(path);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (e) {
        debugPrint('DirectStreamService: getDownloadsStorageDir failed: $e');
      }
    }

    if (!kIsWeb && Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final dir = Directory(
          '$userProfile${Platform.pathSeparator}Downloads${Platform.pathSeparator}Exalere',
        );
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }

    final fallback = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}ExalereDownloads',
    );
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
  }

  /// Extracts or infers a sensible filename from [url] and optional [customTitle].
  String deriveFileName(String url, String? customTitle) {
    String name = '';
    if (customTitle != null && customTitle.trim().isNotEmpty) {
      name = customTitle.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    }

    String extension = '.mp4';
    try {
      final uri = Uri.parse(url);
      final lastSegment = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '')
          : '';

      if (lastSegment.contains('.')) {
        final ext = '.${lastSegment.split('.').last.toLowerCase()}';
        if (['.mp4', '.mkv', '.webm', '.ts', '.avi', '.mov'].contains(ext)) {
          extension = ext;
        }
      }

      if (name.isEmpty && lastSegment.isNotEmpty) {
        name = lastSegment.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        if (!name.endsWith(extension)) {
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex > 0) {
            name = name.substring(0, dotIndex);
          }
        }
      }
    } catch (_) {}

    if (name.isEmpty) {
      name = 'video_${DateTime.now().millisecondsSinceEpoch}';
    }

    if (!name.toLowerCase().endsWith(extension)) {
      name = '$name$extension';
    }

    return name;
  }

  /// Downloads a video from [url] with live progress updates.
  Future<VideoDownloadTask> startDownload({
    required String url,
    String? title,
  }) async {
    final dir = await getDownloadsDirectory();
    final fileName = deriveFileName(url, title);
    final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';
    final displayTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : fileName;

    final cancelToken = DownloadCancelToken();
    _cancelTokens[taskId] = cancelToken;

    var task = VideoDownloadTask(
      id: taskId,
      url: url,
      title: displayTitle,
      fileName: fileName,
      filePath: targetFile.path,
      status: DownloadTaskStatus.downloading,
      startedAt: DateTime.now(),
    );

    _tasks[taskId] = task;
    notifyListeners();

    unawaited(_executeDownload(task, targetFile, cancelToken));
    return task;
  }

  Future<void> _executeDownload(
    VideoDownloadTask task,
    File targetFile,
    DownloadCancelToken cancelToken,
  ) async {
    final taskId = task.id;
    IOSink? sink;

    try {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final request = http.Request('GET', Uri.parse(task.url));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
      final response = await _client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download video: HTTP ${response.statusCode}',
          uri: Uri.parse(task.url),
        );
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      sink = targetFile.openWrite();

      var lastSpeedCheck = DateTime.now();
      int bytesSinceLastCheck = 0;
      double currentSpeed = 0.0;

      await for (final chunk in response.stream) {
        if (cancelToken.isCancelled) {
          await sink.close();
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          _tasks[taskId] = _tasks[taskId]!.copyWith(
            status: DownloadTaskStatus.cancelled,
            errorMessage: 'Download cancelled',
            completedAt: DateTime.now(),
          );
          notifyListeners();
          return;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;
        bytesSinceLastCheck += chunk.length;

        final now = DateTime.now();
        final durationSinceCheck = now
            .difference(lastSpeedCheck)
            .inMilliseconds;
        if (durationSinceCheck >= 500) {
          currentSpeed = (bytesSinceLastCheck / (durationSinceCheck / 1000.0));
          bytesSinceLastCheck = 0;
          lastSpeedCheck = now;

          final progress = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;

          _tasks[taskId] = _tasks[taskId]!.copyWith(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            progress: progress,
            speedBytesPerSec: currentSpeed,
          );
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      _tasks[taskId] = _tasks[taskId]!.copyWith(
        receivedBytes: receivedBytes,
        totalBytes: receivedBytes,
        progress: 1.0,
        speedBytesPerSec: 0.0,
        status: DownloadTaskStatus.completed,
        completedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}

      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: cancelToken.isCancelled
            ? DownloadTaskStatus.cancelled
            : DownloadTaskStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
      notifyListeners();
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  /// Cancels an ongoing download task.
  void cancelDownload(String taskId) {
    final token = _cancelTokens[taskId];
    if (token != null) {
      token.cancel();
    }
  }

  /// Scans the downloads directory and returns all downloaded video files.
  Future<List<DownloadedVideoFile>> getDownloadedFiles() async {
    try {
      final dir = await getDownloadsDirectory();
      if (!await dir.exists()) return [];

      final files = await dir.list().toList();
      final videos = <DownloadedVideoFile>[];

      for (final entity in files) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (['mp4', 'mkv', 'webm', 'ts', 'avi', 'mov'].contains(ext)) {
            final stat = await entity.stat();
            final fileName = entity.path.split(Platform.pathSeparator).last;
            videos.add(
              DownloadedVideoFile(
                path: entity.path,
                fileName: fileName,
                sizeBytes: stat.size,
                modifiedAt: stat.modified,
              ),
            );
          }
        }
      }

      videos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return videos;
    } catch (e) {
      debugPrint('DirectStreamService: getDownloadedFiles error: $e');
      return [];
    }
  }

  /// Deletes a downloaded video file from disk.
  Future<bool> deleteDownloadedFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('DirectStreamService: deleteDownloadedFile error: $e');
    }
    return false;
  }

  /// Persists a URL to the recent streams history.
  Future<void> recordRecentUrl({required String url, String? title}) async {
    if (url.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getRecentUrls();

      final displayTitle = (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : deriveFileName(url, null);

      list.removeWhere((item) => item.url == url.trim());
      list.insert(
        0,
        RecentStreamUrl(
          url: url.trim(),
          title: displayTitle,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      if (list.length > 20) {
        list.removeRange(20, list.length);
      }

      final jsonList = list.map((e) => e.toJson()).toList();
      await prefs.setString(_recentUrlsKey, jsonEncode(jsonList));
      notifyListeners();
    } catch (e) {
      debugPrint('DirectStreamService: recordRecentUrl error: $e');
    }
  }

  /// Retrieves previously streamed URLs from history.
  Future<List<RecentStreamUrl>> getRecentUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_recentUrlsKey);
      if (data == null || data.isEmpty) return [];

      final decoded = jsonDecode(data) as List<dynamic>;
      return decoded
          .map((e) => RecentStreamUrl.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('DirectStreamService: getRecentUrls error: $e');
      return [];
    }
  }

  /// Clears recent streams history.
  Future<void> clearRecentUrls() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentUrlsKey);
      notifyListeners();
    } catch (e) {
      debugPrint('DirectStreamService: clearRecentUrls error: $e');
    }
  }

  /// Removes a single recent URL by index or URL match.
  Future<void> removeRecentUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = await getRecentUrls();
      list.removeWhere((item) => item.url == url);

      final jsonList = list.map((e) => e.toJson()).toList();
      await prefs.setString(_recentUrlsKey, jsonEncode(jsonList));
      notifyListeners();
    } catch (e) {
      debugPrint('DirectStreamService: removeRecentUrl error: $e');
    }
  }

  /// Creates a [MediaItem] model suitable for Exalere's PlayerScreen.
  MediaItem createMediaItem(String url, String? customTitle) {
    final title = (customTitle != null && customTitle.trim().isNotEmpty)
        ? customTitle.trim()
        : deriveFileName(url, null);

    return MediaItem(
      id: 'direct_${url.hashCode.abs()}',
      title: title,
      mediaType: MediaType.movie,
      posterUrl: '',
      year: DateTime.now().year.toString(),
      genre: 'Direct Stream',
    );
  }

  /// Creates a [StreamSource] model suitable for Exalere's PlayerScreen.
  StreamSource createStreamSource(String url) {
    final lower = url.toLowerCase();
    final format = lower.contains('.m3u8')
        ? 'HLS'
        : (lower.contains('.mpd') ? 'DASH' : 'MP4');

    return StreamSource(
      quality: 'Direct Stream',
      resolution: 'Auto',
      format: format,
      url: url.trim(),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0',
      },
    );
  }
}
