import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/provider_selection_dialog.dart';
import 'support/golden_tolerance.dart';

void main() {
  useTolerantGoldens();
  ThemeData cutTheme() {
    final base = AppThemes.netflixBlack.themeData;
    final tokens = base.extension<AppDesignTokens>()!.copyWith(
      cornerStyle: CornerStyle.cut,
    );
    return base.copyWith(extensions: [tokens]);
  }

  testWidgets(
    'provider dialog lays options out in two columns, no close button',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final app = AppProvider();
      final plugins = PluginProvider();
      addTearDown(() {
        app.dispose();
        plugins.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: app),
            ChangeNotifierProvider<PluginProvider>.value(value: plugins),
          ],
          child: MaterialApp(
            theme: cutTheme(),
            home: const Scaffold(
              body: ProviderSelectionDialog(isFromSettings: true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(Icons.close_rounded), findsNothing);

      final cards = find.byType(SizedBox);
      expect(cards, findsWidgets);

      await expectLater(
        find.byType(ProviderSelectionDialog),
        matchesGoldenFile('goldens/cut_provider_dialog.png'),
      );
    },
  );
}
