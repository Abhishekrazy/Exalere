import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/plugin_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppThemes.netflixBlack.themeData,
    home: Scaffold(body: child),
  );

  testWidgets('draws an initials tile when the add-on has no artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const PluginRow(name: 'RogMovies Engine', subtitle: 'by Exalere')),
    );

    expect(find.text('RE'), findsOneWidget);
    expect(find.text('RogMovies Engine'), findsOneWidget);
    expect(find.text('by Exalere'), findsOneWidget);
  });

  testWidgets('a digit-leading name keeps its number in the tile', (
    tester,
  ) async {
    await tester.pumpWidget(host(const PluginRow(name: '4K HD Hub Engine')));
    expect(find.text('4K'), findsOneWidget);
  });

  testWidgets('the whole row is the activation target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PluginRow(
          name: 'MoviesDrive',
          subtitle: 'by Exalere Community',
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('MoviesDrive'));
    await tester.pump();

    expect(
      taps,
      1,
      reason: 'clicking the row must install, not just the trailing pill',
    );
  });

  testWidgets('a row without onTap is not a focus stop', (tester) async {
    await tester.pumpWidget(
      host(const PluginRow(name: 'Installed Add-on', subtitle: 'https://x')),
    );

    // No TvFocusable is created around the row content in this mode.
    final focusables = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'TvFocusable',
    );
    expect(focusables, findsNothing);
  });
}
