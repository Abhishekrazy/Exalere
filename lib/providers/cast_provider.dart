import 'dart:async';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';

import '../models/media_item.dart';
import '../models/stream_source.dart';
import '../services/cast_service.dart';

/// Provider managing active Cast state, device discovery, session
/// playback state, scrubbing, and volume control.
class CastProvider extends ChangeNotifier {
  final AppCastService _castService = AppCastService();

  List<CastDevice> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _isConnecting = false;
  String? _errorMessage;

  CastDevice? _connectedDevice;
  CastSession? _session;
  SessionState _sessionState = SessionState.disconnected;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  MediaItem? _currentMediaItem;
  StreamSource? _currentStreamSource;

  StreamSubscription<List<CastDevice>>? _discoverySub;
  StreamSubscription<SessionState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<double>? _volumeSub;

  // Getters
  List<CastDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isDiscovering => _isDiscovering;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  CastDevice? get connectedDevice => _connectedDevice;
  SessionState get sessionState => _sessionState;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  MediaItem? get currentMediaItem => _currentMediaItem;
  StreamSource? get currentStreamSource => _currentStreamSource;

  bool get isConnected =>
      _connectedDevice != null && _sessionState != SessionState.disconnected;

  bool get isCasting =>
      isConnected &&
      (_sessionState == SessionState.playing ||
          _sessionState == SessionState.paused ||
          _sessionState == SessionState.buffering ||
          _sessionState == SessionState.loading);

  bool get isPlaying => _sessionState == SessionState.playing;
  bool get isPaused => _sessionState == SessionState.paused;
  bool get isBuffering =>
      _sessionState == SessionState.buffering ||
      _sessionState == SessionState.loading;

  /// Start discovering casting targets (Chromecast, DLNA, AirPlay)
  void startDiscovery({Duration timeout = const Duration(seconds: 15)}) {
    _discoverySub?.cancel();
    _discoveredDevices = [];
    _isDiscovering = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _discoverySub = _castService
          .discoverDevices(timeout: timeout)
          .listen(
            (devices) {
              _discoveredDevices = devices;
              notifyListeners();
            },
            onError: (err) {
              debugPrint('CastProvider: Discovery error: $err');
              _isDiscovering = false;
              _errorMessage = 'Discovery failed: $err';
              notifyListeners();
            },
            onDone: () {
              _isDiscovering = false;
              notifyListeners();
            },
          );
    } catch (e) {
      debugPrint('CastProvider: Failed to start discovery: $e');
      _isDiscovering = false;
      _errorMessage = 'Could not start discovery: $e';
      notifyListeners();
    }
  }

  /// Stop active network discovery
  void stopDiscovery() {
    _discoverySub?.cancel();
    _discoverySub = null;
    _castService.stopDiscovery();
    _isDiscovering = false;
    notifyListeners();
  }

  /// Connect to device and initiate playback of media
  Future<bool> connectAndCast({
    required CastDevice device,
    required MediaItem item,
    required StreamSource source,
    Duration? startPosition,
    List<SubtitleOption>? subtitles,
  }) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _castService.connect(device);
      _connectedDevice = device;
      _session = session;
      _currentMediaItem = item;
      _currentStreamSource = source;

      _bindSession(session);

      await _castService.loadMedia(
        session: session,
        item: item,
        source: source,
        startPosition: startPosition,
        subtitles: subtitles,
      );

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CastProvider: Error connecting and casting: $e');
      _isConnecting = false;
      _errorMessage = 'Failed to cast to ${device.name}: $e';
      notifyListeners();
      return false;
    }
  }

  void _bindSession(CastSession session) {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();

    _sessionState = session.state;
    _position = session.position;
    _duration = session.duration;

    _stateSub = session.stateStream.listen(
      (state) {
        _sessionState = state;
        if (state == SessionState.disconnected) {
          _connectedDevice = null;
          _session = null;
          _currentMediaItem = null;
          _currentStreamSource = null;
        }
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('CastProvider: session state error: $err');
        _errorMessage = 'Session error: $err';
        notifyListeners();
      },
    );

    _positionSub = session.positionStream.listen(
      (pos) {
        _position = pos;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('CastProvider: position error: $err');
      },
    );

    _durationSub = session.durationStream.listen(
      (dur) {
        _duration = dur;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('CastProvider: duration error: $err');
      },
    );

    _volumeSub = session.volumeStream.listen(
      (vol) {
        _volume = vol;
        notifyListeners();
      },
      onError: (Object err) {
        debugPrint('CastProvider: volume error: $err');
      },
    );
  }

  Future<void> play() async {
    try {
      await _session?.play();
    } catch (e) {
      debugPrint('CastProvider: Error playing: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _session?.pause();
    } catch (e) {
      debugPrint('CastProvider: Error pausing: $e');
    }
  }

  Future<void> playOrPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    try {
      await _session?.stop();
    } catch (e) {
      debugPrint('CastProvider: Error stopping: $e');
    }
  }

  Future<void> seek(Duration targetPosition) async {
    try {
      await _session?.seek(targetPosition);
    } catch (e) {
      debugPrint('CastProvider: Error seeking: $e');
    }
  }

  Future<void> setVolume(double vol) async {
    try {
      await _session?.setVolume(vol.clamp(0.0, 1.0));
      _volume = vol;
      notifyListeners();
    } catch (e) {
      debugPrint('CastProvider: Error setting volume: $e');
    }
  }

  Future<void> disconnect() async {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();

    await _castService.disconnect();

    _connectedDevice = null;
    _session = null;
    _sessionState = SessionState.disconnected;
    _currentMediaItem = null;
    _currentStreamSource = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _volumeSub?.cancel();
    _castService.dispose();
    super.dispose();
  }
}
