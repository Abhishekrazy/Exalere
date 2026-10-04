import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/media_item.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

/// Represents a discovered Exalere peer device on the local network.
class DiscoveredPeer {
  final String id;
  final String name;
  final String deviceType; // 'tv', 'mobile', 'desktop'
  final String address;
  final int port;
  final List<String> profileNames;
  DateTime lastSeen;

  DiscoveredPeer({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.address,
    required this.port,
    required this.profileNames,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'deviceType': deviceType,
    'address': address,
    'port': port,
    'profileNames': profileNames,
    'lastSeen': lastSeen.millisecondsSinceEpoch,
  };
}

/// Result of a peer synchronization operation.
class SyncResult {
  final bool success;
  final String peerName;
  final List<String> syncedProfiles;
  final int itemsUpdated;
  final String? errorMessage;

  SyncResult({
    required this.success,
    required this.peerName,
    this.syncedProfiles = const [],
    this.itemsUpdated = 0,
    this.errorMessage,
  });
}

/// Service handling local LAN peer-to-peer discovery and data synchronization.
class LanSyncService extends ChangeNotifier {
  static final LanSyncService _instance = LanSyncService._internal();
  factory LanSyncService() => _instance;
  LanSyncService._internal();

  static const int discoveryUdpPort = 8767;
  static const int defaultHttpPort = 8768;

  final StorageService _storageService = StorageService();

  bool _isEnabled = true;
  bool _isDiscovering = false;
  bool _isSyncing = false;
  DateTime? _lastSyncSuccessTime;
  String? _lastSyncError;

  String _deviceId = '';
  String _deviceName = '';
  String _deviceType = 'desktop';
  int _httpPort = defaultHttpPort;

  RawDatagramSocket? _udpSocket;
  HttpServer? _httpServer;
  Timer? _beaconTimer;
  Timer? _pruneTimer;

  final Map<String, DiscoveredPeer> _peersMap = {};

  /// Callback when local profile data is modified as a result of an incoming sync.
  VoidCallback? onProfileDataUpdated;

  bool get isEnabled => _isEnabled;
  bool get isDiscovering => _isDiscovering;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncSuccessTime => _lastSyncSuccessTime;
  String? get lastSyncError => _lastSyncError;
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;
  String get deviceType => _deviceType;
  int get httpPort => _httpPort;
  List<DiscoveredPeer> get discoveredPeers => _peersMap.values.toList();

  Future<void> init({bool isTv = false}) async {
    _isEnabled = await _storageService.getLanSyncEnabled();
    _deviceId = await _storageService.getDeviceId();
    final customName = await _storageService.getCustomDeviceName();

    if (customName != null && customName.isNotEmpty) {
      _deviceName = customName;
    } else {
      _deviceName = _generateDefaultDeviceName(isTv: isTv);
    }

    if (isTv) {
      _deviceType = 'tv';
    } else if (Platform.isAndroid || Platform.isIOS) {
      _deviceType = 'mobile';
    } else {
      _deviceType = 'desktop';
    }

    if (_isEnabled) {
      await startServer();
      await startDiscovery();
    }
  }

  String _generateDefaultDeviceName({required bool isTv}) {
    if (isTv) {
      return 'Exalere TV (${_deviceId.substring(_deviceId.length - 4)})';
    }
    if (Platform.isWindows) {
      final host = Platform.environment['COMPUTERNAME'] ?? 'Windows PC';
      return '$host (Exalere)';
    }
    if (Platform.isAndroid) {
      return 'Android Device (${_deviceId.substring(_deviceId.length - 4)})';
    }
    if (Platform.isMacOS) {
      return 'Mac (${_deviceId.substring(_deviceId.length - 4)})';
    }
    if (Platform.isLinux) {
      return 'Linux PC (${_deviceId.substring(_deviceId.length - 4)})';
    }
    return 'Exalere Device';
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _storageService.setLanSyncEnabled(enabled);
    if (enabled) {
      await startServer();
      await startDiscovery();
    } else {
      await stopDiscovery();
      await stopServer();
      _peersMap.clear();
    }
    notifyListeners();
  }

