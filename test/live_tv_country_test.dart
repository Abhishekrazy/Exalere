import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/iptv_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live TV Country & Storage Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to IN (India) when no country is stored', () async {
      final storage = StorageService();
      final country = await storage.getLiveTvCountry();
      expect(country, 'IN');
    });

    test('persists and updates country code properly', () async {
      final storage = StorageService();
      await storage.setLiveTvCountry('US');
      final updated = await storage.getLiveTvCountry();
      expect(updated, 'US');

      await storage.setLiveTvCountry('ALL');
      final allCountry = await storage.getLiveTvCountry();
      expect(allCountry, 'ALL');
    });

    test(
      'IptvProvider fetches popular countries with India at the top',
      () async {
        final provider = IptvProvider();
        final countries = await provider.fetchCountries();
        expect(countries.isNotEmpty, true);
        expect(countries.first.code, 'IN');
        expect(countries.first.name, 'India');
      },
    );
  });
}
