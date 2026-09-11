import 'dart:async';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'chromecast_subnet_scanner.dart';

/// Central service for casting media from Exalere to Chromecast,
/// DLNA (Smart TVs, Android TV, Roku), and AirPlay devices.
/// Automatically binds headers (User-Agent, Referer) through dart_cast's
/// built-in HTTP proxy.
class AppCastService {
  static final AppCastService _instance = AppCastService._internal();
  factory AppCastService() => _instance;
  AppCastService._internal();

  static const MethodChannel _multicastChannel = MethodChannel(
    'com.exalere/multicast_lock',
  );

  CastService? _castService;
  ChromecastSubnetScanner? _subnetScanner;
  CastSession? _activeSession;
  CastDevice? _activeDevice;

  static Future<void> _acquireMulticastLock() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _multicastChannel.invokeMethod('acquire');
      } catch (e) {
        debugPrint('AppCastService: Failed to acquire multicast lock: $e');
      }
    }
  }

  static Future<void> _releaseMulticastLock() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _multicastChannel.invokeMethod('release');
      } catch (e) {
        debugPrint('AppCastService: Failed to release multicast lock: $e');
      }
    }
  }

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
  /// Combines mDNS discovery with Android MulticastLock and parallel subnet scanning.
  Stream<List<CastDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 15),
  }) {
    init();
    _acquireMulticastLock();

    final controller = StreamController<List<CastDevice>>.broadcast();
    final discoveredMap = <String, CastDevice>{};
    StreamSubscription<List<CastDevice>>? mDnsSub;
    StreamSubscription<CastDevice>? subnetSub;

    void emitList() {
      if (!controller.isClosed) {
        controller.add(discoveredMap.values.toList());
      }
    }

    mDnsSub = _castService!
        .startDiscovery(timeout: timeout)
        .listen(
          (devices) {
            for (final d in devices) {
              discoveredMap[d.id] = d;
            }
            emitList();
          },
          onError: (Object e) {
            debugPrint('AppCastService mDNS discovery error: $e');
          },
        );

    _subnetScanner?.stop();
    _subnetScanner = ChromecastSubnetScanner();
    subnetSub = _subnetScanner!
        .scan(timeout: timeout)
        .listen(
          (device) {
            final exists = discoveredMap.values.any(
              (d) =>
                  d.id == device.id ||
                  d.address.address == device.address.address,
            );
            if (!exists) {
              discoveredMap[device.id] = device;
              emitList();
            }
          },
          onError: (Object e) {
            debugPrint('AppCastService SubnetScanner error: $e');
          },
        );

    Timer(timeout, () {
      mDnsSub?.cancel();
      subnetSub?.cancel();
      _subnetScanner?.stop();
      _releaseMulticastLock();
      if (!controller.isClosed) {
        controller.close();
      }
    });

    controller.onCancel = () {
      mDnsSub?.cancel();
      subnetSub?.cancel();
      _subnetScanner?.stop();
      _releaseMulticastLock();
    };

    return controller.stream;
  }

  /// Stop ongoing discovery
  void stopDiscovery() {
    _castService?.stopDiscovery();
    _subnetScanner?.stop();
    _releaseMulticastLock();
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

    final castSubtitles = (subtitles ?? [])
        .map(
          (s) => CastSubtitle(
            url: s.url,
            label: s.name,
            language: s.language,
            format: s.url.toLowerCase().endsWith('.srt') ? 'srt' : 'vtt',
          ),
        )
        .toList();

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
    stopDiscovery();
    _subnetScanner?.dispose();
    _subnetScanner = null;
    _castService?.dispose();
    _castService = null;
    _activeSession = null;
    _activeDevice = null;
  }
}