  Future<void> setCustomDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _deviceName = trimmed;
    await _storageService.setCustomDeviceName(trimmed);
    notifyListeners();
    if (_isEnabled) {
      await broadcastBeacon();
    }
  }

  /// Starts the local HTTP synchronization server.
  Future<void> startServer() async {
    if (_httpServer != null) return;
    try {
      try {
        _httpServer = await HttpServer.bind(
          InternetAddress.anyIPv4,
          defaultHttpPort,
          shared: true,
        );
        _httpPort = defaultHttpPort;
      } catch (_) {
        // Port 8768 may be occupied, bind to any available ephemeral port
        _httpServer = await HttpServer.bind(
          InternetAddress.anyIPv4,
          0,
          shared: true,
        );
        _httpPort = _httpServer!.port;
      }

      _httpServer!.listen(
        _handleHttpRequest,
        onError: (e) {
          debugPrint('[LanSync] HTTP server error: $e');
        },
      );
      debugPrint('[LanSync] HTTP server running on port $_httpPort');
    } catch (e) {
      debugPrint('[LanSync] Could not start HTTP server: $e');
    }
  }

  Future<void> stopServer() async {
    try {
      await _httpServer?.close(force: true);
      _httpServer = null;
    } catch (e) {
      debugPrint('[LanSync] Error closing HTTP server: $e');
    }
  }

