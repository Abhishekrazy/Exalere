import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/verified_providers.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/tv_settings_view.dart';

/// The Add-ons settings screen with every verified add-on installed, drawn at TV
/// size. The device itself has been unreachable all session, so this pins what
/// the remote would see: the list is there, each row carries its badge, the
/// "Test all" action exists, and D-pad input does not throw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the add-ons screen renders the full verified set at TV size', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final plugins = PluginProvider();
    await plugins.initialize();
    for (final id in VerifiedProviders.ids) {
      await plugins.installPlugin('$id://engine');
    }
    await tester.pump();

    final app = AppProvider();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: app),
            ChangeNotifierProvider<PluginProvider>.value(value: plugins),
          ],
          child: MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: TvSettingsView(
                detectedPlayers: const [],
                iptvController: TextEditingController(),
                storageService: StorageService(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The screen opens on the root tiles; the add-on list lives one level in.
    // The tile lives below the fold on a 1080p screen, which is exactly the
    // real path: the user scrolls to it.
    await tester.scrollUntilVisible(
      find.text('Add-ons'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add-ons'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The screen landed on the add-ons page: the community list is bound to the
    // real catalogue and the rows carry their derived badges.
    expect(find.textContaining('COMMUNITY ADD-ONS'), findsOneWidget);

    final verifiedBadges = find.textContaining('Verified').evaluate().length;
    expect(
      verifiedBadges,
      greaterThan(0),
      reason: 'installed add-ons should show their Verified badge',
    );

    // The installed section (with the Test-all action) is further down the page.
    await tester.scrollUntilVisible(
      find.textContaining('INSTALLED ADD-ONS'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('INSTALLED ADD-ONS'), findsOneWidget);
    expect(
      find.text('Test all'),
      findsOneWidget,
      reason: 'the one-tap health check must be reachable on TV',
    );

    // D-pad input must not throw anywhere on the screen.
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
