import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/plugin_row.dart';

/// The store's honesty lives in two derived tags, and on a 10-foot screen they
/// are squeezed into one metadata line next to the author. These tests render
/// the real catalogue's longest rows at TV sizes and assert nothing overflows
/// and the badge is actually on screen.
void main() {
  Widget surface(Widget child, {required Size size}) => MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppThemes.darkTheme.themeData,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width / 2 - 24, child: child),
        ),
      ),
    ),
  );

  PluginRow rowFor(String id) {
    final item = PluginService().getCommunityCatalog().firstWhere(
      (candidate) => candidate.id == id,
    );
    final tags = item.tags.take(2).join(' · ');
    return PluginRow(
      name: item.name,
      subtitle: tags.isEmpty
          ? 'by ${item.author}'
          : 'by ${item.author} · $tags',
      iconUrl: item.icon,
      onTap: () {},
    );
  }

  group('store badges at TV size', () {
    testWidgets('a catalogue-only verified add-on shows both badges', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        surface(rowFor('gokuhd'), size: const Size(1280, 720)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Verified'), findsOneWidget);
      expect(find.textContaining('Catalogue only'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a demoted add-on says Unavailable, not Verified', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        surface(rowFor('animesalt'), size: const Size(1280, 720)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Unavailable'), findsOneWidget);
      expect(find.textContaining('Verified'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone-width row still fits', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        surface(rowFor('gokuhd'), size: const Size(390, 844)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
