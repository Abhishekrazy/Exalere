import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/moviebox_provider.dart';

void main() {
  group('MovieBox DASH Manifest Resolution', () {
    test('resolves dash manifest from standard CloudFront-Policy cookie', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/dash/12345_0_0_1080_h265_518/*"}]}';
      final b64 = base64Encode(utf8.encode(policyJson));
      final cookie =
          'CloudFront-Policy=$b64; CloudFront-Signature=abc; CloudFront-Key-Pair-Id=xyz;';

      final resolved = MovieBoxProvider.resolveDashManifestFromPolicy(cookie);
      expect(
        resolved,
        'https://sacdn.example.com/dash/12345_0_0_1080_h265_518/index.mpd',
      );
    });

    test('handles custom dash and tilde character substitution', () {
      const policyJson =
          '{"Statement":[{"Resource":"https://sacdn.example.com/stream/999/*"}]}';
      var b64 = base64Encode(utf8.encode(policyJson));
      // Substitute + with -, / with ~
      b64 = b64.replaceAll('+', '-').replaceAll('/', '~');

      final cookie = 'CloudFront-Policy=$b64;';
      final resolved = MovieBoxProvider.resolveDashManifestFromPolicy(cookie);
      expect(resolved, 'https://sacdn.example.com/stream/999/index.mpd');
    });

    test('returns null for invalid or missing policy cookies', () {
      expect(MovieBoxProvider.resolveDashManifestFromPolicy(''), isNull);
      expect(
        MovieBoxProvider.resolveDashManifestFromPolicy(
          'CloudFront-Policy=invalid!not!b64',
        ),
        isNull,
      );
      expect(
        MovieBoxProvider.resolveDashManifestFromPolicy('SomeOtherCookie=123;'),
        isNull,
      );
    });
  });
}
