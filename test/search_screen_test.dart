import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/ui/screens/active_search_screen.dart';
import 'package:exalere/ui/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'SearchScreen renders keyboard-free Category Discovery screen with Search and Voice triggers',
    (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(home: SearchScreen()),
        ),
      );

      // Verify CustomScrollView is used for content
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify NO inline TextField exists on the default screen (prevents TV virtual keyboard popup)
      expect(find.byType(TextField), findsNothing);

      // Verify Search trigger button and Voice trigger button are present
      expect(find.byIcon(Icons.search_rounded), findsWidgets);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Verify Category chips are visible directly on the shelf
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Sci-Fi'), findsOneWidget);

      // Tap 'Action' category chip to filter
      await tester.tap(find.text('Action'));
      await tester.pump();

      // Verify category header reflects selection
      expect(find.text('Action Titles'), findsOneWidget);
    },
  );

  testWidgets(
    'ActiveSearchScreen renders dedicated TextField, Voice button, and results area',
    (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(home: ActiveSearchScreen()),
        ),
      );

      // Verify Back button is rendered
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verify TextField is rendered in dedicated search screen
      expect(find.byType(TextField), findsOneWidget);

      // Verify Voice button is rendered
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Verify Search action button is rendered
      expect(find.text('Search'), findsOneWidget);
    },
  );
}
