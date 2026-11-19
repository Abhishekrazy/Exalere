import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/features_showcase_dialog.dart';

void main() {
  ThemeData cutTheme() {
    final base = AppThemes.netflixBlack.themeData;
    final tokens = base.extension<AppDesignTokens>()!.copyWith(
      cornerStyle: CornerStyle.cut,
    );
    return base.copyWith(extensions: [tokens]);
  }

  testWidgets(
    'features dialog opens with a chip focused, not the search field',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: cutTheme(),
          home: const Scaffold(body: FeaturesShowcaseDialog()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final focus = FocusManager.instance.primaryFocus;
      // The search field must never win the initial focus: on TV it raises the
      // IME and swallows every D-pad stroke.
      expect(focus?.debugLabel, isNot('features_search'));
      expect(focus, isNotNull);

      await expectLater(
        find.byType(FeaturesShowcaseDialog),
        matchesGoldenFile('goldens/cut_features_dialog.png'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
      expect(FocusManager.instance.primaryFocus, isNotNull);
    },
  );
}
