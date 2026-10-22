import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// One file inside a torrent.
class TorrentFileInfo {
  const TorrentFileInfo({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
  });

  final int index;
  final String name;
  final String path;
  final int size;

  factory TorrentFileInfo.fromMap(Map<dynamic, dynamic> map) => TorrentFileInfo(
    index: (map['index'] as num?)?.toInt() ?? 0,
    name: map['name']?.toString() ?? 'file',
    path: map['path']?.toString() ?? '',
    size: (map['size'] as num?)?.toInt() ?? 0,
  );

  String get formattedSize {
    if (size <= 0) return '';
    final gb = size / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    return '${(size / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

/// A torrent known to the engine, with metadata resolved.
class TorrentHandleInfo {
  const TorrentHandleInfo({
    required this.infoHash,
    required this.name,
    required this.totalSize,
    required this.files,
    required this.selectedFileIndex,
  });

  final String infoHash;
  final String name;
  final int totalSize;
  final List<TorrentFileInfo> files;
  final int selectedFileIndex;

  TorrentFileInfo? get selectedFile {
    for (final file in files) {
      if (file.index == selectedFileIndex) return file;
    }
    return files.isEmpty ? null : files.first;
  }

  factory TorrentHandleInfo.fromMap(Map<dynamic, dynamic> map) {
    final rawFiles = map['files'];
    final files = <TorrentFileInfo>[];
    if (rawFiles is List) {
      for (final raw in rawFiles) {
        if (raw is Map) files.add(TorrentFileInfo.fromMap(raw));
      }
    }
    return TorrentHandleInfo(
      infoHash: map['infoHash']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Torrent',
      totalSize: (map['totalSize'] as num?)?.toInt() ?? 0,
      files: files,
      selectedFileIndex: (map['selectedFileIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Live transfer statistics for a torrent.
class TorrentStats {
  const TorrentStats({
    required this.found,
    this.state = 'unknown',
    this.progress = 0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.hasMetadata = false,
  });

  final bool found;
  final String state;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int numPeers;
  final int numSeeds;
  final int totalDone;
  final int totalWanted;
  final bool hasMetadata;

  bool get isActive => found && state != 'finished' && state != 'seeding';

  /// Compact label such as `1.2 MB/s · 18 peers`.
  String get summary {
    final parts = <String>[];
    if (downloadRate > 0) {
      parts.add('${rateLabel(downloadRate)}/s');
    }
    if (numPeers > 0) {
      parts.add('$numPeers ${numPeers == 1 ? 'peer' : 'peers'}');
    }
    return parts.join(' · ');
  }

  static String rateLabel(int bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytesPerSecond >= 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytesPerSecond B';
  }

  factory TorrentStats.fromMap(Map<dynamic, dynamic> map) => TorrentStats(
    found: map['found'] == true,
    state: map['state']?.toString() ?? 'unknown',
    progress: (map['progress'] as num?)?.toDouble() ?? 0,
    downloadRate: (map['downloadRate'] as num?)?.toInt() ?? 0,
    uploadRate: (map['uploadRate'] as num?)?.toInt() ?? 0,
    numPeers: (map['numPeers'] as num?)?.toInt() ?? 0,
    numSeeds: (map['numSeeds'] as num?)?.toInt() ?? 0,
    totalDone: (map['totalDone'] as num?)?.toInt() ?? 0,
    totalWanted: (map['totalWanted'] as num?)?.toInt() ?? 0,
    hasMetadata: map['hasMetadata'] == true,
  );
}

/// A local playback URL produced from a magnet link.
class TorrentStreamTarget {
  const TorrentStreamTarget({
    required this.url,
    required this.infoHash,
    required this.fileIndex,
    required this.name,
    required this.size,
    this.servedByExternalEngine = false,
  });

  final String url;
  final String infoHash;
  final int fileIndex;
  final String name;
  final int size;

  /// True when an external engine served this rather than a bundled one.
  final bool servedByExternalEngine;

  String get formattedSize {
    if (size <= 0) return '';
    final gb = size / (1024 * 1024 * 1024);
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    return '${(size / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
}

/// Which engine is resolving magnets.
enum TorrentEngineKind {
  /// Nothing can resolve magnets with the current platform and configuration.
  none,

  /// The libtorrent engine bundled into the `github` build.
  bundled,

  /// A separate engine reached over loopback HTTP.
  external,
}

/// How magnets are turned into playable URLs.
///
/// A BitTorrent engine cannot be delivered as a downloadable plugin: a plugin in
/// this app's ABI is remote *data* (a manifest plus `/stream/` responses), whereas
/// libtorrent is native code. Dart cannot load a new native library at runtime,
/// and Google Play forbids downloading and executing executable code — so
/// shipping P2P as a plugin is not possible.
///
/// P2P is therefore pluggable at the **engine** level instead:
///
///  * **Bundled** — the `github` build compiles in libtorrent and answers over a
///    MethodChannel. The `play` build contains no torrent code at all.
///  * **External** — a separate engine service (ours, or a compatible one such as
///    TorrServe) runs a local HTTP service. The user points Exalere at its base
///    URL and the app needs no torrent code whatsoever.
///
/// Both paths expose the same methods, so the player never knows which is used.
/// The external protocol is deliberately tiny:
///
/// ```text
/// GET    {base}/health                              -> 200 when ready
/// POST   {base}/torrents        {magnet,name}       -> torrent info JSON
/// POST   {base}/torrents/{hash}/prepare?fileIndex=  -> {"ready":bool}
/// GET    {base}/stream/{hash}/{fileIndex}           -> range-served media
/// GET    {base}/torrents/{hash}/stats               -> stats JSON
/// DELETE {base}/torrents/{hash}?deleteFiles=        -> stop and clean up
/// ```
class TorrentService {
  TorrentService._();

  static final TorrentService instance = TorrentService._();

  static const MethodChannel _channel = MethodChannel('com.exalere/torrent');

  /// Time allowed for the whole open sequence, metadata included.
  static const Duration openTimeout = Duration(seconds: 75);

  static const Duration _httpTimeout = Duration(seconds: 20);

  final StorageService _storage = StorageService();

  bool? _nativeAvailable;
  String? _externalBaseUrl;
  TorrentEngineKind _kind = TorrentEngineKind.none;

  bool get isPlatformCandidate => !kIsWeb && Platform.isAndroid;

  /// Which engine the last configuration resolved to.
  TorrentEngineKind get engineKind => _kind;

  /// Base URL of the configured external engine, if any.
  String? get externalEngineUrl => _externalBaseUrl;

  static bool isMagnetUrl(String url) =>
      url.trimLeft().toLowerCase().startsWith('magnet:');

  /// Re-reads the configured engine URL. Call after the setting changes.
  Future<void> refreshEngineConfiguration() async {
    final raw = await _storage.getP2pEngineUrl();
    final cleaned = raw.trim();
    _externalBaseUrl = cleaned.isEmpty ? null : normalizeBaseUrl(cleaned);
    if (_externalBaseUrl != null) {
      _kind = TorrentEngineKind.external;
    } else if (await _probeNative()) {
      _kind = TorrentEngineKind.bundled;
    } else {
      _kind = TorrentEngineKind.none;
    }
    debugPrint('[TorrentService] engine=${_kind.name} url=$_externalBaseUrl');
  }

  /// Accepts `host:port`, `127.0.0.1:8090/` or a full URL.
  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<bool> _probeNative() async {
    if (!isPlatformCandidate) return false;
    final cached = _nativeAvailable;
    if (cached != null) return cached;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      _nativeAvailable = supported ?? false;
    } on MissingPluginException {
      debugPrint('[TorrentService] No bundled torrent engine registered.');
      _nativeAvailable = false;
    } catch (e) {
      debugPrint('[TorrentService] Bundled engine probe failed: $e');
      _nativeAvailable = false;
    }
    return _nativeAvailable!;
  }

  /// Whether magnets can be resolved at all right now.
  Future<bool> isAvailable() async {
    if (_kind == TorrentEngineKind.none) {
      await refreshEngineConfiguration();
    }
    if (_kind == TorrentEngineKind.external) return _externalHealthOk();
    return _kind == TorrentEngineKind.bundled;
  }

  Future<bool> _externalHealthOk() async {
    final base = _externalBaseUrl;
    if (base == null) return false;
    try {
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[TorrentService] External engine unreachable at $base: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Engine operations
  // ---------------------------------------------------------------------

  /// Initialises the engine. For an external engine this is a health check.
  Future<bool> init() async {
    await refreshEngineConfiguration();
    if (_kind == TorrentEngineKind.external) return _externalHealthOk();
    if (_kind != TorrentEngineKind.bundled) return false;
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>('init');
      return result?['running'] == true;
    } catch (e) {
      debugPrint('[TorrentService] init failed: $e');
      return false;
    }
  }

  /// Adds a magnet and waits for metadata.
  Future<TorrentHandleInfo?> addMagnet(
    String magnet, {
    String? name,
    String? outputFolder,
  }) async {
    if (_kind == TorrentEngineKind.external) {
      return _addMagnetExternal(magnet, name: name, outputFolder: outputFolder);
    }
    if (_kind != TorrentEngineKind.bundled) return null;
    try {
      final result = await _channel
          .invokeMapMethod<dynamic, dynamic>('addMagnet', {
            'magnet': magnet,
            'name': name,
            'outputFolder': outputFolder,
          })
          .timeout(openTimeout);
      return result == null ? null : TorrentHandleInfo.fromMap(result);
    } on TimeoutException {
      debugPrint('[TorrentService] Timed out waiting for metadata.');
      return null;
    } catch (e) {
      debugPrint('[TorrentService] addMagnet failed: $e');
      return null;
    }
  }

  Future<TorrentHandleInfo?> _addMagnetExternal(
    String magnet, {
    String? name,
    String? outputFolder,
  }) async {
    final base = _externalBaseUrl;
    if (base == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$base/torrents'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'magnet': magnet,
              'name': ?name,
              'outputFolder': ?outputFolder,
            }),
          )
          .timeout(openTimeout);
      if (response.statusCode != 200) {
        debugPrint(
          '[TorrentService] External addMagnet HTTP ${response.statusCode}',
        );
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;
      return TorrentHandleInfo.fromMap(decoded);
    } catch (e) {
      debugPrint('[TorrentService] External addMagnet failed: $e');
      return null;
    }
  }

  /// Asks the engine to prioritise [fileIndex] so playback can start quickly.
  Future<bool> prepare(
    String infoHash, {
    int fileIndex = 0,
    bool resuming = false,
  }) async {
    if (_kind == TorrentEngineKind.external) {
      final base = _externalBaseUrl;
      if (base == null) return false;
      try {
        final response = await http
            .post(
              Uri.parse(
                '$base/torrents/$infoHash/prepare'
                '?fileIndex=$fileIndex&resuming=$resuming',
              ),
            )
            .timeout(openTimeout);
        if (response.statusCode != 200) return false;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map && decoded['ready'] == true;
      } catch (e) {
        debugPrint('[TorrentService] External prepare failed: $e');
        return false;
      }
    }
    try {
      final ready = await _channel.invokeMethod<bool>('prepare', {
        'infoHash': infoHash,
        'fileIndex': fileIndex,
        'resuming': resuming,
      });
      return ready ?? false;
    } catch (e) {
      debugPrint('[TorrentService] prepare failed: $e');
      return false;
    }
  }

  /// Loopback URL for [fileIndex] of [infoHash].
  Future<String?> streamUrl(String infoHash, {int fileIndex = 0}) async {
    if (_kind == TorrentEngineKind.external) {
      final base = _externalBaseUrl;
      if (base == null) return null;
      return '$base/stream/$infoHash/$fileIndex';
    }
    try {
      return await _channel.invokeMethod<String>('getStreamUrl', {
        'infoHash': infoHash,
        'fileIndex': fileIndex,
      });
    } catch (e) {
      debugPrint('[TorrentService] getStreamUrl failed: $e');
      return null;
    }
  }

  Future<TorrentStats?> stats(String infoHash) async {
    if (_kind == TorrentEngineKind.external) {
      final base = _externalBaseUrl;
      if (base == null) return null;
      try {
        final response = await http
            .get(Uri.parse('$base/torrents/$infoHash/stats'))
            .timeout(_httpTimeout);
        if (response.statusCode != 200) return null;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map ? TorrentStats.fromMap(decoded) : null;
      } catch (e) {
        debugPrint('[TorrentService] External stats failed: $e');
        return null;
      }
    }
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>('stats', {
        'infoHash': infoHash,
      });
      return result == null ? null : TorrentStats.fromMap(result);
    } catch (e) {
      debugPrint('[TorrentService] stats failed: $e');
      return null;
    }
  }

  /// Stops a torrent and removes its scratch data.
  Future<void> release(String infoHash, {bool deleteFiles = true}) async {
    if (_kind == TorrentEngineKind.external) {
      final base = _externalBaseUrl;
      if (base == null) return;
      try {
        await http
            .delete(
              Uri.parse('$base/torrents/$infoHash?deleteFiles=$deleteFiles'),
            )
            .timeout(_httpTimeout);
      } catch (e) {
        debugPrint('[TorrentService] External release failed: $e');
      }
      return;
    }
    try {
      await _channel.invokeMethod<void>('stop', {
        'infoHash': infoHash,
        'deleteFiles': deleteFiles,
      });
    } catch (e) {
      debugPrint('[TorrentService] release failed: $e');
    }
  }

  Future<void> shutdown() async {
    if (_kind == TorrentEngineKind.external) return;
    try {
      await _channel.invokeMethod<void>('shutdown');
    } catch (e) {
      debugPrint('[TorrentService] shutdown failed: $e');
    }
  }

  /// Full open sequence: add, prepare, and produce a playable local URL.
  ///
  /// Returns `null` on any failure so the caller can offer the external player.
  Future<TorrentStreamTarget?> openMagnet(
    String magnet, {
    String? name,
    String? outputFolder,
    int? preferredFileIndex,
    bool resuming = false,
    void Function(TorrentHandleInfo handle)? onMetadata,
  }) async {
    if (!await init()) return null;

    final handle = await addMagnet(
      magnet,
      name: name,
      outputFolder: outputFolder,
    );
    if (handle == null || handle.infoHash.isEmpty) return null;
    onMetadata?.call(handle);

    final fileIndex = preferredFileIndex ?? handle.selectedFileIndex;
    final prepared = await prepare(
      handle.infoHash,
      fileIndex: fileIndex,
      resuming: resuming,
    );
    if (!prepared) {
      debugPrint(
        '[TorrentService] Not ready yet for ${handle.infoHash}; still exposing '
        'the stream URL so the player can retry.',
      );
    }

    final url = await streamUrl(handle.infoHash, fileIndex: fileIndex);
    if (url == null || url.isEmpty) return null;

    final file = handle.selectedFile;
    return TorrentStreamTarget(
      url: url,
      infoHash: handle.infoHash,
      fileIndex: fileIndex,
      name: file?.name ?? handle.name,
      size: file?.size ?? handle.totalSize,
      servedByExternalEngine: _kind == TorrentEngineKind.external,
    );
  }
}
