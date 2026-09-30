import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_details.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'app_installer_service.dart' show DownloadCancelToken;
import 'provider_registry.dart';

enum DownloadTaskStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

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
  final Map<String, String>? headers;
  final String? mediaId;
  final String? mediaTitle;
  final int? season;
  final int? episode;
  final String? thumbnailUrl;
  final String? quality;

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
    this.headers,
    this.mediaId,
    this.mediaTitle,
    this.season,
    this.episode,
    this.thumbnailUrl,
    this.quality,
  });

  VideoDownloadTask copyWith({
    String? url,
    String? title,
    String? fileName,
    String? filePath,
    int? totalBytes,
    int? receivedBytes,
    double? progress,
    double? speedBytesPerSec,
    DownloadTaskStatus? status,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    Map<String, String>? headers,
    String? mediaId,
    String? mediaTitle,
    int? season,
    int? episode,
    String? thumbnailUrl,
    String? quality,
  }) {
    return VideoDownloadTask(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      progress: progress ?? this.progress,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      headers: headers ?? this.headers,
      mediaId: mediaId ?? this.mediaId,
      mediaTitle: mediaTitle ?? this.mediaTitle,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      quality: quality ?? this.quality,
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

  final Set<String> _pausedTaskIds = {};
  bool _isProcessingQueue = false;

  List<VideoDownloadTask> get queuedTasks => _tasks.values
      .where((t) => t.status == DownloadTaskStatus.queued)
      .toList();

  List<VideoDownloadTask> get inProgressAndQueuedTasks => _tasks.values
      .where(
        (t) =>
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.queued ||
            t.status == DownloadTaskStatus.paused,
      )
      .toList();

  /// Enqueues a video download in the sequential queue.
  /// If no download is active, it starts downloading immediately.
  Future<VideoDownloadTask> enqueueDownload({
    required String url,
    String? title,
    Map<String, String>? headers,
    String? mediaId,
    String? mediaTitle,
    int? season,
    int? episode,
    String? thumbnailUrl,
    String? quality,
  }) async {
    final dir = await getDownloadsDirectory();
    final fileName = deriveFileName(
      url.isNotEmpty ? url : (mediaTitle ?? title ?? 'video'),
      title,
    );
    final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');
    final taskId =
        'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}';
    final displayTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : fileName;

    final task = VideoDownloadTask(
      id: taskId,
      url: url,
      title: displayTitle,
      fileName: fileName,
      filePath: targetFile.path,
      status: DownloadTaskStatus.queued,
      startedAt: DateTime.now(),
      headers: headers,
      mediaId: mediaId,
      mediaTitle: mediaTitle ?? displayTitle,
      season: season,
      episode: episode,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
    );

    _tasks[taskId] = task;
    notifyListeners();

    unawaited(_processQueue());
    return task;
  }

  /// Downloads a video from [url] with live progress updates.
  /// Legacy entry point that delegates to [enqueueDownload].
  Future<VideoDownloadTask> startDownload({
    required String url,
    String? title,
    Map<String, String>? headers,
    String? mediaId,
    String? mediaTitle,
    int? season,
    int? episode,
    String? thumbnailUrl,
    String? quality,
  }) async {
    return enqueueDownload(
      url: url,
      title: title,
      headers: headers,
      mediaId: mediaId,
      mediaTitle: mediaTitle,
      season: season,
      episode: episode,
      thumbnailUrl: thumbnailUrl,
      quality: quality,
    );
  }

  /// Enqueues an entire season of episodes in the sequential download queue.
  /// Resolves streams dynamically as each episode begins downloading to prevent token expiry.
  Future<List<VideoDownloadTask>> enqueueSeason({
    required MediaItem mediaItem,
    required int seasonNumber,
    required List<Episode> episodes,
    String? preferredProviderId,
  }) async {
    final List<VideoDownloadTask> addedTasks = [];
    final dir = await getDownloadsDirectory();

    for (int i = 0; i < episodes.length; i++) {
      final ep = episodes[i];
      final title =
          '${mediaItem.title} - S${seasonNumber}E${ep.episode}: ${ep.title}';
      final cleanTitle = '${mediaItem.title}_S${seasonNumber}E${ep.episode}'
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '$cleanTitle.mp4';
      final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');
      final taskId =
          'task_${DateTime.now().millisecondsSinceEpoch}_${_tasks.length}_$i';

      final task = VideoDownloadTask(
        id: taskId,
        url: '', // Lazy resolution when the task starts
        title: title,
        fileName: fileName,
        filePath: targetFile.path,
        status: DownloadTaskStatus.queued,
        startedAt: DateTime.now(),
        mediaId: mediaItem.id,
        mediaTitle: mediaItem.title,
        season: seasonNumber,
        episode: ep.episode,
        thumbnailUrl: ep.thumbnail,
      );

      _tasks[taskId] = task;
      addedTasks.add(task);
    }

    notifyListeners();
    unawaited(_processQueue());
    return addedTasks;
  }

  /// Processes the sequential download queue. Only 1 active download at a time.
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;

    final isDownloading = _tasks.values.any(
      (t) => t.status == DownloadTaskStatus.downloading,
    );
    if (isDownloading) return;

    final nextTaskEntry = _tasks.entries
        .cast<MapEntry<String, VideoDownloadTask>?>()
        .firstWhere(
          (e) => e?.value.status == DownloadTaskStatus.queued,
          orElse: () => null,
        );

    if (nextTaskEntry == null) return;

    _isProcessingQueue = true;
    final taskId = nextTaskEntry.key;
    var task = nextTaskEntry.value;

    try {
      // Lazy stream resolution for queued series episodes
      if (task.url.isEmpty && task.mediaId != null) {
        final streams = await ProviderRegistry().resolveStreams(
          subjectId: task.mediaId!,
          title: task.mediaTitle ?? task.title,
          season: task.season,
          episode: task.episode,
          isSeries: true,
        );

        if (streams.isEmpty) {
          _tasks[taskId] = task.copyWith(
            status: DownloadTaskStatus.failed,
            errorMessage: 'No streams available for download',
            completedAt: DateTime.now(),
          );
          notifyListeners();
          _isProcessingQueue = false;
          unawaited(_processQueue());
          return;
        }

        // Favor progressive MP4 streams
        final bestStream = streams.firstWhere(
          (s) =>
              s.format.toUpperCase() == 'MP4' ||
              s.url.toLowerCase().contains('.mp4'),
          orElse: () => streams.first,
        );

        final fileName = deriveFileName(bestStream.url, task.title);
        final dir = await getDownloadsDirectory();
        final targetFile = File(
          '${dir.path}${Platform.pathSeparator}$fileName',
        );

        task = task.copyWith(
          url: bestStream.url,
          headers: bestStream.headers,
          fileName: fileName,
          filePath: targetFile.path,
          quality: bestStream.quality,
        );
      }

      File targetFile = File(task.filePath);
      if (task.filePath.isEmpty) {
        final dir = await getDownloadsDirectory();
        final fileName = deriveFileName(task.url, task.title);
        targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');
        task = task.copyWith(fileName: fileName, filePath: targetFile.path);
      }

      final cancelToken = DownloadCancelToken();
      _cancelTokens[taskId] = cancelToken;

      task = task.copyWith(
        status: DownloadTaskStatus.downloading,
        startedAt: DateTime.now(),
      );
      _tasks[taskId] = task;
      notifyListeners();

      await _executeDownload(task, targetFile, cancelToken);
    } catch (e) {
      debugPrint('DirectStreamService queue error on task $taskId: $e');
      if (_tasks.containsKey(taskId)) {
        _tasks[taskId] = _tasks[taskId]!.copyWith(
          status: DownloadTaskStatus.failed,
          errorMessage: e.toString(),
          completedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } finally {
      _cancelTokens.remove(taskId);
      _isProcessingQueue = false;
      unawaited(_processQueue());
    }
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
      if (task.headers != null && task.headers!.isNotEmpty) {
        request.headers.addAll(task.headers!);
      }

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
          final isPaused = _pausedTaskIds.remove(taskId);
          if (!isPaused && await targetFile.exists()) {
            await targetFile.delete();
          }
          _tasks[taskId] = _tasks[taskId]!.copyWith(
            status: isPaused
                ? DownloadTaskStatus.paused
                : DownloadTaskStatus.cancelled,
            errorMessage: isPaused ? 'Download paused' : 'Download cancelled',
            completedAt: isPaused ? null : DateTime.now(),
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

      final isPaused = _pausedTaskIds.remove(taskId);
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: isPaused
            ? DownloadTaskStatus.paused
            : (cancelToken.isCancelled
                  ? DownloadTaskStatus.cancelled
                  : DownloadTaskStatus.failed),
        errorMessage: isPaused ? 'Download paused' : e.toString(),
        completedAt: isPaused ? null : DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Pauses an active downloading or queued task.
  void pauseDownload(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;

    _pausedTaskIds.add(taskId);
    if (task.status == DownloadTaskStatus.downloading) {
      final token = _cancelTokens[taskId];
      if (token != null) {
        token.cancel();
      }
    }
    _tasks[taskId] = task.copyWith(status: DownloadTaskStatus.paused);
    notifyListeners();
  }

  /// Resumes a paused, failed, or cancelled task.
  void resumeDownload(String taskId) {
    final task = _tasks[taskId];
    if (task == null) return;

    _pausedTaskIds.remove(taskId);
    if (task.status == DownloadTaskStatus.paused ||
        task.status == DownloadTaskStatus.failed ||
        task.status == DownloadTaskStatus.cancelled) {
      _tasks[taskId] = task.copyWith(
        status: DownloadTaskStatus.queued,
        errorMessage: null,
      );
      notifyListeners();
      unawaited(_processQueue());
    }
  }

  /// Retries a failed or cancelled download task.
  void retryDownload(String taskId) {
    resumeDownload(taskId);
  }

  /// Cancels an ongoing download task.
  void cancelDownload(String taskId) {
    _pausedTaskIds.remove(taskId);
    final token = _cancelTokens[taskId];
    if (token != null) {
      token.cancel();
    } else {
      final task = _tasks[taskId];
      if (task != null) {
        _tasks[taskId] = task.copyWith(
          status: DownloadTaskStatus.cancelled,
          completedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }

    final task = _tasks[taskId];
    if (task != null && task.filePath.isNotEmpty) {
      try {
        final file = File(task.filePath);
        file.exists().then((exists) {
          if (exists) file.delete();
        });
      } catch (_) {}
    }
    unawaited(_processQueue());
  }

  /// Removes a task from the list and deletes its file if incomplete.
  void removeTask(String taskId) {
    cancelDownload(taskId);
    _tasks.remove(taskId);
    notifyListeners();
  }

  /// Clears completed, failed, and cancelled tasks from the list.
  void clearCompletedTasks() {
    _tasks.removeWhere(
      (_, task) =>
          task.status == DownloadTaskStatus.completed ||
          task.status == DownloadTaskStatus.failed ||
          task.status == DownloadTaskStatus.cancelled,
    );
    notifyListeners();
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
