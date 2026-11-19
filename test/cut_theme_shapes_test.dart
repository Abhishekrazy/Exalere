import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/logging_settings_dialog.dart';
import 'support/golden_tolerance.dart';

/// Renders dialogs under the Cut (bevel) theme so corner geometry can be
/// inspected without a device. Fonts render as Ahem blocks in goldens, which is
/// fine: this pins shapes, borders and clips, not typography.
void main() {
  useTolerantGoldens();
  ThemeData cutTheme() {
    final base = AppThemes.netflixBlack.themeData;
    final tokens = base.extension<AppDesignTokens>()!.copyWith(
      cornerStyle: CornerStyle.cut,
    );
    return base.copyWith(extensions: [tokens]);
  }

  testWidgets('logging dialog corners under Cut', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: cutTheme(),
        home: const Scaffold(body: LoggingSettingsDialog()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(LoggingSettingsDialog),
      matchesGoldenFile('goldens/cut_logging_dialog.png'),
    );
  });
}
