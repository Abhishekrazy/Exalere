import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_tokens.dart';
import 'package:exalere/ui/widgets/app_button.dart';
import 'package:exalere/ui/widgets/app_surface.dart';

void main() {
  group('CornerStyle & SurfaceMorphism Tokens', () {
    test('CornerStyle geometry generates appropriate ShapeBorder', () {
      const tokensRounded = AppDesignTokens(
        canvasBackground: Color(0xFF000000),
        surfaceCard: Color(0xFF111111),
        surfaceElevated: Color(0xFF222222),
        surfaceGlass: Color(0xFF333333),
        borderSubtle: Color(0xFF444444),
        borderFocus: Color(0xFF555555),
        primaryAccent: Color(0xFF666666),
        secondaryAccent: Color(0xFF777777),
        textPrimary: Color(0xFF888888),
        textSecondary: Color(0xFF999999),
        textMuted: Color(0xFFAAAAAA),
        liveColor: Color(0xFFBBBBBB),
        vipColor: Color(0xFFCCCCCC),
        errorColor: Color(0xFFDDDDDD),
        heroGradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF111111)],
        ),
        scrimGradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF111111)],
        ),
        cardRadius: 12.0,
        cornerStyle: CornerStyle.rounded,
      );

      final shapeRounded = tokensRounded.getShapeBorder();
      expect(shapeRounded, isA<RoundedRectangleBorder>());
      expect(
        (shapeRounded as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12.0),
      );

      final tokensSharp = tokensRounded.copyWith(
        cornerStyle: CornerStyle.sharp,
      );
      final shapeSharp = tokensSharp.getShapeBorder();
      expect(shapeSharp, isA<RoundedRectangleBorder>());
      expect(
        (shapeSharp as RoundedRectangleBorder).borderRadius,
        BorderRadius.zero,
      );

      final tokensCut = tokensRounded.copyWith(cornerStyle: CornerStyle.cut);
      final shapeCut = tokensCut.getShapeBorder();
      expect(shapeCut, isA<BeveledRectangleBorder>());
    });

    test('SurfaceMorphism generates distinct decoration effects', () {
      const baseTokens = AppDefaultTokens.value;

      final glassDeco = baseTokens
          .copyWith(surfaceMorphism: SurfaceMorphism.glass)
          .getShapeDecoration();
      expect(glassDeco.gradient, isNotNull);

      final neoDeco = baseTokens
          .copyWith(surfaceMorphism: SurfaceMorphism.neomorphic)
          .getShapeDecoration();
      expect(neoDeco.shadows, isNotNull);
      expect(neoDeco.shadows!.length, greaterThanOrEqualTo(2));

      final clayDeco = baseTokens
          .copyWith(surfaceMorphism: SurfaceMorphism.clay)
          .getShapeDecoration();
      expect(clayDeco.shadows, isNotNull);
    });
  });

  group('Universal Widget Rendering', () {
    testWidgets('AppSurface renders child and adapts to morphism', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppSurface(
              morphism: SurfaceMorphism.glass,
              child: const Text('Glass Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glass Card Content'), findsOneWidget);
    });

    testWidgets('AppButton renders all variants with tactile D-Pad support', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppButton.primary(
                  label: 'Primary Button',
                  onTap: () => tapped = true,
                ),
                AppButton.secondary(label: 'Secondary Button'),
                AppButton.glass(label: 'Glass Capsule'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary Button'), findsOneWidget);
      expect(find.text('Secondary Button'), findsOneWidget);
      expect(find.text('Glass Capsule'), findsOneWidget);

      await tester.tap(find.text('Primary Button'));
      expect(tapped, isTrue);
    });
  });
}
