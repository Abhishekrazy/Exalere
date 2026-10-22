import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/network/warp_registration_client.dart';
import 'package:exalere/services/network/warp_service.dart';
import 'package:exalere/services/network/warp_tunnel.dart';

/// A tunnel whose behaviour each test controls, so the orchestration can be
/// proven without a native module or a network.
class _FakeTunnel implements WarpTunnel {
  _FakeTunnel({
    this.supported = true,
    this.startSucceeds = true,
    this.reportsRunning = true,
    this.keyPair = const WarpKeyPair(privateKey: 'priv=', publicKey: 'pub='),
  });

  bool supported;
  bool startSucceeds;
  bool reportsRunning;
  WarpKeyPair? keyPair;

  int startCalls = 0;
  int stopCalls = 0;
  int keygenCalls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<WarpKeyPair?> generateKeyPair() async {
    keygenCalls++;
    return keyPair;
  }

  @override
  Future<bool> start({
    required WarpConfig config,
    required String privateKey,
  }) async {
    startCalls++;
    return startSucceeds;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<WarpTunnelState> state() async =>
      WarpTunnelState(running: reportsRunning, error: 'tunnel refused');
}

/// Registration client that always fails, to prove the error path is surfaced.
class _FailingRegistration implements WarpRegistrationClient {
  @override
  Future<WarpConfig> register({
    required String publicKeyBase64,
    String deviceModel = 'PC',
  }) async => throw WarpRegistrationException('Cloudflare said no');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WarpService without a native module', () {
    test('reports unavailable and refuses to enable', () async {
      final service = WarpService(
        tunnel: _FakeTunnel(supported: false),
        registrationClient: _FailingRegistration(),
      );

      await service.initialize();

      expect(service.status, WarpStatus.unavailable);
      expect(service.isSupported, isFalse);
      expect(service.unavailableReason, isNotNull);
      expect(await service.enable(), isFalse);
      expect(service.status, WarpStatus.unavailable);
    });
  });

  group('WarpService enable', () {
    test('registers once, starts the tunnel and reports connected', () async {
      final tunnel = _FakeTunnel();
      final service = WarpService(
        tunnel: tunnel,
        registrationClient: _StubRegistration(),
      );

      await service.initialize();
      expect(service.status, WarpStatus.idle);

      final ok = await service.enable();

      expect(ok, isTrue);
      expect(service.status, WarpStatus.connected);
      expect(tunnel.keygenCalls, 1);
      expect(tunnel.startCalls, 1);
      expect(service.config, isNotNull);
    });

    test('does not re-register on a second enable', () async {
      final tunnel = _FakeTunnel();
      final service = WarpService(
        tunnel: tunnel,
        registrationClient: _StubRegistration(),
      );
      await service.initialize();
      await service.enable();
      await service.disable();
      await service.enable();

      expect(
        tunnel.keygenCalls,
        1,
        reason: 'the provisioned profile should be reused',
      );
      expect(tunnel.startCalls, 2);
    });

    test('fails clearly when the device cannot make a keypair', () async {
      final service = WarpService(
        tunnel: _FakeTunnel(keyPair: null),
        registrationClient: _StubRegistration(),
      );
      await service.initialize();

      expect(await service.enable(), isFalse);
      expect(service.status, WarpStatus.error);
      expect(service.errorMessage, contains('keypair'));
    });

    test('surfaces a registration failure', () async {
      final service = WarpService(
        tunnel: _FakeTunnel(),
        registrationClient: _FailingRegistration(),
      );
      await service.initialize();

      expect(await service.enable(), isFalse);
      expect(service.status, WarpStatus.error);
      expect(service.errorMessage, contains('Cloudflare said no'));
    });

    test('fails when the tunnel refuses to start', () async {
      final service = WarpService(
        tunnel: _FakeTunnel(startSucceeds: false),
        registrationClient: _StubRegistration(),
      );
      await service.initialize();

      expect(await service.enable(), isFalse);
      expect(service.errorMessage, contains('did not start'));
    });

    test(
      'fails when the tunnel claims success but reports not running',
      () async {
        final service = WarpService(
          tunnel: _FakeTunnel(reportsRunning: false),
          registrationClient: _StubRegistration(),
        );
        await service.initialize();

        expect(await service.enable(), isFalse);
        expect(service.status, WarpStatus.error);
        expect(
          service.errorMessage,
          contains('tunnel refused'),
          reason: 'the native error should be passed through, not swallowed',
        );
      },
    );

    test('persists the enabled flag only on success', () async {
      final failing = WarpService(
        tunnel: _FakeTunnel(startSucceeds: false),
        registrationClient: _StubRegistration(),
      );
      await failing.initialize();
      await failing.enable();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('user_warp_enabled'),
        isNot(isTrue),
        reason: 'a failed connect must not be restored on next launch',
      );
    });
  });

  group('WarpService disable and forget', () {
    test('disable stops the tunnel and returns to idle', () async {
      final tunnel = _FakeTunnel();
      final service = WarpService(
        tunnel: tunnel,
        registrationClient: _StubRegistration(),
      );
      await service.initialize();
      await service.enable();
      await service.disable();

      expect(tunnel.stopCalls, 1);
      expect(service.status, WarpStatus.idle);
      expect(service.isConnected, isFalse);
    });

    test(
      'forgetDevice clears the profile so the next enable re-registers',
      () async {
        final tunnel = _FakeTunnel();
        final service = WarpService(
          tunnel: tunnel,
          registrationClient: _StubRegistration(),
        );
        await service.initialize();
        await service.enable();
        await service.forgetDevice();

        expect(service.config, isNull);
        expect(service.status, WarpStatus.idle);

        await service.enable();
        expect(
          tunnel.keygenCalls,
          2,
          reason: 'a forgotten device registers again',
        );
      },
    );
  });

  group('WarpStatus', () {
    test('every status has a label', () {
      for (final status in WarpStatus.values) {
        expect(status.label, isNotEmpty);
      }
    });
  });
}

/// Registration client returning a fixed usable profile.
class _StubRegistration implements WarpRegistrationClient {
  @override
  Future<WarpConfig> register({
    required String publicKeyBase64,
    String deviceModel = 'PC',
  }) async => const WarpConfig(
    accountId: 'acct',
    accessToken: 'tok',
    peerPublicKey: 'peer=',
    endpointHost: '162.159.192.1',
    endpointPort: 2408,
    ipv4: '172.16.0.2',
    ipv6: '',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
