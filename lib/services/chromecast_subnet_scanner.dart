import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fallback and parallel scanner that discovers Google Cast / Chromecast devices
/// across local network subnets by probing HTTP Eureka info (port 8008) and
/// CASTV2 TLS (port 8009).
///
/// This provides guaranteed device discovery even on restrictive Wi-Fi routers
/// where UDP mDNS multicast (224.0.0.251:5353) is filtered, dropped, or
/// blocked by AP Isolation or IGMP snooping.
class ChromecastSubnetScanner {
  final http.Client _client = http.Client();
  bool _isScanning = false;

  /// Scans local subnets for Chromecast devices and yields each discovered [CastDevice].
  Stream<CastDevice> scan({
    Duration timeout = const Duration(seconds: 4),
  }) async* {
    if (_isScanning) return;
    _isScanning = true;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidateIps = <String>{};
      final ownIps = <String>{};

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          ownIps.add(addr.address);
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            for (int i = 1; i <= 254; i++) {
              final ip = '$prefix.$i';
              if (!ownIps.contains(ip)) {
                candidateIps.add(ip);
              }
            }
          }
        }
      }

      if (candidateIps.isEmpty) return;

      final controller = StreamController<CastDevice>();
      final seenDeviceIds = <String>{};

      // Process in concurrent batches of 40 to avoid socket exhaustion
      const batchSize = 40;
      final ipList = candidateIps.toList();

      Future<void> runScan() async {
        for (int i = 0; i < ipList.length; i += batchSize) {
          if (!_isScanning) break;
          final batch = ipList.sublist(
            i,
            (i + batchSize > ipList.length) ? ipList.length : i + batchSize,
          );

          await Future.wait(
            batch.map((ip) async {
              if (!_isScanning) return;
              try {
                final device = await _probeIp(ip);
                if (device != null &&
                    !seenDeviceIds.contains(device.id) &&
                    !ownIps.contains(device.address.address)) {
                  seenDeviceIds.add(device.id);
                  if (!controller.isClosed) {
                    controller.add(device);
                  }
                }
              } catch (_) {}
            }),
          );
        }
        if (!controller.isClosed) {
          await controller.close();
        }
      }

      runScan();

      yield* controller.stream.timeout(
        timeout,
        onTimeout: (sink) {
          _isScanning = false;
          sink.close();
        },
      );
    } catch (e) {
      debugPrint('ChromecastSubnetScanner error: $e');
    } finally {
      _isScanning = false;
    }
  }

  /// Stop scanning immediately
  void stop() {
    _isScanning = false;
  }

  Future<CastDevice?> _probeIp(String ip) async {
    // 1. Try Google Cast HTTP Eureka endpoint (port 8008)
    try {
      final uri = Uri.parse(
        'http://$ip:8008/setup/eureka_info?params=name,device_info',
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(milliseconds: 700));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final friendlyName =
            data['name'] as String? ??
            (data['device_info'] as Map<String, dynamic>?)?['model_name']
                as String? ??
            'Chromecast';

        final deviceInfo = data['device_info'] as Map<String, dynamic>?;
        final model = deviceInfo?['model_name'] as String? ?? 'Chromecast';
        final deviceId =
            deviceInfo?['cloud_device_id'] as String? ??
            deviceInfo?['mac_address'] as String? ??
            ip;

        return CastDevice(
          id: deviceId,
          name: friendlyName,
          protocol: CastProtocol.chromecast,
          address: InternetAddress(ip),
          port: 8009,
          metadata: {'fn': friendlyName, 'md': model, 'id': deviceId},
        );
      }
    } catch (_) {}

    // 2. Fallback: Quick TCP socket test on CastV2 TLS port 8009
    try {
      final socket = await Socket.connect(
        ip,
        8009,
        timeout: const Duration(milliseconds: 400),
      );
      socket.destroy();

      // If port 8009 is open, it is a CastV2 receiver. Re-check eureka info on 8008 with slightly longer timeout
      try {
        final uri = Uri.parse('http://$ip:8008/setup/eureka_info');
        final response = await _client
            .get(uri)
            .timeout(const Duration(milliseconds: 800));
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final friendlyName = data['name'] as String? ?? 'Chromecast';
          return CastDevice(
            id: ip,
            name: friendlyName,
            protocol: CastProtocol.chromecast,
            address: InternetAddress(ip),
            port: 8009,
            metadata: {'fn': friendlyName, 'md': 'Chromecast'},
          );
        }
      } catch (_) {}

      return CastDevice(
        id: ip,
        name: 'Chromecast ($ip)',
        protocol: CastProtocol.chromecast,
        address: InternetAddress(ip),
        port: 8009,
        metadata: {'fn': 'Chromecast ($ip)', 'md': 'Google Cast'},
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _isScanning = false;
    _client.close();
  }
}
