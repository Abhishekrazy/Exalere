import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/services/moviebox_config_service.dart';
import 'package:exalere/services/moviebox_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieBox Upstream Sync & Config Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('parseHostPool accurately parses Rust const HOST_POOL array', () {
      const rustSample = '''
const HOST_POOL: &[&str] = &[
    "https://api6.aoneroom.com",
    "https://api5.aoneroom.com",
    "https://api4.aoneroom.com",
    "https://api4sg.aoneroom.com",
    "https://api3.aoneroom.com",
    "https://api6sg.aoneroom.com",
    "https://api.inmoviebox.com",
];
''';

      final hosts = MovieBoxConfigService.parseHostPool(rustSample);
      expect(hosts.length, 7);
      expect(hosts[0], 'https://api6.aoneroom.com');
      expect(hosts[1], 'https://api5.aoneroom.com');
      expect(hosts[3], 'https://api4sg.aoneroom.com');
      expect(hosts[5], 'https://api6sg.aoneroom.com');
      expect(hosts[6], 'https://api.inmoviebox.com');
    });

    test('parseSecretKey extracts HMAC secret key constant', () {
      const rustSample = '''
const SECRET_KEY_DEFAULT: &str = "76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O";
const SIGNATURE_BODY_MAX_BYTES: usize = 102_400;
''';

      final key = MovieBoxConfigService.parseSecretKey(rustSample);
      expect(key, '76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O');
    });

    test('parseClientInfo parses metadata from crypto.rs', () {
      const rustSample = '''
    let version_codes = [50020117, 50020118, 50020119, 50020120, 50020121];
    let client_info = format!(
        r#"{"package_name":"com.community.oneroom","version_name":"4.0.01.0813.03","version_code":{},"os":"android","os_version":"{}","install_ch":"ps","device_id":"{}","install_store":"ps","gaid":"{}","brand":"{}","model":"{}","system_language":"en","net":"{}","region":"US","timezone":"{}","sp_code":"40401","X-Play-Mode":"2"}"#,
        version_code, android.0, device_id, gaid, device.1, device.0, network, timezone
    );
''';

      final info = MovieBoxConfigService.parseClientInfo(rustSample);
      expect(info['packageName'], 'com.community.oneroom');
      expect(info['versionName'], '4.0.01.0813.03');
      expect(info['spCode'], '40401');
      expect(info['versionCodes'], [
        50020117,
        50020118,
        50020119,
        50020120,
        50020121,
      ]);
    });

    test('MovieBoxConfig JSON roundtrip preserves all properties', () {
      const original = MovieBoxConfig(
        hostPool: [
          'https://api6.aoneroom.com',
          'https://api5.aoneroom.com',
          'https://api4sg.aoneroom.com',
        ],
        secretKey: 'custom_test_secret_key_1234567890',
        packageName: 'com.custom.app',
        versionName: '5.0.0',
        spCode: '99999',
        versionCodes: [60000001, 60000002],
        lastSyncTimestamp: 1700000000000,
        lastSyncStatus: 'Successfully tested',
      );

      final json = original.toJson();
      final restored = MovieBoxConfig.fromJson(json);

      expect(restored.hostPool, original.hostPool);
      expect(restored.secretKey, original.secretKey);
      expect(restored.packageName, original.packageName);
      expect(restored.versionName, original.versionName);
      expect(restored.spCode, original.spCode);
      expect(restored.versionCodes, original.versionCodes);
      expect(restored.lastSyncTimestamp, original.lastSyncTimestamp);
      expect(restored.lastSyncStatus, original.lastSyncStatus);
    });

    test('MovieBoxClient accesses dynamic host pool and falls back safely', () {
      final client = MovieBoxClient();
      expect(client.hostPool.isNotEmpty, true);
      expect(client.hostPool.first.startsWith('https://'), true);
      expect(client.userAgent.contains('com.community.oneroom'), true);
    });
  });
}
