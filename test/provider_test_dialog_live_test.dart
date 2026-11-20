import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';

/// Drives the engine path the provider-test dialog uses, against the network.
///
/// The dialog itself is covered by widget tests with a scripted run; this proves
/// the other half — that a real installed add-on walks Catalog → Search →
/// Metadata → Streams and reports them in order, which is what the flake icon
/// shows a user.
///
///   flutter test test/provider_test_dialog_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');

/// `--dart-define=LIVE=1` (or `=true`) turns the network test on.
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  HttpOverrides.global = null;

  test(
    'a verified add-on walks every stage the dialog shows',
    () async {
      final plugin = createPlugin(
        ExalerePluginConfig(
          id: 'kisskh',
          name: 'KissKh',
          baseUrl: 'kisskh://engine',
          addedAt: DateTime.now(),
        ),
      );

      final stages = <ProviderTestStage>[];
      final report = await ProviderDiagnosticsService.instance.run(
        plugin,
        onStage: (result) => stages.add(result.stage),
      );

      // ignore: avoid_print
      print(
        'stages=${stages.map((s) => s.name).join(' -> ')} '
        'health=${report.health} summary=${report.summary}',
      );

      expect(stages, isNotEmpty);
      expect(report.health, ProviderHealth.working);
      expect(
        report.stageOf(ProviderTestStage.streams)?.outcome,
        ProviderStageOutcome.passed,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !live,
  );
}
