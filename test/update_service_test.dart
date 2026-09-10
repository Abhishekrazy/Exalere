import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/update_service.dart';

void main() {
  group('UpdateService semver comparator', () {
    test('detects newer minor and patch versions', () {
      expect(UpdateService.isNewerVersion('0.2.0', '0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', '0.3.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0', 'v1.0.0'), isTrue);
    });

    test('correctly identifies older or equal versions', () {
      expect(UpdateService.isNewerVersion('0.2.0', '0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', '0.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0', 'v0.1.9'), isFalse);
    });

    test('handles build metadata suffixes cleanly', () {
      expect(UpdateService.isNewerVersion('0.2.0+1', '0.2.1'), isTrue);
      expect(UpdateService.isNewerVersion('0.2.0+1', '0.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.2.0-beta', '0.2.1'), isTrue);
    });
  });
}
