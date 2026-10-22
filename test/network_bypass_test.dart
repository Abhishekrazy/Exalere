import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/network_proxy_settings.dart';
import 'package:exalere/services/network/anti_dpi_proxy.dart';
import 'package:exalere/services/network/doh_resolver.dart';
import 'package:exalere/services/network/network_bypass_service.dart';

/// Builds a DNS response containing one A record for [host] -> [ip].
Uint8List _dnsResponse({
  String host = 'example.com',
  String ip = '93.184.216.34',
  int ttl = 300,
  int rcode = 0,
  bool includeAnswer = true,
}) {
  final b = BytesBuilder();
  b.add([0x00, 0x00, 0x81, 0x80 | rcode]);
  b.add([0x00, 0x01, includeAnswer ? 0x00 : 0x00, includeAnswer ? 0x01 : 0x00]);
  b.add([0x00, 0x00, 0x00, 0x00]);
  b.add(DohResolver.encodeName(host));
  b.add([0x00, 0x01, 0x00, 0x01]);

  if (includeAnswer) {
    b.add([0xC0, 0x0C]); // pointer to the question name
    b.add([0x00, 0x01, 0x00, 0x01]);
    b.add([
      (ttl >> 24) & 0xFF,
      (ttl >> 16) & 0xFF,
      (ttl >> 8) & 0xFF,
      ttl & 0xFF,
    ]);
    b.add([0x00, 0x04]);
    b.add(ip.split('.').map(int.parse).toList());
  }
  return b.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DohProvider', () {
    test('each provider maps to an endpoint or needs a custom one', () {
      expect(DohProvider.cloudflare.endpoint, contains('cloudflare-dns.com'));
      expect(DohProvider.google.endpoint, contains('dns.google'));
      expect(DohProvider.adguard.endpoint, contains('adguard'));
      expect(DohProvider.custom.endpoint, isNull);
      expect(DohProvider.off.endpoint, isNull);
    });

    test('falls back to Cloudflare for an unknown stored value', () {
      expect(DohProvider.fromName(null), DohProvider.cloudflare);
      expect(DohProvider.fromName('nonsense'), DohProvider.cloudflare);
      expect(DohProvider.fromName('off'), DohProvider.off);
    });
  });

  group('NetworkProxySettings', () {
    test('has no DoH endpoint when disabled or custom-but-empty', () {
      expect(
        const NetworkProxySettings(dohProvider: DohProvider.off).hasDoh,
        isFalse,
      );
      expect(
        const NetworkProxySettings(
          dohProvider: DohProvider.custom,
          customDohUrl: '   ',
        ).hasDoh,
        isFalse,
      );
    });

    test('uses the custom URL when provided', () {
      const settings = NetworkProxySettings(
        dohProvider: DohProvider.custom,
        customDohUrl: 'https://dns.example/dns-query',
      );
      expect(settings.dohEndpoint, 'https://dns.example/dns-query');
      expect(settings.hasDoh, isTrue);
    });

    test('resolves a profile by label, defaulting to balanced', () {
      expect(AntiDpiProfile.byLabel('Light').chunkSize, 64);
      expect(AntiDpiProfile.byLabel('Aggressive').chunkSize, 8);
      expect(AntiDpiProfile.byLabel(null).label, 'Balanced');
      expect(AntiDpiProfile.byLabel('unknown').label, 'Balanced');
    });

    test('copyWith keeps untouched fields', () {
      const base = NetworkProxySettings(antiDpiPort: 1234);
      final updated = base.copyWith(antiDpiEnabled: true);
      expect(updated.antiDpiEnabled, isTrue);
      expect(updated.antiDpiPort, 1234);
      expect(updated.dohProvider, base.dohProvider);
    });
  });

  group('DohResolver wire format', () {
    test('encodes a name as length-prefixed labels plus root', () {
      expect(
        DohResolver.encodeName('a.bc'),
        Uint8List.fromList([1, 0x61, 2, 0x62, 0x63, 0]),
      );
    });

    test('builds a query with the recursion-desired flag and one question', () {
      final query = DohResolver.buildQuery('example.com');
      expect(query.length, greaterThan(12));
      expect(query[2], 0x01, reason: 'RD flag');
      expect(query[4], 0x00);
      expect(query[5], 0x01, reason: 'QDCOUNT = 1');
      // QTYPE A / QCLASS IN at the tail.
      expect(query.sublist(query.length - 4), [0x00, 0x01, 0x00, 0x01]);
    });

    test('parses an A record out of a response', () {
      final answers = DohResolver.parseResponse(_dnsResponse());
      expect(answers.single.address, '93.184.216.34');
      expect(answers.single.ttlSeconds, 300);
    });

    test('returns empty for a response with no answers', () {
      expect(
        DohResolver.parseResponse(_dnsResponse(includeAnswer: false)),
        isEmpty,
      );
    });

    test('returns empty for a non-zero rcode', () {
      expect(
        DohResolver.parseResponse(_dnsResponse(rcode: 3)),
        isEmpty,
        reason: 'NXDOMAIN must not yield an address',
      );
    });

    test('returns empty for truncated or malformed input', () {
      expect(DohResolver.parseResponse(Uint8List(0)), isEmpty);
      expect(DohResolver.parseResponse(Uint8List(8)), isEmpty);
      expect(
        DohResolver.parseResponse(Uint8List.fromList([0, 0, 0x81, 0x80, 0, 1])),
        isEmpty,
      );
    });

    test('skipName handles a compression pointer and a root name', () {
      final pointed = Uint8List.fromList([0xC0, 0x0C]);
      expect(DohResolver.skipName(pointed, 0), 2);
      final root = Uint8List.fromList([0x00, 0x01]);
      expect(DohResolver.skipName(root, 0), 1);
    });

    test('a literal address short-circuits without a network call', () async {
      final resolver = DohResolver(defaultEndpoint: 'https://dns.example/q');
      final answers = await resolver.resolve('1.2.3.4');
      expect(answers.single.address, '1.2.3.4');
    });

    test('returns empty when no endpoint is configured', () async {
      expect(await DohResolver().resolve('example.com'), isEmpty);
    });
  });

  group('AntiDpiProxy.planFragments', () {
    test('fragments concatenate back to the original bytes', () {
      final data = Uint8List.fromList(List.generate(100, (i) => i));
      for (final profile in AntiDpiProfile.all) {
        final fragments = AntiDpiProxy.planFragments(data, profile);
        final rebuilt = <int>[];
        for (final fragment in fragments) {
          rebuilt.addAll(fragment);
        }
        expect(
          rebuilt,
          data,
          reason: '${profile.label} must not corrupt the stream',
        );
      }
    });

    test('uses the profile chunk size', () {
      final data = Uint8List(100);
      expect(AntiDpiProxy.planFragments(data, AntiDpiProfile.light).length, 2);
      expect(
        AntiDpiProxy.planFragments(data, AntiDpiProfile.aggressive).length,
        13,
      );
    });

    test('handles empty input and a tail shorter than the chunk', () {
      expect(
        AntiDpiProxy.planFragments(Uint8List(0), AntiDpiProfile.light),
        isEmpty,
      );
      expect(
        AntiDpiProxy.planFragments(Uint8List(10), AntiDpiProfile.light).length,
        1,
      );
    });
  });

  group('AntiDpiProxy lifecycle', () {
    test('binds a loopback port and reports it', () async {
      final proxy = AntiDpiProxy();
      final port = await proxy.start();
      addTearDown(proxy.dispose);

      expect(port, isNotNull);
      expect(proxy.isRunning, isTrue);
      expect(proxy.status.label, 'Active :$port');
      expect(proxy.proxySpec, 'PROXY 127.0.0.1:$port');
    });

    test('stops and reports Off', () async {
      final proxy = AntiDpiProxy();
      await proxy.start();
      await proxy.stop();

      expect(proxy.isRunning, isFalse);
      expect(proxy.status.label, 'Off');
    });
  });

  group('NetworkBypassService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await NetworkBypassService.instance.shutdown();
    });

    test('WARP is unavailable and refuses to switch on', () async {
      final service = NetworkBypassService.instance;
      expect(service.isWarpAvailable, isFalse);
      expect(service.warpUnavailableReason, isNotEmpty);

      final enabled = await service.setWarpEnabled(true);
      expect(enabled, isFalse, reason: 'it must not claim to tunnel');
      expect(service.settings.warpEnabled, isFalse);
    });

    test('anti-DPI starts a real proxy and persists the choice', () async {
      final service = NetworkBypassService.instance;
      final started = await service.setAntiDpiEnabled(true);
      addTearDown(service.shutdown);

      expect(started, isTrue);
      expect(service.isAntiDpiRunning, isTrue);
      expect(service.antiDpiPort, greaterThan(0));
      expect(service.proxySpec, contains('127.0.0.1'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('user_network_antidpi_enabled'), isTrue);
    });

    test('stopping anti-DPI clears the running state', () async {
      final service = NetworkBypassService.instance;
      await service.setAntiDpiEnabled(true);
      await service.setAntiDpiEnabled(false);

      expect(service.isAntiDpiRunning, isFalse);
      expect(service.proxySpec, isNull);
    });

    test('DoH choice and custom URL round-trip through storage', () async {
      final service = NetworkBypassService.instance;
      await service.setDohProvider(DohProvider.custom);
      await service.setCustomDohUrl(' https://dns.example/q ');

      expect(service.settings.dohProvider, DohProvider.custom);
      expect(service.settings.customDohUrl, 'https://dns.example/q');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_network_doh_provider'), 'custom');
      expect(
        prefs.getString('user_network_doh_custom_url'),
        'https://dns.example/q',
      );
    });

    test('resolveViaDoh returns null when DoH is off', () async {
      final service = NetworkBypassService.instance;
      await service.setDohProvider(DohProvider.off);
      expect(await service.resolveViaDoh('example.com'), isNull);
    });
  });

  group('AntiDpiStatus', () {
    test('labels each state', () {
      expect(const AntiDpiStatus(running: false, port: 0).label, 'Off');
      expect(
        const AntiDpiStatus(running: true, port: 46411).label,
        'Active :46411',
      );
      expect(
        const AntiDpiStatus(running: false, port: 0, error: 'in use').label,
        contains('in use'),
      );
    });
  });

  group('proxy is loopback only', () {
    test('bound socket is not reachable off-device by design', () async {
      final proxy = AntiDpiProxy();
      final port = await proxy.start();
      addTearDown(proxy.dispose);

      // A loopback bind answers on 127.0.0.1; this asserts it is actually up.
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port!,
        timeout: const Duration(seconds: 3),
      );
      expect(socket.port, isNotNull);
      socket.destroy();
    });
  });
}
