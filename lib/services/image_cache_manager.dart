import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import 'video_cache_service.dart';

/// HTTP Client that strictly throttles concurrent outgoing requests using a FIFO queue.
///
/// On ARMv7 32-bit Android TV devices, concurrent network sockets combined with
/// parallel image decoding exhaust device heap and lock CPU cores. Throttling ensures
/// only [maxConcurrent] image downloads are active at any millisecond.
class ThrottledHttpClient extends http.BaseClient {
  final http.Client _inner;
  final int maxConcurrent;
  int _activeRequests = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  ThrottledHttpClient({http.Client? inner, required this.maxConcurrent})
    : _inner = inner ?? http.Client();

  int get activeRequests => _activeRequests;
  int get queuedRequests => _waiters.length;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    while (_activeRequests >= maxConcurrent) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _activeRequests++;
    try {
      request.headers.putIfAbsent(
        'User-Agent',
        () =>
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      request.headers.putIfAbsent(
        'Accept',
        () =>
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      );
      return await _inner.send(request).timeout(const Duration(seconds: 15));
    } finally {
      _activeRequests--;
      if (_waiters.isNotEmpty) {
        _waiters.removeFirst().complete();
      }
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Specialized [HttpFileService] that configures both [concurrentFetches] in
/// `flutter_cache_manager`'s WebHelper and the underlying [ThrottledHttpClient].
class ThrottledHttpFileService extends HttpFileService {
  final int maxConcurrent;

  ThrottledHttpFileService({
    http.Client? httpClient,
    required this.maxConcurrent,
  }) : super(
         httpClient: httpClient is ThrottledHttpClient
             ? httpClient
             : ThrottledHttpClient(
                 inner: httpClient ?? http.Client(),
                 maxConcurrent: maxConcurrent,
               ),
       ) {
    concurrentFetches = maxConcurrent;
  }
}

/// Centralized image cache manager for Exalere that adaptively throttles concurrent
/// downloads and caps disk cache objects based on the hardware architecture.
class ExalereImageCacheManager extends CacheManager with ImageCacheManager {
  static const String key = 'exalereImageCache';

  static ExalereImageCacheManager? _instance;

  static ExalereImageCacheManager get instance {
    _instance ??= ExalereImageCacheManager._();
    return _instance!;
  }

  @visibleForTesting
  static void setInstance(ExalereImageCacheManager? manager) {
    _instance = manager;
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  ExalereImageCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: VideoCacheService.instance.is32BitOrLowRam
              ? 150
              : 500,
          fileService: ThrottledHttpFileService(
            maxConcurrent: VideoCacheService.instance.is32BitOrLowRam ? 4 : 16,
          ),
        ),
      );

  @visibleForTesting
  ExalereImageCacheManager.custom({
    required int maxConcurrent,
    required int maxNrOfCacheObjects,
  }) : super(
         Config(
           key,
           stalePeriod: const Duration(days: 7),
           maxNrOfCacheObjects: maxNrOfCacheObjects,
           fileService: ThrottledHttpFileService(maxConcurrent: maxConcurrent),
         ),
       );
}
