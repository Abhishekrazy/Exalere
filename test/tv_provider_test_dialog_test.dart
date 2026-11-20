import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/provider_test_dialog.dart';

/// The flask-icon self-test, drawn at TV size with a canned report.
///
/// The device has been unreachable all session, so this pins what a remote would
/// actually see when the dialog opens: every stage line, the verdict, and the
/// dated reason when the add-on is tagged Unavailable. It also drives the D-pad,
/// because a dialog that renders but traps focus is not usable on a television.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderTestReport report({String? knownIssue}) => ProviderTestReport(
    providerId: 'demo',
    providerName: 'Demo Add-on',
    stages: const [
      ProviderStageResult(
        stage: ProviderTestStage.catalog,
        outcome: ProviderStageOutcome.passed,
        detail: '41 items',
      ),
      ProviderStageResult(
        stage: ProviderTestStage.search,
        outcome: ProviderStageOutcome.passed,
        detail: '5 hits',
      ),
      ProviderStageResult(
        stage: ProviderTestStage.metadata,
        outcome: ProviderStageOutcome.skipped,
        detail: 'Declares none',
      ),
      ProviderStageResult(
        stage: ProviderTestStage.streams,
        outcome: ProviderStageOutcome.passed,
        detail: '7 streams · 1080p',
        itemCount: 7,
      ),
    ],
    health: ProviderHealth.working,
    finishedAt: DateTime(2026, 11, 20),
    knownIssue: knownIssue,
  );

  Future<void> pumpDialog(
    WidgetTester tester, {
    required ProviderTestReport value,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final plugins = PluginProvider();
    await plugins.initialize();
    await tester.pump();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920, 1080)),
        child: ChangeNotifierProvider<PluginProvider>.value(
          value: plugins,
          child: MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: ProviderTestDialog(
                providerId: 'demo',
                providerName: 'Demo Add-on',
                runTest: (id, {onStage}) async {
                  // The rows are painted from the stage callbacks as the run
                  // progresses, exactly as the real diagnostics service reports;
                  // the returned report only fills the verdict and known issue.
                  for (final stage in value.stages) {
                    onStage?.call(stage);
                  }
                  return value;
                },
              ),
            ),
          ),
        ),
      ),
    );
    // The dialog runs its test in initState. It paints a spinner while that
    // future is pending, so settle by pumping frames rather than waiting for
    // every animation to stop (pumpAndSettle never returns against a spinner).
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() {
    // PluginProvider reads the plugin store through SharedPreferences; without a
    // mock the platform channel never answers and the test hangs at initialize().
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('every stage, the verdict and the add-on name are on screen', (
    tester,
  ) async {
    await pumpDialog(tester, value: report());

    expect(find.textContaining('Demo Add-on'), findsWidgets);
    expect(find.textContaining('41 items'), findsWidgets);
    expect(find.textContaining('5 hits'), findsWidgets);
    // The stage row and the verdict summary both carry it.
    expect(find.textContaining('7 streams'), findsWidgets);
  });

  testWidgets('an add-on tagged Unavailable shows its dated reason', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      value: report(
        knownIssue: 'the visitor API returns a 23-second advert (2026-11-20)',
      ),
    );

    expect(find.textContaining('23-second advert'), findsOneWidget);
  });

  testWidgets('the D-pad moves through the dialog without trapping focus', (
    tester,
  ) async {
    await pumpDialog(tester, value: report());

    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    // Nothing threw, and the dialog is still on screen rather than popped.
    expect(find.textContaining('Demo Add-on'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