  /// Handles incoming HTTP synchronization requests.
  Future<void> _handleHttpRequest(HttpRequest request) async {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (path == '/api/v1/ping' && request.method == 'GET') {
      final profiles = await _storageService.getProfiles();
      final body = jsonEncode({
        'status': 'ok',
        'app': 'exalere',
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'deviceType': _deviceType,
        'port': _httpPort,
        'profiles': profiles.map((p) => p.name).toList(),
      });
      request.response
        ..headers.contentType = ContentType.json
        ..statusCode = HttpStatus.ok
        ..write(body);
      await request.response.close();
      return;
    }

    if (path == '/api/v1/sync' && request.method == 'POST') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final Map<String, dynamic> body = jsonDecode(content);

        final String? incomingProfileName = body['profileName'] as String?;
        if (incomingProfileName == null || incomingProfileName.isEmpty) {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write(jsonEncode({'error': 'Missing profileName'}));
          await request.response.close();
          return;
        }

        final profiles = await _storageService.getProfiles();
        final matchingProfile = profiles.cast<UserProfile?>().firstWhere(
          (p) =>
              p?.name.trim().toLowerCase() ==
              incomingProfileName.trim().toLowerCase(),
          orElse: () => null,
        );

        if (matchingProfile == null) {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write(
              jsonEncode({
                'error':
                    'Profile "$incomingProfileName" not found on this device',
              }),
            );
          await request.response.close();
          return;
        }

        // Perform merge on matching profile
        final targetProfileId = matchingProfile.id;
        final mergedResult = await _mergeIncomingData(targetProfileId, body);

        // Notify app that profile data was refreshed
        onProfileDataUpdated?.call();

        // Return the freshly merged data to the caller
        request.response
          ..headers.contentType = ContentType.json
          ..statusCode = HttpStatus.ok
          ..write(jsonEncode(mergedResult));
        await request.response.close();
        return;
      } catch (e) {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'error': e.toString()}));
        await request.response.close();
        return;
      }
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not found');
    await request.response.close();
  }

  /// Merges incoming profile data bundle with local storage for [profileId].
  Future<Map<String, dynamic>> _mergeIncomingData(
    String profileId,
    Map<String, dynamic> remoteData,
  ) async {
    // 1. Favorites: Set union by ID
    final localFavorites = await _storageService.getFavorites(
      profileId: profileId,
    );
    final remoteFavoritesRaw = (remoteData['favorites'] as List? ?? []);
    final favMap = <String, MediaItem>{};
    for (final f in localFavorites) {
      favMap[f.id] = f;
    }
    for (final item in remoteFavoritesRaw) {
      try {
        final m = MediaItem.fromJson(item as Map<String, dynamic>);
        favMap[m.id] = m;
      } catch (_) {}
    }
    final mergedFavorites = favMap.values.toList();
    await _storageService.saveFavorites(mergedFavorites, profileId: profileId);

    // 2. Already Watched: Set union by ID
    final localAlreadyWatched = await _storageService.getAlreadyWatched(
      profileId: profileId,
    );
    final remoteAlreadyWatchedRaw =
        (remoteData['alreadyWatched'] as List? ?? []);
    final awMap = <String, MediaItem>{};
    for (final a in localAlreadyWatched) {
      awMap[a.id] = a;
    }
    for (final item in remoteAlreadyWatchedRaw) {
      try {
        final m = MediaItem.fromJson(item as Map<String, dynamic>);
        awMap[m.id] = m;
      } catch (_) {}
    }
    final mergedAlreadyWatched = awMap.values.toList();
    await _storageService.saveAlreadyWatched(
      mergedAlreadyWatched,
      profileId: profileId,
    );

    // 3. Watched Episodes: Map set union
    final localEpisodes = await _storageService.getAllWatchedEpisodes(
      profileId: profileId,
    );
    final remoteEpisodesRaw =
        (remoteData['watchedEpisodes'] as Map<String, dynamic>? ?? {});
    final mergedEpisodes = <String, Set<String>>{};
    for (final entry in localEpisodes.entries) {
      mergedEpisodes[entry.key] = Set.from(entry.value);
    }
    remoteEpisodesRaw.forEach((key, val) {
      if (val is List) {
        mergedEpisodes
            .putIfAbsent(key, () => <String>{})
            .addAll(val.map((e) => e.toString()));
      }
    });
    await _storageService.saveAllWatchedEpisodes(
      mergedEpisodes,
      profileId: profileId,
    );

    // 4. Watch History: LWW (Last-Write-Wins)
    final localHistory = await _storageService.getWatchHistory(
      profileId: profileId,
    );
    final remoteHistoryRaw = (remoteData['watchHistory'] as List? ?? []);
    final histMap = <String, WatchHistoryItem>{};

    String histKey(WatchHistoryItem h) {
      if (h.season != null && h.episode != null) {
        return '${h.item.id}_s${h.season}_e${h.episode}';
      }
      return h.item.id;
    }

    for (final h in localHistory) {
      histMap[histKey(h)] = h;
    }

    for (final raw in remoteHistoryRaw) {
      try {
        final remoteH = WatchHistoryItem.fromJson(raw as Map<String, dynamic>);
        final key = histKey(remoteH);
        final localH = histMap[key];

        if (localH == null) {
          histMap[key] = remoteH;
        } else {
          // Last write wins by timestamp
          if (remoteH.lastWatchedTimestamp > localH.lastWatchedTimestamp) {
            histMap[key] = remoteH;
          } else if (remoteH.lastWatchedTimestamp ==
              localH.lastWatchedTimestamp) {
            if (remoteH.isWatched && !localH.isWatched) {
              histMap[key] = remoteH;
            } else if (remoteH.positionSeconds > localH.positionSeconds) {
              histMap[key] = remoteH;
            }
          }
        }
      } catch (_) {}
    }

    final mergedHistory = histMap.values.toList()
      ..sort(
        (a, b) => b.lastWatchedTimestamp.compareTo(a.lastWatchedTimestamp),
      );
    final trimmedHistory = mergedHistory.take(50).toList();
    await _storageService.saveWatchHistory(
      trimmedHistory,
      profileId: profileId,
    );

    return {
      'success': true,
      'profileName': remoteData['profileName'],
      'favorites': mergedFavorites.map((f) => f.toJson()).toList(),
      'alreadyWatched': mergedAlreadyWatched.map((a) => a.toJson()).toList(),
      'watchHistory': trimmedHistory.map((h) => h.toJson()).toList(),
      'watchedEpisodes': mergedEpisodes.map((k, v) => MapEntry(k, v.toList())),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Starts UDP discovery listener and beacon broadcaster.
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    notifyListeners();

    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryUdpPort,
        reuseAddress: true,
        reusePort: false,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen(
        _handleUdpPacket,
        onError: (e) {
          debugPrint('[LanSync] UDP socket error: $e');
        },
      );
      debugPrint('[LanSync] UDP discovery listening on port $discoveryUdpPort');
    } catch (e) {
      debugPrint('[LanSync] Could not bind UDP discovery socket: $e');
    }

    // Broadcast immediately, then every 12 seconds
    await broadcastBeacon();
    _beaconTimer?.cancel();
    _beaconTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      broadcastBeacon();
    });

    // Prune stale peers every 20 seconds
    _pruneTimer?.cancel();
    _pruneTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _pruneStalePeers();
    });
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    try {
      _udpSocket?.close();
      _udpSocket = null;
    } catch (e) {
      debugPrint('[LanSync] Error closing UDP socket: $e');
    }
    notifyListeners();
  }

  /// Broadcasts a UDP beacon announcing this device's presence and profiles.
  Future<void> broadcastBeacon() async {
    if (!_isEnabled) return;
    try {
      final profiles = await _storageService.getProfiles();
      final packet = {
        'app': 'exalere',
        'type': 'beacon',
        'version': 1,
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'deviceType': _deviceType,
        'port': _httpPort,
        'profiles': profiles.map((p) => p.name).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final data = utf8.encode(jsonEncode(packet));

      // 1. Send via existing socket or ephemeral socket
      RawDatagramSocket senderSocket;
      bool shouldClose = false;
      if (_udpSocket != null) {
        senderSocket = _udpSocket!;
      } else {
        senderSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        senderSocket.broadcastEnabled = true;
        shouldClose = true;
      }

      // Broadcast to standard broadcast address
      senderSocket.send(
        data,
        InternetAddress('255.255.255.255'),
        discoveryUdpPort,
      );

      // Also broadcast to all active network interface broadcast addresses
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final bcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                senderSocket.send(
                  data,
                  InternetAddress(bcast),
                  discoveryUdpPort,
                );
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Also broadcast to loopback for local testing
      try {
        senderSocket.send(data, InternetAddress.loopbackIPv4, discoveryUdpPort);
      } catch (_) {}

      if (shouldClose) {
        senderSocket.close();
      }
    } catch (e) {
      debugPrint('[LanSync] Error broadcasting beacon: $e');
    }
  }

  void _handleUdpPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udpSocket == null) return;
    final datagram = _udpSocket!.receive();
    if (datagram == null) return;

    try {
      final message = utf8.decode(datagram.data);
      final Map<String, dynamic> data = jsonDecode(message);

      if (data['app'] != 'exalere') return;
      final peerDeviceId = data['deviceId'] as String?;
      if (peerDeviceId == null || peerDeviceId == _deviceId) {
        // Ignore own beacon
        return;
      }

      final peerName = data['deviceName'] as String? ?? 'Exalere Device';
      final peerType = data['deviceType'] as String? ?? 'device';
      final peerPort = (data['port'] as num?)?.toInt() ?? defaultHttpPort;
      final profilesList = (data['profiles'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      final senderIp = datagram.address.address;

      final existing = _peersMap[peerDeviceId];
      if (existing != null) {
        existing.lastSeen = DateTime.now();
      } else {
        _peersMap[peerDeviceId] = DiscoveredPeer(
          id: peerDeviceId,
          name: peerName,
          deviceType: peerType,
          address: senderIp,
          port: peerPort,
          profileNames: profilesList,
          lastSeen: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  void _pruneStalePeers() {
    final now = DateTime.now();
    bool changed = false;
    _peersMap.removeWhere((_, peer) {
      final isStale = now.difference(peer.lastSeen).inSeconds > 45;
      if (isStale) changed = true;
      return isStale;
    });
    if (changed) {
      notifyListeners();
    }
  }

  /// Synchronizes with a discovered peer for all matching profile names.
  Future<SyncResult> syncWithPeer(DiscoveredPeer peer) async {
    return _syncWithTarget(
      host: peer.address,
      port: peer.port,
      targetPeerName: peer.name,
      targetProfileNames: peer.profileNames,
    );
  }

  /// Manually synchronizes with a device at a specific IP and port (e.g. for AP-isolated Wi-Fi).
  Future<SyncResult> syncWithAddress(
    String host, {
    int port = defaultHttpPort,
  }) async {
    final cleanHost = host.trim();
    if (cleanHost.isEmpty) {
      return SyncResult(
        success: false,
        peerName: host,
        errorMessage: 'Invalid IP address',
      );
    }

    try {
      // Handshake ping first
      final pingUrl = Uri.parse('http://$cleanHost:$port/api/v1/ping');
      final pingRes = await http
          .get(pingUrl)
          .timeout(const Duration(seconds: 4));
      if (pingRes.statusCode != 200) {
        return SyncResult(
          success: false,
          peerName: host,
          errorMessage: 'Device replied with status ${pingRes.statusCode}',
        );
      }
      final info = jsonDecode(pingRes.body) as Map<String, dynamic>;
      final peerName = info['deviceName'] as String? ?? cleanHost;
      final profileNames = (info['profiles'] as List? ?? [])
          .map((e) => e.toString())
          .toList();

      return _syncWithTarget(
        host: cleanHost,
        port: port,
        targetPeerName: peerName,
        targetProfileNames: profileNames,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        peerName: host,
        errorMessage: 'Could not connect to $cleanHost:$port ($e)',
      );
    }
  }

  Future<SyncResult> _syncWithTarget({
    required String host,
    required int port,
    required String targetPeerName,
    required List<String> targetProfileNames,
  }) async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        peerName: targetPeerName,
        errorMessage: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    final syncedProfiles = <String>[];
    int totalItemsUpdated = 0;

    try {
      final localProfiles = await _storageService.getProfiles();

      // Find matching profiles by name (case-insensitive)
      final commonProfiles = <UserProfile>[];
      for (final lp in localProfiles) {
        final matches = targetProfileNames.any(
          (tp) => tp.trim().toLowerCase() == lp.name.trim().toLowerCase(),
        );
        if (matches) {
          commonProfiles.add(lp);
        }
      }

      if (commonProfiles.isEmpty) {
        _isSyncing = false;
        _lastSyncError = 'No matching profile names found between devices';
        notifyListeners();
        return SyncResult(
          success: false,
          peerName: targetPeerName,
          errorMessage: _lastSyncError,
        );
      }

      for (final profile in commonProfiles) {
        final localFavorites = await _storageService.getFavorites(
          profileId: profile.id,
        );
        final localAlreadyWatched = await _storageService.getAlreadyWatched(
          profileId: profile.id,
        );
        final localHistory = await _storageService.getWatchHistory(
          profileId: profile.id,
        );
        final localEpisodes = await _storageService.getAllWatchedEpisodes(
          profileId: profile.id,
        );

        final payload = {
          'senderDeviceId': _deviceId,
          'senderDeviceName': _deviceName,
          'profileName': profile.name,
          'favorites': localFavorites.map((f) => f.toJson()).toList(),
          'alreadyWatched': localAlreadyWatched.map((a) => a.toJson()).toList(),
          'watchHistory': localHistory.map((h) => h.toJson()).toList(),
          'watchedEpisodes': localEpisodes.map(
            (k, v) => MapEntry(k, v.toList()),
          ),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final syncUri = Uri.parse('http://$host:$port/api/v1/sync');
        final response = await http
            .post(
              syncUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final Map<String, dynamic> remoteMerged = jsonDecode(response.body);

          // Update our local storage with the merged data returned from the peer
          await _mergeIncomingData(profile.id, remoteMerged);
          syncedProfiles.add(profile.name);
          totalItemsUpdated +=
              (remoteMerged['favorites'] as List? ?? []).length +
              (remoteMerged['watchHistory'] as List? ?? []).length;
        } else {
          debugPrint(
            '[LanSync] Peer responded with status ${response.statusCode}',
          );
        }
      }

      _lastSyncSuccessTime = DateTime.now();
      _lastSyncError = null;
      _isSyncing = false;

      // Notify UI listeners to update continue watching and library
      onProfileDataUpdated?.call();
      notifyListeners();

      return SyncResult(
        success: true,
        peerName: targetPeerName,
        syncedProfiles: syncedProfiles,
        itemsUpdated: totalItemsUpdated,
      );
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return SyncResult(
        success: false,
        peerName: targetPeerName,
        errorMessage: _lastSyncError,
      );
    }
  }

  @override
  void dispose() {
    stopDiscovery();
    stopServer();
    super.dispose();
  }
}
