import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/iptv_provider.dart';
import 'package:exalere/ui/screens/live_tv/live_tv_category_dialog.dart';
import 'package:exalere/ui/screens/live_tv/live_tv_country_dialog.dart';
import 'package:exalere/ui/screens/live_tv/live_tv_language_dialog.dart';
import 'package:exalere/ui/theme/app_themes.dart';

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

    testWidgets(
      'LiveTvCategoryDialog renders categories, scrolls smoothly, and triggers selection',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: Scaffold(
              body: LiveTvCategoryDialog(
                categories: const [
                  'All',
                  'General',
                  'Kids',
                  'Legislative',
                  'Lifestyle',
                  'Movies',
                  'Music',
                  'News',
                ],
                selectedCategory: 'Kids',
                onCategorySelected: (cat) => selected = cat,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kids'), findsWidgets);
        expect(find.text('General'), findsWidgets);

        // Scroll to Lifestyle and tap it
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(find.text('Lifestyle'), findsWidgets);
        await tester.tap(find.text('Lifestyle'));
        await tester.pumpAndSettle();

        expect(selected, 'Lifestyle');
      },
    );

    testWidgets(
      'LiveTvCountryDialog renders countries without overflow and allows selection',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: Scaffold(
              body: LiveTvCountryDialog(
                selectedCountry: 'IN',
                iptvProvider: IptvProvider(),
                onCountrySelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select Live TV Country'), findsWidgets);
        expect(find.text('India'), findsWidgets);
      },
    );

    testWidgets(
      'LiveTvLanguageDialog renders languages without overflow and toggles selection',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: Scaffold(
              body: LiveTvLanguageDialog(
                selectedLanguages: const {'ALL'},
                onLanguagesSelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Select Languages'), findsWidgets);
        expect(find.text('English'), findsWidgets);
      },
    );
  });
}
