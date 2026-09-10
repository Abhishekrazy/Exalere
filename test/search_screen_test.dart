import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/ui/screens/search_screen.dart';

void main() {
  testWidgets(
    'SearchScreen renders CustomScrollView with separated search button',
    (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(home: SearchScreen()),
        ),
      );

      // Verify CustomScrollView is used (search bar and categories scroll with content)
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify Search text field is rendered
      expect(find.byType(TextField), findsOneWidget);

      // Verify Separated Search action button is rendered with search icon
      expect(find.byIcon(Icons.search_rounded), findsWidgets);

      // Verify Trending category chips are rendered
      expect(find.text('Action'), findsOneWidget);
      expect(find.text('Sci-Fi'), findsOneWidget);
    },
  );
}
