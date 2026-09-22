import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'moviebox_config_service.dart';

class MovieBoxCrypto {
  static const String secretKeyDefault =
      "76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O";
  static const int signatureBodyMaxBytes = 102400;

  static List<int> get defaultSecretBytes {
    final key = MovieBoxConfigService().secretKey;
    final pad = (4 - key.length % 4) % 4;
    return base64Decode(key + ('=' * pad));
  }

  static String md5Hex(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  static String generateXClientToken(int tsMs) {
    final tsStr = tsMs.toString();
    final reversedTs = tsStr.split('').reversed.join('');
    final hashVal = md5.convert(utf8.encode(reversedTs)).toString();
    return '$tsStr,$hashVal';
  }

  static String sortedQueryString(String urlStr) {
    final uri = Uri.tryParse(urlStr);
    if (uri == null || uri.queryParametersAll.isEmpty) {
      return '';
    }

    final sortedKeys = uri.queryParametersAll.keys.toList()..sort();
    final parts = <String>[];
    for (final key in sortedKeys) {
      final values = uri.queryParametersAll[key] ?? [];
      for (final val in values) {
        parts.add('$key=$val');
      }
    }
    return parts.join('&');
  }

  static String buildCanonicalString({
    required String method,
    String? accept,
    String? contentType,
    required String url,
    String? body,
    required int timestampMs,
  }) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final query = sortedQueryString(url);
    final canonicalUrl = query.isEmpty ? path : '$path?$query';

    String bodyHash = '';
    String bodyLength = '';

    if (body != null) {
      final bytes = utf8.encode(body);
      final len = bytes.length;
      final truncated = len > signatureBodyMaxBytes
          ? bytes.sublist(0, signatureBodyMaxBytes)
          : bytes;
      bodyHash = md5Hex(truncated);
      bodyLength = len.toString();
    }

    return [
      method.toUpperCase(),
      accept ?? '',
      contentType ?? '',
      bodyLength,
      timestampMs.toString(),
      bodyHash,
      canonicalUrl,
    ].join('\n');
  }

  static String generateXTrSignature({
    required String method,
    String? accept,
    String? contentType,
    required String url,
    String? body,
    required int timestampMs,
  }) {
    final canonical = buildCanonicalString(
      method: method,
      accept: accept,
      contentType: contentType,
      url: url,
      body: body,
      timestampMs: timestampMs,
    );

    final hmacMd5 = Hmac(md5, defaultSecretBytes);
    final digest = hmacMd5.convert(utf8.encode(canonical));
    final sigB64 = base64Encode(digest.bytes);

    return '$timestampMs|2|$sigB64';
  }

  static String randomHex(int len) {
    final rng = Random();
    final buffer = StringBuffer();
    for (int i = 0; i < len; i++) {
      buffer.write(rng.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  static String randomUuid() {
    return '${randomHex(8)}-${randomHex(4)}-${randomHex(4)}-${randomHex(4)}-${randomHex(12)}';
  }

  static String randomSpoofedIp() {
    final rng = Random();
    const prefixes = [
      '103.241',
      '49.36',
      '117.195',
      '106.198',
      '122.162',
      '157.32',
      '182.70',
      '103.58',
      '27.60',
      '59.90',
    ];
    final prefix = prefixes[rng.nextInt(prefixes.length)];
    final c = rng.nextInt(253) + 1;
    final d = rng.nextInt(253) + 1;
    return '$prefix.$c.$d';
  }

  static (String userAgent, String clientInfo) generateClientInfoAndUa() {
    final rng = Random();

    const androidVersions = [
      ('11', 'RP1A.200720.011'),
      ('12', 'S1B.220414.015'),
      ('13', 'TQ2A.230405.003'),
    ];
    const redmiDevices = [
      ('2201117TY', 'Redmi'),
      ('M2012K11AG', 'Redmi'),
      ('22101316G', 'Redmi'),
    ];
    final cfg = MovieBoxConfigService();
    final versionCodes = cfg.versionCodes.isNotEmpty
        ? cfg.versionCodes
        : const [50020117, 50020118, 50020119, 50020120, 50020121];

    final android = androidVersions[rng.nextInt(androidVersions.length)];
    final device = redmiDevices[rng.nextInt(redmiDevices.length)];
    final versionCode = versionCodes[rng.nextInt(versionCodes.length)];
    final gaid = randomUuid();
    final deviceId = randomHex(32);

    final userAgent =
        '${cfg.packageName}/$versionCode (Linux; U; Android ${android.$1}; en_US; ${device.$1}; Build/${android.$2}; Cronet/135.0.7012.3)';

    final clientInfoMap = {
      'package_name': cfg.packageName,
      'version_name': cfg.versionName,
      'version_code': versionCode,
      'os': 'android',
      'os_version': android.$1,
      'install_ch': 'ps',
      'device_id': deviceId,
      'install_store': 'ps',
      'gaid': gaid,
      'brand': device.$2,
      'model': device.$1,
      'system_language': 'en',
      'net': 'NETWORK_WIFI',
      'region': 'US',
      'timezone': 'Asia/Kolkata',
      'sp_code': cfg.spCode,
      'X-Play-Mode': '2',
    };

    return (userAgent, jsonEncode(clientInfoMap));
  }

  static Map<String, String> buildSignedHeaders({
    required String method,
    required String url,
    String? body,
    String? authToken,
    required String userAgent,
    required String clientInfo,
    required String spoofedIp,
  }) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    const accept = 'application/json';
    const contentType = 'application/json';

    final clientToken = generateXClientToken(ts);
    final signature = generateXTrSignature(
      method: method,
      accept: accept,
      contentType: contentType,
      url: url,
      body: body,
      timestampMs: ts,
    );

    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept': accept,
      'Content-Type': contentType,
      'Connection': 'keep-alive',
      'x-client-token': clientToken,
      'x-tr-signature': signature,
      'x-client-info': clientInfo,
      'x-client-status': '0',
      'x-forwarded-for': spoofedIp,
    };

    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    return headers;
  }
}
