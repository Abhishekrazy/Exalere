import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/tv_settings_menu_item.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppThemes.netflixBlack.themeData,
    home: Scaffold(
      body: Center(child: SizedBox(width: 400, child: child)),
    ),
  );

  testWidgets('value chip and chevron sit at the card right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TvSettingsMenuItem(
          icon: Icons.face_rounded,
          title: 'Viewer Profiles',
          subtitle: 'Switch, create or edit viewer profiles',
          valueText: 'AR',
          onTap: () {},
        ),
      ),
    );

    final card = tester.getRect(find.byType(TvSettingsMenuItem));
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right_rounded));

    // Only the 16 px container padding may remain to the right of the chevron.
    expect(card.right - chevron.right, lessThanOrEqualTo(20));
  });

  testWidgets('a long value stays inside the card and keeps the arrow right', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        TvSettingsMenuItem(
          icon: Icons.settings_rounded,
          title: 'Video Decoder',
          subtitle: 'Hardware, software, or automatic',
          valueText: 'Hardware Acceleration (Auto Safe)',
          onTap: () {},
        ),
      ),
    );

    final card = tester.getRect(find.byType(TvSettingsMenuItem));
    final chevron = tester.getRect(find.byIcon(Icons.chevron_right_rounded));
    final chipText = tester.getRect(
      find.text('Hardware Acceleration (Auto Safe)'),
    );

    expect(chipText.right, lessThanOrEqualTo(card.right));
    expect(card.right - chevron.right, lessThanOrEqualTo(20));
  });
}
