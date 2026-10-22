import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:exalere/services/network/warp_registration_client.dart';

/// Cloudflare's registration response shape, as observed in the reference client:
/// the payload is wrapped in `result`, the peer carries the endpoint, and the
/// interface carries the addresses.
String _successBody() => json.encode({
  'result': {
    'id': 'acct-123',
    'token': 'tok-abc',
    'config': {
      'interface': {
        'addresses': {'v4': '172.16.0.2', 'v6': '2606:4700:110::2'},
      },
      'peers': [
        {
          'public_key': 'peerPubKeyBase64=',
          'endpoint': {
            'v4': '162.159.192.1:0',
            'v6': '[2606:4700:d0::a29f:c001]:0',
          },
        },
      ],
    },
  },
});

void main() {
  group('WarpRegistrationClient.register', () {
    test('parses a successful registration', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/v0a4471/reg'));
        expect(request.method, 'POST');
        expect(request.headers['CF-Client-Version'], 'a-6.35-4471');
        return http.Response(_successBody(), 200);
      });

      final config = await WarpRegistrationClient(
        client: client,
      ).register(publicKeyBase64: 'myPublicKey=');

      expect(config.accountId, 'acct-123');
      expect(config.accessToken, 'tok-abc');
      expect(config.peerPublicKey, 'peerPubKeyBase64=');
      expect(config.endpointHost, '162.159.192.1');
      expect(config.ipv4, '172.16.0.2');
      expect(config.isUsable, isTrue);
    });

    test('sends the WireGuard tunnel type, not MASQUE', () async {
      late Map<String, dynamic> sent;
      final client = MockClient((request) async {
        sent = json.decode(request.body) as Map<String, dynamic>;
        return http.Response(_successBody(), 200);
      });

      await WarpRegistrationClient(
        client: client,
      ).register(publicKeyBase64: 'k=');

      expect(sent['key_type'], 'curve25519');
      expect(
        sent['tunnel_type'],
        'wireguard',
        reason: 'MASQUE would require the GPL client binary',
      );
      expect(sent['key'], 'k=');
      expect(sent['tos'], isNotEmpty);
      expect(sent['serial_number'], isNotEmpty);
    });

    test('rejects a missing public key before any request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response(_successBody(), 200);
      });

      expect(
        () => WarpRegistrationClient(
          client: client,
        ).register(publicKeyBase64: ' '),
        throwsA(isA<WarpRegistrationException>()),
      );
      expect(called, isFalse);
    });

    test('reports an HTTP failure with a short body', () async {
      final client = MockClient(
        (_) async => http.Response('forbidden by policy', 403),
      );

      await expectLater(
        WarpRegistrationClient(client: client).register(publicKeyBase64: 'k='),
        throwsA(
          isA<WarpRegistrationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('403'), contains('forbidden')),
          ),
        ),
      );
    });

    test('wraps a network exception as a registration error', () async {
      final client = MockClient((_) async => throw const SocketLikeFailure());
      await expectLater(
        WarpRegistrationClient(client: client).register(publicKeyBase64: 'k='),
        throwsA(isA<WarpRegistrationException>()),
      );
    });
  });

  group('WarpRegistrationClient.parseRegistration', () {
    test('accepts an unwrapped payload as well as a result-wrapped one', () {
      final bare = json.encode({
        'id': 'a',
        'token': 't',
        'config': {
          'interface': {
            'addresses': {'v4': '10.0.0.2'},
          },
          'peers': [
            {
              'public_key': 'p',
              'endpoint': {'v4': '1.2.3.4:2408'},
            },
          ],
        },
      });
      final config = WarpRegistrationClient.parseRegistration(bare);
      expect(config.accountId, 'a');
      expect(config.endpointPort, 2408);
    });

    test('strips a zero port and defaults to 2408', () {
      final config = WarpRegistrationClient.parseRegistration(_successBody());
      expect(config.endpointPort, 2408);
      expect(config.endpointHost, '162.159.192.1');
    });

    test('unwraps a bracketed IPv6 endpoint', () {
      final body = json.encode({
        'id': 'a',
        'token': 't',
        'config': {
          'interface': {
            'addresses': {'v4': '10.0.0.2'},
          },
          'peers': [
            {
              'public_key': 'p',
              'endpoint': {'v6': '[2606:4700:d0::1]:2408'},
            },
          ],
        },
      });
      final config = WarpRegistrationClient.parseRegistration(body);
      expect(config.endpointHost, '2606:4700:d0::1');
      expect(config.endpointPort, 2408);
    });

    test('throws for each incomplete shape', () {
      final cases = <String, String>{
        'not json': 'not JSON',
        '[]': 'not an object',
        '{"result":{"config":{}}}': 'account id or token',
        '{"result":{"id":"a","token":"t"}}': 'no config',
        '{"result":{"id":"a","token":"t","config":{"peers":[]}}}': 'no peers',
      };
      cases.forEach((body, expected) {
        expect(
          () => WarpRegistrationClient.parseRegistration(body),
          throwsA(
            isA<WarpRegistrationException>().having(
              (e) => e.message,
              'message',
              contains(expected),
            ),
          ),
          reason: 'body: $body',
        );
      });
    });
  });

  group('WarpConfigStore', () {
    test('round-trips a config', () async {
      String? stored;
      final store = WarpConfigStore(
        read: () async => stored,
        write: (value) async => stored = value,
      );

      const config = WarpConfig(
        accountId: 'a',
        accessToken: 't',
        peerPublicKey: 'p',
        endpointHost: '1.2.3.4',
        endpointPort: 2408,
        ipv4: '10.0.0.2',
        ipv6: '',
      );

      await store.save(config);
      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.accountId, 'a');
      expect(loaded.endpointPort, 2408);
      expect(loaded.isUsable, isTrue);
    });

    test(
      'returns null for empty, malformed or unusable stored values',
      () async {
        for (final raw in [null, '', 'not json', '{}', '{"accountId":"a"}']) {
          final store = WarpConfigStore(
            read: () async => raw,
            write: (_) async {},
          );
          expect(await store.load(), isNull, reason: 'stored: $raw');
        }
      },
    );

    test('clear empties the stored value', () async {
      var stored = 'something';
      final store = WarpConfigStore(
        read: () async => stored,
        write: (value) async => stored = value,
      );
      await store.clear();
      expect(stored, isEmpty);
      expect(await store.load(), isNull);
    });
  });

  group('WarpConfig', () {
    test('is unusable without a peer key, endpoint or address', () {
      const complete = WarpConfig(
        accountId: 'a',
        accessToken: 't',
        peerPublicKey: 'p',
        endpointHost: 'h',
        endpointPort: 2408,
        ipv4: '10.0.0.2',
        ipv6: '',
      );
      expect(complete.isUsable, isTrue);

      expect(
        WarpConfig(
          accountId: 'a',
          accessToken: 't',
          peerPublicKey: '',
          endpointHost: complete.endpointHost,
          endpointPort: 2408,
          ipv4: complete.ipv4,
          ipv6: '',
        ).isUsable,
        isFalse,
      );
    });
  });
}

/// Stands in for a socket-level failure inside a MockClient handler.
class SocketLikeFailure implements Exception {
  const SocketLikeFailure();

  @override
  String toString() => 'connection refused';
}
