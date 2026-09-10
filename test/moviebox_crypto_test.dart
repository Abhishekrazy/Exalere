import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/moviebox_crypto.dart';

void main() {
  group('MovieBoxCrypto Tests', () {
    test('generateXClientToken produces valid ts and md5 hash', () {
      final token = MovieBoxCrypto.generateXClientToken(1700000000000);
      final parts = token.split(',');
      expect(parts.length, 2);
      expect(parts[0], '1700000000000');
      expect(parts[1].length, 32);
    });

    test('sortedQueryString sorts parameters alphabetically', () {
      const url = 'https://api.example.com/endpoint?b=2&a=1&c=3';
      expect(MovieBoxCrypto.sortedQueryString(url), 'a=1&b=2&c=3');

      const noQuery = 'https://api.example.com/endpoint';
      expect(MovieBoxCrypto.sortedQueryString(noQuery), '');
    });

    test('buildCanonicalString matches MovieBox signature specification', () {
      final canonical = MovieBoxCrypto.buildCanonicalString(
        method: 'GET',
        accept: 'application/json',
        contentType: 'application/json',
        url: 'https://api.example.com/path?tab=1&page=2',
        body: null,
        timestampMs: 1700000000000,
      );

      final lines = canonical.split('\n');
      expect(lines.length, 7);
      expect(lines[0], 'GET');
      expect(lines[1], 'application/json');
      expect(lines[2], 'application/json');
      expect(lines[3], ''); // bodyLength
      expect(lines[4], '1700000000000');
      expect(lines[5], ''); // bodyHash
      expect(lines[6], '/path?page=2&tab=1'); // canonical URL with sorted query
    });

    test('generateXTrSignature produces version 2 signature', () {
      final sig = MovieBoxCrypto.generateXTrSignature(
        method: 'GET',
        accept: 'application/json',
        contentType: 'application/json',
        url: 'https://api.example.com/path',
        body: null,
        timestampMs: 1700000000000,
      );

      final parts = sig.split('|');
      expect(parts.length, 3);
      expect(parts[0], '1700000000000');
      expect(parts[1], '2');
      expect(parts[2].isNotEmpty, true);
    });

    test('generateClientInfoAndUa produces valid user agent and JSON client info', () {
      final (ua, infoJson) = MovieBoxCrypto.generateClientInfoAndUa();
      expect(ua.contains('com.community.oneroom/500201'), true);
      expect(ua.contains('Cronet/135.0.7012.3'), true);

      final decoded = jsonDecode(infoJson);
      expect(decoded['package_name'], 'com.community.oneroom');
      expect(decoded['version_name'], '4.0.01.0813.03');
      expect(decoded['sp_code'], '40401');
      expect(decoded['X-Play-Mode'], '2');
    });
  });
}
