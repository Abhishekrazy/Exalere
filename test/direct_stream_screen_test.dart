import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/ui/screens/direct_stream_screen.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/search_media_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DirectStreamScreen Widget Tests', () {
    testWidgets('Renders all primary UI components and input fields', (
      tester,
    ) async {
      final app = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: const DirectStreamScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Stream & Downloader'), findsOneWidget);
      expect(find.text('STREAM / VIDEO URL'), findsOneWidget);
      expect(find.text('Paste URL'), findsOneWidget);
      expect(find.text('CUSTOM TITLE (OPTIONAL)'), findsOneWidget);
      expect(find.text('Play Now'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('Clicking Play Now with empty URL displays error snackbar', (
      tester,
    ) async {
      final app = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: const DirectStreamScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Play Now without entering a URL
      await tester.tap(find.text('Play Now'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter or paste a valid stream URL'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Entering invalid URL protocol displays format error snackbar',
      (tester) async {
        final app = AppProvider();

        await tester.pumpWidget(
          ChangeNotifierProvider<AppProvider>.value(
            value: app,
            child: MaterialApp(
              theme: AppThemes.netflixBlack.themeData,
              home: const DirectStreamScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'ftp://bad-url.com/movie.mp4',
        );
        await tester.pump();

        await tester.tap(find.text('Play Now'));
        await tester.pumpAndSettle();

        expect(
          find.text('URL must begin with http://, https://, or rtsp://'),
          findsOneWidget,
        );
      },
    );
  });

  group('SearchMediaCard Widget Tests (Home Card Alignment)', () {
    testWidgets('Renders poster, title below poster, and subtitle metadata', (
      tester,
    ) async {
      final app = AppProvider();
      final item = MediaItem(
        id: '123',
        title: 'Inception',
        mediaType: MediaType.movie,
        year: '2010',
        genre: 'Sci-Fi',
        rating: 8.8,
        posterUrl: 'https://image.tmdb.org/t/p/w500/test.jpg',
      );

      bool tapped = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            home: Scaffold(
              body: SizedBox(
                width: 140,
                height: 240,
                child: SearchMediaCard(item: item, onTap: () => tapped = true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('2010 • Sci-Fi'), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget);

      await tester.tap(find.byType(SearchMediaCard));
      expect(tapped, isTrue);
    });
  });
}
