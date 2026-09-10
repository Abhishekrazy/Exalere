import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/ui/theme/app_themes.dart';

void main() {
  group('Exalere Design System & Style Guide Tokens Tests', () {
    test('All presets in AppThemes have valid AppDesignTokens', () {
      expect(AppThemes.allThemes.length, 7);

      for (final themeOption in AppThemes.allThemes) {
        expect(themeOption.tokens, isNotNull);
        expect(themeOption.tokens.canvasBackground, isNotNull);
        expect(themeOption.tokens.surfaceCard, isNotNull);
        expect(themeOption.tokens.primaryAccent, isNotNull);
        expect(themeOption.tokens.borderFocus, isNotNull);
        expect(themeOption.tokens.heroGradient.colors.length, greaterThanOrEqualTo(2));
        expect(themeOption.tokens.scrimGradient.colors.length, greaterThanOrEqualTo(2));

        // Verify that ThemeData contains the ThemeExtension
        final extension = themeOption.themeData.extension<AppDesignTokens>();
        expect(extension, isNotNull);
        expect(extension!.primaryAccent, equals(themeOption.tokens.primaryAccent));
      }
    });

    test('AppSpacing tokens provide expected layout dimensions', () {
      expect(AppSpacing.none, 0.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 12.0);
      expect(AppSpacing.lg, 16.0);
      expect(AppSpacing.xl, 24.0);
      expect(AppSpacing.xxl, 32.0);
      expect(AppSpacing.xxxl, 48.0);

      expect(AppSpacing.gapMd.width, 12.0);
      expect(AppSpacing.gapMd.height, 12.0);

      expect(AppSpacing.screen(false), equals(AppSpacing.screenMobile));
      expect(AppSpacing.screen(true), equals(AppSpacing.screenTv));
    });

    test('AppRadius tokens provide expected border radii', () {
      expect(AppRadius.xs, 4.0);
      expect(AppRadius.sm, 8.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.lg, 16.0);
      expect(AppRadius.xl, 20.0);
      expect(AppRadius.pill, 999.0);

      expect(AppRadius.borderMd, equals(BorderRadius.circular(12.0)));
      expect(AppRadius.borderPill, equals(BorderRadius.circular(999.0)));
    });

    test('AppMotion tokens provide expected animation constants', () {
      expect(AppMotion.fast.inMilliseconds, 150);
      expect(AppMotion.normal.inMilliseconds, 250);
      expect(AppMotion.slow.inMilliseconds, 400);
      expect(AppMotion.tvFocusScale, 1.06);
      expect(AppMotion.desktopHoverScale, 1.02);
    });

    testWidgets('BuildContext.tokens retrieves theme tokens dynamically', (WidgetTester tester) async {
      late AppDesignTokens retrievedTokens;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.jioHotstar.themeData,
          home: Builder(
            builder: (context) {
              retrievedTokens = context.tokens;
              return Container(color: context.tokens.surfaceCard);
            },
          ),
        ),
      );

      expect(retrievedTokens.primaryAccent, equals(const Color(0xFF00D2FF)));
      expect(retrievedTokens.canvasBackground, equals(const Color(0xFF0B0E17)));
      expect(retrievedTokens.surfaceCard, equals(const Color(0xFF131926)));
    });

    testWidgets('AppDesignTokens lerps smoothly during animated theme transitions', (WidgetTester tester) async {
      final t1 = AppThemes.netflixTokens;
      final t2 = AppThemes.tokyoTokens;

      final lerped = t1.lerp(t2, 0.5);
      expect(lerped, isNotNull);
      expect(lerped.cardRadius, equals(AppRadius.md));
    });
  });
}
