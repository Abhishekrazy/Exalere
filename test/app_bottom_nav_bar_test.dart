import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/navigation/app_bottom_nav_bar.dart';

const _items = [
  AppNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Home',
  ),
  AppNavItem(
    icon: Icons.search_outlined,
    activeIcon: Icons.search_rounded,
    label: 'Search',
  ),
  AppNavItem(
    icon: Icons.live_tv_outlined,
    activeIcon: Icons.live_tv_rounded,
    label: 'Live TV',
  ),
  AppNavItem(
    icon: Icons.bookmark_outline_rounded,
    activeIcon: Icons.bookmark_rounded,
    label: 'My List',
  ),
  AppNavItem(
    icon: Icons.download_outlined,
    activeIcon: Icons.download_rounded,
    label: 'Downloads',
  ),
  AppNavItem(
    icon: Icons.link_outlined,
    activeIcon: Icons.link_rounded,
    label: 'Streams',
  ),
  AppNavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    label: 'Settings',
  ),
];

Widget _wrap({
  int currentIndex = 0,
  ValueChanged<int>? onSelected,
  Size size = const Size(360, 720),
}) {
  return MaterialApp(
    theme: AppThemes.netflixBlack.themeData,
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: AppBottomNavBar(
          items: _items,
          currentIndex: currentIndex,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('AppBottomNavBar', () {
    testWidgets('renders every label on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Seven destinations must all remain labelled; the stock NavigationBar
      // clipped these at this width.
      for (final item in _items) {
        expect(
          find.text(item.label),
          findsOneWidget,
          reason: 'missing label for ${item.label}',
        );
      }
    });

    testWidgets('marks the selected destination with its active icon', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(currentIndex: 4));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      // Inactive destinations keep their outline icon.
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsNothing);
    });

    testWidgets('reports the tapped destination index', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final taps = <int>[];
      await tester.pumpWidget(_wrap(onSelected: taps.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();

      expect(taps, [6, 4]);
    });

    testWidgets('does not overflow on a very narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(size: const Size(320, 640)));
      await tester.pumpAndSettle();

      // An overflow here would surface as a thrown FlutterError during layout.
      expect(tester.takeException(), isNull);
    });

    testWidgets('exposes selection state to assistive technology', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrap(currentIndex: 2));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.text('Live TV'));
      expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });
}
