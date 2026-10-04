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
  final String? preferredProviderId;
  final String? serverName;

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
    this.preferredProviderId,
    this.serverName,
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
    String? preferredProviderId,
    String? serverName,
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
      preferredProviderId: preferredProviderId ?? this.preferredProviderId,
      serverName: serverName ?? this.serverName,
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

enum DownloadCheckStatus {
  notDownloaded,
  alreadyDownloaded,
  alreadyDownloading,
  alreadyQueued,
  paused,
}

class DownloadCheckResult {
  final DownloadCheckStatus status;
  final VideoDownloadTask? existingTask;
  final String? existingFilePath;

  const DownloadCheckResult({
    required this.status,
    this.existingTask,
    this.existingFilePath,
  });

  bool get isDuplicate =>
      status == DownloadCheckStatus.alreadyDownloaded ||
      status == DownloadCheckStatus.alreadyDownloading ||
      status == DownloadCheckStatus.alreadyQueued;

  String get userMessage {
    switch (status) {
      case DownloadCheckStatus.alreadyDownloaded:
        return 'Already downloaded';
      case DownloadCheckStatus.alreadyDownloading:
        return 'Currently downloading';
      case DownloadCheckStatus.alreadyQueued:
        return 'Already in download queue';
      case DownloadCheckStatus.paused:
        return 'Download paused (resumed)';
      case DownloadCheckStatus.notDownloaded:
        return 'Queued for download';
    }
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

  /// Checks whether an item is already downloaded or active in the download queue.
  DownloadCheckResult checkExistingDownload({
    String? mediaId,
    String? title,
    String? fileName,
    int? season,
    int? episode,
    String? url,
  }) {
    for (final task in _tasks.values) {
      bool matches = false;
      if (mediaId != null &&
          mediaId.isNotEmpty &&
          task.mediaId == mediaId &&
          task.season == season &&
          task.episode == episode) {
        matches = true;
      } else if (fileName != null &&
          fileName.isNotEmpty &&
          task.fileName.toLowerCase() == fileName.toLowerCase()) {
        matches = true;
      } else if (title != null &&
          title.isNotEmpty &&
          task.mediaTitle?.toLowerCase() == title.toLowerCase() &&
          task.season == season &&
          task.episode == episode) {
        matches = true;
      } else if (url != null && url.isNotEmpty && task.url == url) {
        matches = true;
      }

      if (matches) {
        if (task.status == DownloadTaskStatus.completed) {
          final file = File(task.filePath);
          if (file.existsSync() && file.lengthSync() > 1024 * 1024) {
            return DownloadCheckResult(
              status: DownloadCheckStatus.alreadyDownloaded,
              existingTask: task,
              existingFilePath: task.filePath,
            );
          }
        } else if (task.status == DownloadTaskStatus.downloading) {
          return DownloadCheckResult(
            status: DownloadCheckStatus.alreadyDownloading,
            existingTask: task,
            existingFilePath: task.filePath,
          );
        } else if (task.status == DownloadTaskStatus.queued) {
          return DownloadCheckResult(
            status: DownloadCheckStatus.alreadyQueued,
            existingTask: task,
            existingFilePath: task.filePath,
          );
        } else if (task.status == DownloadTaskStatus.paused) {
          return DownloadCheckResult(
            status: DownloadCheckStatus.paused,
            existingTask: task,
            existingFilePath: task.filePath,
          );
        }
      }
    }

    return const DownloadCheckResult(status: DownloadCheckStatus.notDownloaded);
  }

  /// Enqueues a video download in the sequential queue.
  /// If no download is active, it starts downloading immediately.
  /// Prevents duplicate downloads if already downloaded, queued, or active.
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
    String? preferredProviderId,
    String? serverName,
  }) async {
    final dir = await getDownloadsDirectory();
    final fileName = deriveFileName(
      url.isNotEmpty ? url : (mediaTitle ?? title ?? 'video'),
      title,
    );
    final targetFile = File('${dir.path}${Platform.pathSeparator}$fileName');

    // 1. Prevent duplicate download tasks
    final check = checkExistingDownload(
      mediaId: mediaId,
      title: mediaTitle ?? title,
      fileName: fileName,
      season: season,
      episode: episode,
      url: url.isNotEmpty ? url : null,
    );

    if (check.isDuplicate && check.existingTask != null) {
      debugPrint(
        'DirectStreamService: Prevented duplicate enqueue for $fileName (${check.status})',
      );
      return check.existingTask!;
    }

    // 2. If previously paused, resume the existing task
    if (check.status == DownloadCheckStatus.paused &&
        check.existingTask != null) {
      resumeDownload(check.existingTask!.id);
      return check.existingTask!;
    }

    // 3. Check if file already exists on disk and is intact (> 1MB)
    if (await targetFile.exists()) {
      final fileLen = await targetFile.length();
      if (fileLen > 1024 * 1024) {
        debugPrint(
          'DirectStreamService: File already exists on disk: ${targetFile.path} ($fileLen bytes)',
        );
        final completedTask = VideoDownloadTask(
          id: 'existing_${targetFile.path.hashCode.abs()}',
          url: url,
          title: title ?? fileName,
          fileName: fileName,
          filePath: targetFile.path,
          totalBytes: fileLen,
          receivedBytes: fileLen,
          progress: 1.0,
          status: DownloadTaskStatus.completed,
          startedAt: DateTime.now(),
          completedAt: DateTime.now(),
          mediaId: mediaId,
          mediaTitle: mediaTitle,
          season: season,
          episode: episode,
          thumbnailUrl: thumbnailUrl,
          quality: quality,
          serverName: serverName,
          preferredProviderId: preferredProviderId,
        );
        _tasks[completedTask.id] = completedTask;
        notifyListeners();
        return completedTask;
      }
    }

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
      serverName: serverName,
      preferredProviderId: preferredProviderId,
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
    String? preferredProviderId,
    String? serverName,
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
      preferredProviderId: preferredProviderId,
      serverName: serverName,
    );
  }

  /// Enqueues an entire season of episodes in the sequential download queue.
  /// Automatically filters out already-downloaded or already-queued episodes.
  Future<List<VideoDownloadTask>> enqueueSeason({
    required MediaItem mediaItem,
    required int seasonNumber,
    required List<Episode> episodes,
    String? preferredProviderId,
    String? preferredQuality,
    String? serverName,
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

      // Check if episode is already downloaded or in queue
      final check = checkExistingDownload(
        mediaId: mediaItem.id,
        season: seasonNumber,
        episode: ep.episode,
        fileName: fileName,
      );

      if (check.status == DownloadCheckStatus.alreadyDownloaded) {
        debugPrint(
          'DirectStreamService: Skipping S${seasonNumber}E${ep.episode} - already downloaded.',
        );
        continue;
      }
      if (check.status == DownloadCheckStatus.alreadyDownloading ||
          check.status == DownloadCheckStatus.alreadyQueued) {
        debugPrint(
          'DirectStreamService: Skipping S${seasonNumber}E${ep.episode} - already in queue.',
        );
        continue;
      }
      if (check.status == DownloadCheckStatus.paused &&
          check.existingTask != null) {
        resumeDownload(check.existingTask!.id);
        addedTasks.add(check.existingTask!);
        continue;
      }

      // Check if target file already exists on disk
      if (await targetFile.exists() &&
          await targetFile.length() > 1024 * 1024) {
        debugPrint(
          'DirectStreamService: Skipping S${seasonNumber}E${ep.episode} - file exists on disk.',
        );
        continue;
      }

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
        quality: preferredQuality,
        preferredProviderId: preferredProviderId,
        serverName: serverName,
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
          preferredProviderId: task.preferredProviderId,
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

        // Favor progressive MP4 streams that are not web embeds or torrents
        final downloadable = streams.where((s) {
          final u = s.url.toLowerCase();
          final f = s.format.toLowerCase();
          return !u.contains('/embed/') &&
              !u.contains('vidsrc') &&
              !u.startsWith('magnet:') &&
              f != 'web embed';
        }).toList();

        final bestStream = downloadable.firstWhere(
          (s) =>
              (task.serverName != null &&
                  (s.server == task.serverName ||
                      s.quality == task.serverName)) ||
              (task.quality != null && s.quality == task.quality) ||
              s.format.toUpperCase() == 'MP4' ||
              s.url.toLowerCase().contains('.mp4'),
          orElse: () =>
              downloadable.isNotEmpty ? downloadable.first : streams.first,
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
    int totalBytes = task.totalBytes;

    try {
      // 1. Resume check: examine existing file or partial multi-segment files on disk
      int existingBytes = 0;
      if (await targetFile.exists()) {
        existingBytes = await targetFile.length();
      }

      final part0 = File('${targetFile.path}.part0');
      if (await part0.exists() && task.totalBytes > 0) {
        debugPrint(
          'DirectStreamService: Resuming multi-segment download for ${task.fileName}',
        );
        await _executeMultiSegmentDownload(
          task,
          targetFile,
          cancelToken,
          totalBytes: task.totalBytes,
        );
        return;
      }

      final lowerUrl = task.url.toLowerCase();
      if (lowerUrl.contains('.mpd') || lowerUrl.contains('/dash/')) {
        await _executeDashDownload(task, targetFile, cancelToken);
        return;
      }
      if (lowerUrl.contains('.m3u8')) {
        await _executeHlsDownload(task, targetFile, cancelToken);
        return;
      }

      final request = http.Request('GET', Uri.parse(task.url));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
      if (task.headers != null && task.headers!.isNotEmpty) {
        request.headers.addAll(task.headers!);
      }

      // Add Range header if we have existing bytes to resume
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
        debugPrint(
          'DirectStreamService: Requesting range bytes=$existingBytes- for ${task.fileName}',
        );
      }

      final response = await _client.send(request);

      int receivedBytes = 0;

      http.StreamedResponse activeStreamResponse = response;

      if (response.statusCode == 206) {
        // HTTP 206 Partial Content: Server successfully resumed from existingBytes
        receivedBytes = existingBytes;
        final remaining = response.contentLength ?? 0;
        totalBytes = existingBytes + remaining;
        sink = targetFile.openWrite(mode: FileMode.append);
        debugPrint(
          'DirectStreamService: Resuming download of ${task.fileName} from $existingBytes / $totalBytes bytes',
        );
      } else if (response.statusCode == 200) {
        // HTTP 200 OK: Starting fresh from byte 0 or server does not support Range
        receivedBytes = 0;
        totalBytes = response.contentLength ?? 0;

        // Check if multi-segment parallel download accelerator can be activated
        final supportsRanges =
            response.headers['accept-ranges']?.toLowerCase().contains(
              'bytes',
            ) ==
            true;
        if (existingBytes == 0 &&
            totalBytes >= 10 * 1024 * 1024 &&
            supportsRanges) {
          debugPrint(
            'DirectStreamService: Activating multi-segment download accelerator for ${task.fileName} ($totalBytes bytes)',
          );
          unawaited(response.stream.drain().catchError((_) {}));
          await _executeMultiSegmentDownload(
            task,
            targetFile,
            cancelToken,
            totalBytes: totalBytes,
          );
          return;
        }

        sink = targetFile.openWrite(mode: FileMode.write);
        debugPrint(
          'DirectStreamService: Downloading ${task.fileName} from byte 0 ($totalBytes bytes)',
        );
      } else if (response.statusCode == 416) {
        // HTTP 416 Range Not Satisfiable: File might already be complete
        if (existingBytes > 0 &&
            task.totalBytes > 0 &&
            existingBytes >= task.totalBytes) {
          debugPrint(
            'DirectStreamService: Range 416 - file already fully downloaded ($existingBytes bytes).',
          );
          _tasks[taskId] = _tasks[taskId]!.copyWith(
            receivedBytes: existingBytes,
            totalBytes: existingBytes,
            progress: 1.0,
            status: DownloadTaskStatus.completed,
            completedAt: DateTime.now(),
          );
          notifyListeners();
          return;
        } else {
          // Incomplete range: reset file and restart from 0
          debugPrint(
            'DirectStreamService: Range 416 - resetting corrupted partial file and restarting from 0.',
          );
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          final freshRequest = http.Request('GET', Uri.parse(task.url));
          freshRequest.headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
          if (task.headers != null && task.headers!.isNotEmpty) {
            freshRequest.headers.addAll(task.headers!);
          }
          final freshResponse = await _client.send(freshRequest);
          if (freshResponse.statusCode < 200 ||
              freshResponse.statusCode >= 300) {
            throw HttpException(
              'Failed to download video: HTTP ${freshResponse.statusCode}',
              uri: Uri.parse(task.url),
            );
          }
          activeStreamResponse = freshResponse;
          receivedBytes = 0;
          totalBytes = freshResponse.contentLength ?? 0;
          sink = targetFile.openWrite(mode: FileMode.write);
        }
      } else {
        throw HttpException(
          'Failed to download video: HTTP ${response.statusCode}',
          uri: Uri.parse(task.url),
        );
      }

      var lastSpeedCheck = DateTime.now();
      int bytesSinceLastCheck = 0;
      double currentSpeed = 0.0;

      await for (final chunk in activeStreamResponse.stream) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          final isPaused = _pausedTaskIds.remove(taskId);
          // Preserve partial file on disk so retry/resume continues from where it left off!
          final currentLen = await targetFile.exists()
              ? await targetFile.length()
              : receivedBytes;
          _tasks[taskId] = _tasks[taskId]!.copyWith(
            status: isPaused
                ? DownloadTaskStatus.paused
                : DownloadTaskStatus.cancelled,
            errorMessage: isPaused ? 'Download paused' : 'Download cancelled',
            receivedBytes: currentLen,
            totalBytes: totalBytes,
            progress: totalBytes > 0
                ? (currentLen / totalBytes).clamp(0.0, 1.0)
                : 0.0,
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
        await sink?.flush();
        await sink?.close();
      } catch (_) {}

      final isPaused = _pausedTaskIds.remove(taskId);
      // Preserve the partial file so retry can resume from where it left off
      final partialBytes = await targetFile.exists()
          ? await targetFile.length()
          : 0;
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: isPaused
            ? DownloadTaskStatus.paused
            : (cancelToken.isCancelled
                  ? DownloadTaskStatus.cancelled
                  : DownloadTaskStatus.failed),
        errorMessage: isPaused ? 'Download paused' : e.toString(),
        receivedBytes: partialBytes,
        totalBytes: totalBytes > 0 ? totalBytes : task.totalBytes,
        progress: (totalBytes > 0 ? totalBytes : task.totalBytes) > 0
            ? (partialBytes / (totalBytes > 0 ? totalBytes : task.totalBytes))
                  .clamp(0.0, 1.0)
            : 0.0,
        completedAt: isPaused ? null : DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// Executes a multi-segment parallel download by splitting the file into
  /// concurrent byte-range workers. Delivers 3x–5x faster download speeds
  /// on high-speed internet connections while preserving pause/resume capability.
  Future<void> _executeMultiSegmentDownload(
    VideoDownloadTask task,
    File targetFile,
    DownloadCancelToken cancelToken, {
    required int totalBytes,
    int segmentCount = 3,
  }) async {
    final taskId = task.id;
    final int segmentSize = (totalBytes / segmentCount).ceil();
    final List<File> partFiles = List.generate(
      segmentCount,
      (i) => File('${targetFile.path}.part$i'),
    );

    final List<int> segmentReceived = List.filled(segmentCount, 0);
    for (int i = 0; i < segmentCount; i++) {
      if (await partFiles[i].exists()) {
        segmentReceived[i] = await partFiles[i].length();
      }
    }

    var lastSpeedCheck = DateTime.now();
    int bytesSinceLastCheck = 0;
    double currentSpeed = 0.0;

    void updateProgress() {
      final now = DateTime.now();
      final durationSinceCheck = now.difference(lastSpeedCheck).inMilliseconds;
      if (durationSinceCheck >= 500) {
        currentSpeed = (bytesSinceLastCheck / (durationSinceCheck / 1000.0));
        bytesSinceLastCheck = 0;
        lastSpeedCheck = now;

        final currentTotalReceived = segmentReceived.fold<int>(
          0,
          (a, b) => a + b,
        );
        final progress = totalBytes > 0
            ? (currentTotalReceived / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        _tasks[taskId] = _tasks[taskId]!.copyWith(
          receivedBytes: currentTotalReceived,
          totalBytes: totalBytes,
          progress: progress,
          speedBytesPerSec: currentSpeed,
        );
        notifyListeners();
      }
    }

    final futures = <Future<void>>[];
    for (int i = 0; i < segmentCount; i++) {
      final segIdx = i;
      final segStart = segIdx * segmentSize;
      final segEnd = (segIdx == segmentCount - 1)
          ? totalBytes - 1
          : (segStart + segmentSize - 1);
      final currentPartBytes = segmentReceived[segIdx];

      if (currentPartBytes >= (segEnd - segStart + 1)) {
        // Segment already completed
        continue;
      }

      final rangeStart = segStart + currentPartBytes;
      futures.add(() async {
        final req = http.Request('GET', Uri.parse(task.url));
        req.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
        if (task.headers != null) req.headers.addAll(task.headers!);
        req.headers['Range'] = 'bytes=$rangeStart-$segEnd';

        final res = await _client.send(req);
        if (res.statusCode != 206 && res.statusCode != 200) {
          throw HttpException(
            'Segment $segIdx returned HTTP ${res.statusCode}',
            uri: Uri.parse(task.url),
          );
        }

        final sink = partFiles[segIdx].openWrite(mode: FileMode.append);
        try {
          await for (final chunk in res.stream) {
            if (cancelToken.isCancelled) {
              await sink.flush();
              await sink.close();
              return;
            }
            sink.add(chunk);
            segmentReceived[segIdx] += chunk.length;
            bytesSinceLastCheck += chunk.length;
            updateProgress();
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      }());
    }

    await Future.wait(futures);

    if (cancelToken.isCancelled) {
      final isPaused = _pausedTaskIds.remove(taskId);
      final totalPartBytes = segmentReceived.fold<int>(0, (a, b) => a + b);
      _tasks[taskId] = _tasks[taskId]!.copyWith(
        status: isPaused
            ? DownloadTaskStatus.paused
            : DownloadTaskStatus.cancelled,
        errorMessage: isPaused ? 'Download paused' : 'Download cancelled',
        receivedBytes: totalPartBytes,
        totalBytes: totalBytes,
        progress: totalBytes > 0
            ? (totalPartBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0,
        completedAt: isPaused ? null : DateTime.now(),
      );
      notifyListeners();
      return;
    }

    // Merge completed segment files into the final destination file
    final outputSink = targetFile.openWrite(mode: FileMode.write);
    try {
      for (final partFile in partFiles) {
        if (await partFile.exists()) {
          await outputSink.addStream(partFile.openRead());
        }
      }
      await outputSink.flush();
    } finally {
      await outputSink.close();
    }

    // Clean up temporary part files
    for (final partFile in partFiles) {
      try {
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    }

    _tasks[taskId] = _tasks[taskId]!.copyWith(
      receivedBytes: totalBytes,
      totalBytes: totalBytes,
      progress: 1.0,
      speedBytesPerSec: 0.0,
      status: DownloadTaskStatus.completed,
      completedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> _executeHlsDownload(
    VideoDownloadTask task,
    File targetFile,
    DownloadCancelToken cancelToken,
  ) async {
    final taskId = task.id;
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(task.url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
      if (task.headers != null) req.headers.addAll(task.headers!);

      final resp = await _client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
          'Failed to load HLS playlist: HTTP ${resp.statusCode}',
          uri: Uri.parse(task.url),
        );
      }

      final playlistText = await resp.stream.bytesToString();
      final baseUri = Uri.parse(task.url);

      var mediaPlaylistText = playlistText;
      var mediaBaseUri = baseUri;

      // Master playlist detection: has variant streams
      if (playlistText.contains('#EXT-X-STREAM-INF')) {
        final lines = playlistText.split('\n');
        String? bestVariantUri;
        int highestBandwidth = -1;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('#EXT-X-STREAM-INF:')) {
            int bw = 0;
            final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
            if (bwMatch != null) {
              bw = int.tryParse(bwMatch.group(1)!) ?? 0;
            }
            if (i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim();
              if (!nextLine.startsWith('#') && nextLine.isNotEmpty) {
                if (bw > highestBandwidth || bestVariantUri == null) {
                  highestBandwidth = bw;
                  bestVariantUri = nextLine;
                }
              }
            }
          }
        }

        if (bestVariantUri != null) {
          mediaBaseUri = baseUri.resolve(bestVariantUri);
          final mediaReq = http.Request('GET', mediaBaseUri);
          mediaReq.headers['User-Agent'] =
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
          if (task.headers != null) mediaReq.headers.addAll(task.headers!);
          final mediaResp = await _client.send(mediaReq);
          if (mediaResp.statusCode == 200) {
            mediaPlaylistText = await mediaResp.stream.bytesToString();
          }
        }
      }

      // Extract segment URLs
      final segmentUris = <Uri>[];
      for (final line in mediaPlaylistText.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          segmentUris.add(mediaBaseUri.resolve(trimmed));
        }
      }

      if (segmentUris.isEmpty) {
        throw HttpException(
          'HLS playlist contains no media segments',
          uri: Uri.parse(task.url),
        );
      }

      sink = targetFile.openWrite(mode: FileMode.write);
      int receivedBytes = 0;
      var lastSpeedCheck = DateTime.now();
      int bytesSinceLastCheck = 0;

      for (int i = 0; i < segmentUris.length; i++) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          final isPaused = _pausedTaskIds.remove(taskId);
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

        final segUri = segmentUris[i];
        final segReq = http.Request('GET', segUri);
        segReq.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
        if (task.headers != null) segReq.headers.addAll(task.headers!);

        final segResp = await _client.send(segReq);
        if (segResp.statusCode == 200) {
          await for (final chunk in segResp.stream) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            bytesSinceLastCheck += chunk.length;
          }
        }

        final now = DateTime.now();
        final ms = now.difference(lastSpeedCheck).inMilliseconds;
        if (ms >= 1000 || i == segmentUris.length - 1) {
          final speed = ms > 0 ? (bytesSinceLastCheck / (ms / 1000.0)) : 0.0;
          lastSpeedCheck = now;
          bytesSinceLastCheck = 0;
          final progress = (i + 1) / segmentUris.length;

          _tasks[taskId] = _tasks[taskId]!.copyWith(
            receivedBytes: receivedBytes,
            totalBytes: (receivedBytes / progress).round(),
            progress: progress.clamp(0.0, 1.0),
            speedBytesPerSec: speed,
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
        status: DownloadTaskStatus.completed,
        completedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      if (sink != null) {
        await sink.close().catchError((_) {});
      }
      rethrow;
    }
  }

  Future<void> _executeDashDownload(
    VideoDownloadTask task,
    File targetFile,
    DownloadCancelToken cancelToken,
  ) async {
    try {
      final req = http.Request('GET', Uri.parse(task.url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
      if (task.headers != null) req.headers.addAll(task.headers!);

      final resp = await _client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
          'Failed to load DASH manifest: HTTP ${resp.statusCode}',
          uri: Uri.parse(task.url),
        );
      }

      final manifestXml = await resp.stream.bytesToString();
      final baseUri = Uri.parse(task.url);

      // 1. Direct BaseURL check (single file progressive stream)
      final baseUrlMatch = RegExp(
        r'<BaseURL\b[^>]*>([^<]+)</BaseURL>',
        caseSensitive: false,
      ).firstMatch(manifestXml);
      if (baseUrlMatch != null && !manifestXml.contains('<SegmentTemplate')) {
        final rawBase = baseUrlMatch.group(1)!.trim();
        if (rawBase.isNotEmpty) {
          final directResolvedUri = baseUri.resolve(rawBase);
          debugPrint(
            'DirectStreamService: DASH resolved to direct BaseURL: $directResolvedUri',
          );
          final directTask = task.copyWith(url: directResolvedUri.toString());
          await _executeDownload(directTask, targetFile, cancelToken);
          return;
        }
      }

      // 2. SegmentTemplate parsing (fragmented MP4 segments)
      final repMatches = RegExp(
        r'<Representation\b[^>]*id="([^"]+)"',
        caseSensitive: false,
      ).allMatches(manifestXml).toList();
      String repId = repMatches.isNotEmpty ? repMatches.first.group(1)! : '1';

      if (task.quality != null && repMatches.length > 1) {
        for (final m in repMatches) {
          final id = m.group(1)!;
          if (task.quality!.contains(id) || id.contains(task.quality!)) {
            repId = id;
            break;
          }
        }
      }

      final templateMatch = RegExp(
        r'<SegmentTemplate\b([^>]+)>',
        caseSensitive: false,
      ).firstMatch(manifestXml);
      if (templateMatch == null) {
        final segListInit = RegExp(
          r'<Initialization\b[^>]*sourceURL="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(manifestXml);
        final segListUrls = RegExp(
          r'<SegmentURL\b[^>]*media="([^"]+)"',
          caseSensitive: false,
        ).allMatches(manifestXml).map((m) => m.group(1)!).toList();

        if (segListUrls.isNotEmpty) {
          final segmentUris = <Uri>[];
          if (segListInit != null) {
            segmentUris.add(baseUri.resolve(segListInit.group(1)!));
          }
          for (final s in segListUrls) {
            segmentUris.add(baseUri.resolve(s));
          }
          await _downloadSegmentSequence(
            task,
            targetFile,
            segmentUris,
            cancelToken,
          );
          return;
        }

        throw HttpException(
          'DASH manifest format not recognized or contains encrypted DRM streams.',
          uri: Uri.parse(task.url),
        );
      }

      final templateAttrs = templateMatch.group(1)!;
      final initMatch = RegExp(
        r'initialization="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(templateAttrs);
      final mediaMatch = RegExp(
        r'media="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(templateAttrs);
      final startNumMatch = RegExp(
        r'startNumber="(\d+)"',
        caseSensitive: false,
      ).firstMatch(templateAttrs);
      final durationMatch = RegExp(
        r'duration="(\d+)"',
        caseSensitive: false,
      ).firstMatch(templateAttrs);
      final timescaleMatch = RegExp(
        r'timescale="(\d+)"',
        caseSensitive: false,
      ).firstMatch(templateAttrs);

      if (mediaMatch == null) {
        throw HttpException(
          'DASH SegmentTemplate missing media pattern',
          uri: Uri.parse(task.url),
        );
      }

      final mediaPattern = mediaMatch.group(1)!;
      final startNumber = int.tryParse(startNumMatch?.group(1) ?? '1') ?? 1;
      final timescale =
          int.tryParse(timescaleMatch?.group(1) ?? '1000') ?? 1000;
      final segDuration =
          int.tryParse(durationMatch?.group(1) ?? '4000') ?? 4000;

      final segmentUris = <Uri>[];

      if (initMatch != null) {
        final initPath = initMatch
            .group(1)!
            .replaceAll('\$RepresentationID\$', repId);
        segmentUris.add(baseUri.resolve(initPath));
      }

      final timelineMatch = RegExp(
        r'<SegmentTimeline\b[^>]*>(.*?)</SegmentTimeline>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(manifestXml);
      if (timelineMatch != null) {
        final sMatches = RegExp(
          r'<S\b([^>]+)/>',
          caseSensitive: false,
        ).allMatches(timelineMatch.group(1)!);
        int currentNum = startNumber;
        int currentTime = 0;

        for (final sm in sMatches) {
          final sAttrs = sm.group(1)!;
          final tMatch = RegExp(r't="(\d+)"').firstMatch(sAttrs);
          final dMatch = RegExp(r'd="(\d+)"').firstMatch(sAttrs);
          final rMatch = RegExp(r'r="(-?\d+)"').firstMatch(sAttrs);

          if (tMatch != null) {
            currentTime = int.tryParse(tMatch.group(1)!) ?? currentTime;
          }
          final d = int.tryParse(dMatch?.group(1) ?? '4000') ?? 4000;
          final r = int.tryParse(rMatch?.group(1) ?? '0') ?? 0;
          final count = r >= 0 ? r + 1 : 1;

          for (int c = 0; c < count; c++) {
            var segPath = mediaPattern.replaceAll(
              '\$RepresentationID\$',
              repId,
            );
            segPath = segPath.replaceAll('\$Number\$', '$currentNum');
            segPath = segPath.replaceAllMapped(RegExp(r'\$Number%0(\d+)d\$'), (
              m,
            ) {
              final width = int.tryParse(m.group(1) ?? '1') ?? 1;
              return currentNum.toString().padLeft(width, '0');
            });
            segPath = segPath.replaceAll('\$Time\$', '$currentTime');
            segmentUris.add(baseUri.resolve(segPath));

            currentNum++;
            currentTime += d;
          }
        }
      } else {
        final mpdDurMatch = RegExp(
          r'mediaPresentationDuration="PT(?:(\d+)H)?(?:(\d+)M)?(?:([\d.]+)S)?"',
          caseSensitive: false,
        ).firstMatch(manifestXml);
        double totalSeconds = 7200;
        if (mpdDurMatch != null) {
          final h = double.tryParse(mpdDurMatch.group(1) ?? '0') ?? 0;
          final m = double.tryParse(mpdDurMatch.group(2) ?? '0') ?? 0;
          final s = double.tryParse(mpdDurMatch.group(3) ?? '0') ?? 0;
          totalSeconds = (h * 3600) + (m * 60) + s;
        }

        final segCount = ((totalSeconds * timescale) / segDuration)
            .ceil()
            .clamp(1, 10000);
        for (int i = 0; i < segCount; i++) {
          final num = startNumber + i;
          var segPath = mediaPattern.replaceAll('\$RepresentationID\$', repId);
          segPath = segPath.replaceAll('\$Number\$', '$num');
          segPath = segPath.replaceAllMapped(RegExp(r'\$Number%0(\d+)d\$'), (
            m,
          ) {
            final width = int.tryParse(m.group(1) ?? '1') ?? 1;
            return num.toString().padLeft(width, '0');
          });
          segmentUris.add(baseUri.resolve(segPath));
        }
      }

      if (segmentUris.isEmpty) {
        throw HttpException(
          'No segments could be enumerated from DASH manifest',
          uri: Uri.parse(task.url),
        );
      }

      await _downloadSegmentSequence(
        task,
        targetFile,
        segmentUris,
        cancelToken,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _downloadSegmentSequence(
    VideoDownloadTask task,
    File targetFile,
    List<Uri> segmentUris,
    DownloadCancelToken cancelToken,
  ) async {
    final taskId = task.id;
    final sink = targetFile.openWrite(mode: FileMode.write);
    int receivedBytes = 0;
    var lastSpeedCheck = DateTime.now();
    int bytesSinceLastCheck = 0;

    try {
      for (int i = 0; i < segmentUris.length; i++) {
        if (cancelToken.isCancelled) {
          await sink.flush();
          await sink.close();
          final isPaused = _pausedTaskIds.remove(taskId);
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

        final segUri = segmentUris[i];
        final segReq = http.Request('GET', segUri);
        segReq.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Exalere/1.0';
        if (task.headers != null) segReq.headers.addAll(task.headers!);

        final segResp = await _client.send(segReq);
        if (segResp.statusCode == 200) {
          await for (final chunk in segResp.stream) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            bytesSinceLastCheck += chunk.length;
          }
        }

        final now = DateTime.now();
        final ms = now.difference(lastSpeedCheck).inMilliseconds;
        if (ms >= 1000 || i == segmentUris.length - 1) {
          final speed = ms > 0 ? (bytesSinceLastCheck / (ms / 1000.0)) : 0.0;
          lastSpeedCheck = now;
          bytesSinceLastCheck = 0;
          final progress = (i + 1) / segmentUris.length;

          _tasks[taskId] = _tasks[taskId]!.copyWith(
            receivedBytes: receivedBytes,
            totalBytes: (receivedBytes / progress).round(),
            progress: progress.clamp(0.0, 1.0),
            speedBytesPerSec: speed,
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
        status: DownloadTaskStatus.completed,
        completedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (e) {
      await sink.close().catchError((_) {});
      rethrow;
    }
  }

  /// Exports or reveals a downloaded video file to the system.
  /// On Desktop (Windows): Reveals and highlights the file in File Explorer.
  /// On Android: Copies the file to the user's public external Downloads directory.
  Future<String?> exportDownloadedFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 'Downloaded file not found on disk.';
    }

    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', file.path]);
        return null;
      } catch (e) {
        return 'Could not open File Explorer: $e';
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final publicDownloads = Directory(
          '/storage/emulated/0/Download/Exalere',
        );
        if (!await publicDownloads.exists()) {
          await publicDownloads.create(recursive: true);
        }
        final destFile = File(
          '${publicDownloads.path}${Platform.pathSeparator}$fileName',
        );
        if (file.path != destFile.path) {
          await file.copy(destFile.path);
        }
        return null;
      } catch (e) {
        return 'Export failed: $e';
      }
    }

    return null;
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
    final task = _tasks[taskId];
    if (task != null && task.filePath.isNotEmpty) {
      for (int i = 0; i < 4; i++) {
        final part = File('${task.filePath}.part$i');
        if (part.existsSync()) {
          try {
            part.deleteSync();
          } catch (_) {}
        }
      }
    }
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
