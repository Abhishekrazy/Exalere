import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/bdix_provider.dart';

void main() {
  group('BdixCircleFtpProvider Tests', () {
    test('detectResolution parses resolutions correctly', () {
      expect(
        BdixCircleFtpProvider.detectResolution('2160p 4K'),
        equals('3840x2160'),
      );
      expect(
        BdixCircleFtpProvider.detectResolution('1080p FHD'),
        equals('1920x1080'),
      );
      expect(
        BdixCircleFtpProvider.detectResolution('720p HD'),
        equals('1280x720'),
      );
      expect(
        BdixCircleFtpProvider.detectResolution('480p SD'),
        equals('854x480'),
      );
      expect(
        BdixCircleFtpProvider.detectResolution('Unknown'),
        equals('1920x1080'),
      );
    });

    test('BdixCircleFtpAdapter declares correct properties', () {
      final adapter = BdixCircleFtpAdapter();
      expect(adapter.id, equals('circleftp'));
      expect(adapter.name, equals('CircleFTP (BDIX)'));
      expect(adapter.supportsMovies, isTrue);
      expect(adapter.supportsSeries, isTrue);
      expect(adapter.supportsSearch, isTrue);
      expect(adapter.priority, equals(30));
    });
  });
}
