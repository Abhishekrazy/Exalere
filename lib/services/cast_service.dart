import 'dart:async';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import '../models/media_item.dart';
import '../models/stream_source.dart';

/// Central service for casting media from Exalere to Chromecast,
/// DLNA (Smart TVs, Android TV, Roku), and AirPlay devices.
/// Automatically binds headers (User-Agent, Referer) through dart_cast's
/// built-in HTTP proxy.
class AppCastService {
  static final AppCastService _instance = AppCastService._internal();
  factory AppCastService() => _instance;
  AppCastService._internal();

  CastService? _castService;
  CastSession? _activeSession;
  CastDevice? _activeDevice;

  void init() {
    if (_castService != null) return;
    _castService = CastService(
      discoveryProviders: [
        ChromecastDiscoveryProvider(),
        AirPlayDiscoveryProvider(),
        DlnaDiscoveryProvider(),
      ],
      sessionFactory: (device) => _createSessionForDevice(device),
    );
  }

  CastSession _createSessionForDevice(CastDevice device) {
    switch (device.protocol) {
      case CastProtocol.chromecast:
        return ChromecastSession(device: device);
      case CastProtocol.airplay:
        return AirPlaySession(device);
      case CastProtocol.dlna:
        return DlnaSession.fromDevice(device);
    }
  }

  /// Discover cast devices on the local network (Chromecast, DLNA, AirPlay)
  Stream<List<CastDevice>> discoverDevices({Duration timeout = const Duration(seconds: 15)}) {
    init();
    return _castService!.startDiscovery(timeout: timeout);
  }

  /// Stop ongoing discovery
  void stopDiscovery() {
    _castService?.stopDiscovery();
  }

  /// Connect to a target cast device
  Future<CastSession> connect(CastDevice device) async {
    init();

    // Disconnect any active session before connecting to new device
    if (_activeSession != null) {
      try {
        await _activeSession!.disconnect();
      } catch (e) {
        debugPrint('AppCastService: Error disconnecting previous session: $e');
      }
      _activeSession = null;
      _activeDevice = null;
    }

    try {
      CastSession session;
      if (device.protocol == CastProtocol.dlna) {
        session = DlnaSession.fromDevice(device);
        await session.connect();
      } else {
        session = await _castService!.connect(device);
      }

      _activeSession = session;
      _activeDevice = device;
      return session;
    } catch (e) {
      debugPrint('AppCastService: Failed to connect to ${device.name}: $e');
      rethrow;
    }
  }

  /// Create a CastMedia descriptor configured with proper media type and custom MovieBox HTTP headers
  CastMedia buildCastMedia({
    required MediaItem item,
    required StreamSource source,
    Duration? startPosition,
    List<SubtitleOption>? subtitles,
  }) {
    CastMediaType type = CastMediaType.mp4;
    final urlLower = source.url.toLowerCase();
    if (urlLower.contains('.m3u8') || urlLower.contains('hls')) {
      type = CastMediaType.hls;
    } else if (urlLower.contains('.mkv')) {
      type = CastMediaType.mkv;
    } else if (urlLower.contains('.ts')) {
      type = CastMediaType.mpegTs;
    }

    final castSubtitles = (subtitles ?? []).map((s) => CastSubtitle(
      url: s.url,
      label: s.name,
      language: s.language,
      format: s.url.toLowerCase().endsWith('.srt') ? 'srt' : 'vtt',
    )).toList();

    return CastMedia(
      url: source.url,
      type: type,
      title: item.title,
      imageUrl: item.backdropUrl ?? item.posterUrl,
      httpHeaders: source.headers,
      startPosition: startPosition,
      subtitles: castSubtitles,
    );
  }

  /// Cast media to the connected session
  Future<void> loadMedia({
    required CastSession session,
    required MediaItem item,
    required StreamSource source,
    Duration? startPosition,
    List<SubtitleOption>? subtitles,
  }) async {
    final media = buildCastMedia(
      item: item,
      source: source,
      startPosition: startPosition,
      subtitles: subtitles,
    );

    await session.loadMedia(media);
  }

  /// Disconnect active casting session
  Future<void> disconnect() async {
    if (_activeSession != null) {
      try {
        await _activeSession!.disconnect();
      } catch (e) {
        debugPrint('AppCastService: Error disconnecting session: $e');
      }
      _activeSession = null;
      _activeDevice = null;
    }
  }

  CastSession? get activeSession => _activeSession;
  CastDevice? get activeDevice => _activeDevice;

  void dispose() {
    _castService?.dispose();
    _castService = null;
    _activeSession = null;
    _activeDevice = null;
  }
}
