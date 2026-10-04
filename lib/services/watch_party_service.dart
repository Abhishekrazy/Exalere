import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Sync state packet exchanged between watch party peers.
class WatchPartyState {
  final String partyId;
  final String hostName;
  final String mediaId;
  final String mediaTitle;
  final int positionMs;
  final bool isPlaying;
  final double speed;
  final int timestamp;

  const WatchPartyState({
    required this.partyId,
    required this.hostName,
    required this.mediaId,
    required this.mediaTitle,
    required this.positionMs,
    required this.isPlaying,
    this.speed = 1.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'partyId': partyId,
    'hostName': hostName,
    'mediaId': mediaId,
    'mediaTitle': mediaTitle,
    'positionMs': positionMs,
    'isPlaying': isPlaying,
    'speed': speed,
    'timestamp': timestamp,
  };

  factory WatchPartyState.fromJson(Map<String, dynamic> json) {
    return WatchPartyState(
      partyId: json['partyId']?.toString() ?? '',
      hostName: json['hostName']?.toString() ?? 'Host',
      mediaId: json['mediaId']?.toString() ?? '',
      mediaTitle: json['mediaTitle']?.toString() ?? '',
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      isPlaying: json['isPlaying'] as bool? ?? false,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service orchestrating real-time LAN Watch Party sessions between Exalere devices.
class WatchPartyService extends ChangeNotifier {
  static final WatchPartyService _instance = WatchPartyService._internal();
  factory WatchPartyService() => _instance;
  WatchPartyService._internal();

  static const int syncPort = 8769;

  bool _isHosting = false;
  bool _isConnected = false;
  String? _currentPartyPin;
  String _hostAddress = '';
  int _connectedClientsCount = 0;
  WatchPartyState? _lastState;

  RawDatagramSocket? _socket;
  Timer? _hostBroadcastTimer;

  bool get isHosting => _isHosting;
  bool get isConnected => _isConnected;
  bool get isInParty => _isHosting || _isConnected;
  String? get currentPartyPin => _currentPartyPin;
  String get hostAddress => _hostAddress;
  int get connectedClientsCount => _connectedClientsCount;
  WatchPartyState? get lastState => _lastState;

  final StreamController<WatchPartyState> _stateStreamController =
      StreamController<WatchPartyState>.broadcast();
  Stream<WatchPartyState> get onSyncReceived => _stateStreamController.stream;

  /// Starts hosting a Watch Party session.
  Future<String> startHosting({
    required String hostName,
    required String mediaId,
    required String mediaTitle,
  }) async {
    await stopParty();

    final pin = (1000 + (DateTime.now().millisecond % 9000)).toString();
    _currentPartyPin = pin;
    _isHosting = true;
    _connectedClientsCount = 1;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        syncPort,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram == null) return;
          try {
            final payload = utf8.decode(datagram.data);
            final data = jsonDecode(payload);
            if (data['type'] == 'join' && data['pin'] == _currentPartyPin) {
              _connectedClientsCount++;
              notifyListeners();
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[WatchPartyService] Socket bind error: $e');
    }

    notifyListeners();
    return pin;
  }

  /// Broadcasts host position and play/pause status to all listening clients.
  void broadcastState({
    required String hostName,
    required String mediaId,
    required String mediaTitle,
    required int positionMs,
    required bool isPlaying,
    double speed = 1.0,
  }) {
    if (!_isHosting || _socket == null) return;

    final state = WatchPartyState(
      partyId: _currentPartyPin ?? '0000',
      hostName: hostName,
      mediaId: mediaId,
      mediaTitle: mediaTitle,
      positionMs: positionMs,
      isPlaying: isPlaying,
      speed: speed,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    _lastState = state;

    final packet = jsonEncode({
      'type': 'sync',
      'pin': _currentPartyPin,
      'state': state.toJson(),
    });

    try {
      final bytes = utf8.encode(packet);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), syncPort);
    } catch (e) {
      debugPrint('[WatchPartyService] Broadcast error: $e');
    }
  }

  /// Joins an existing party using host IP or broadcast listener.
  Future<bool> joinParty({required String pin, String? hostIp}) async {
    await stopParty();

    _currentPartyPin = pin;
    _isConnected = true;
    _hostAddress = hostIp ?? 'LAN Broadcast';

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        syncPort,
        reuseAddress: true,
      );
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram == null) return;
          try {
            final payload = utf8.decode(datagram.data);
            final data = jsonDecode(payload);
            if (data['type'] == 'sync' && data['pin'] == _currentPartyPin) {
              final st = WatchPartyState.fromJson(data['state']);
              _lastState = st;
              _stateStreamController.add(st);
              notifyListeners();
            }
          } catch (_) {}
        }
      });

      // Send join announcement
      final joinPacket = jsonEncode({'type': 'join', 'pin': pin});
      final bytes = utf8.encode(joinPacket);
      _socket?.send(bytes, InternetAddress('255.255.255.255'), syncPort);
    } catch (e) {
      debugPrint('[WatchPartyService] Join error: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// Disconnects from current party and releases sockets.
  Future<void> stopParty() async {
    _hostBroadcastTimer?.cancel();
    _socket?.close();
    _socket = null;
    _isHosting = false;
    _isConnected = false;
    _currentPartyPin = null;
    _connectedClientsCount = 0;
    _lastState = null;
    notifyListeners();
  }
}
