import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/ui/widgets/provider_badge.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('ProviderBadge renders label correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderBadge(
            provider: ProviderType.movieBox,
            isSelected: true,
          ),
        ),
      ),
    );

    expect(find.text('MovieBox'), findsOneWidget);
  });
}
