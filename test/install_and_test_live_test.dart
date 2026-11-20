import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/services/provider_registry.dart';

/// The closest thing to a user's first run that can be automated without a TV:
/// install through the store path the row uses, let the provider run its own
/// health check, and confirm the verdict is stored where the list reads it.
///
/// Network test: run explicitly.
///   flutter test test/install_and_test_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'installing through the store and testing it stores a working verdict',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ProviderRegistry().clearAll();

      final provider = PluginProvider();
      await provider.initialize();
      final installed = await provider.installPlugin('kisskh://engine');

      expect(installed, isTrue, reason: 'the store path must accept it');
      expect(ProviderRegistry().resolveProvider('kisskh'), isNotNull);

      final stages = <ProviderTestStage>[];
      final report = await provider.runProviderTest(
        'kisskh',
        onStage: (result) => stages.add(result.stage),
      );

      // ignore: avoid_print
      print(
        'stages=${stages.map((s) => s.name).join(' -> ')} '
        'health=${provider.healthFor('kisskh')} '
        'summary=${report?.summary}',
      );

      expect(report, isNotNull);
      expect(provider.healthFor('kisskh'), ProviderHealth.working);
      expect(provider.reportFor('kisskh'), isNotNull);
      expect(stages, contains(ProviderTestStage.streams));

      // A fresh provider reads the same verdict back: the list must survive a
      // restart, not only the session that ran the test.
      final reloaded = PluginProvider();
      await reloaded.initialize();
      expect(reloaded.healthFor('kisskh'), ProviderHealth.working);
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !live,
  );

  test(
    'a catalogue-only add-on installs and tests through the same path',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ProviderRegistry().clearAll();

      final provider = PluginProvider();
      await provider.initialize();
      expect(await provider.installPlugin('gokuhd://engine'), isTrue);

      final report = await provider.runProviderTest('gokuhd');

      // ignore: avoid_print
      print(
        'gokuhd health=${provider.healthFor('gokuhd')} summary=${report?.summary}',
      );

      expect(report, isNotNull);
      expect(provider.healthFor('gokuhd'), ProviderHealth.working);
      // It has no search by design, so that stage must be skipped rather than
      // failed — a red row for a capability it never had would be a lie.
      expect(
        report!.stageOf(ProviderTestStage.search)?.outcome,
        ProviderStageOutcome.skipped,
      );
      expect(
        report.stageOf(ProviderTestStage.streams)?.outcome,
        ProviderStageOutcome.passed,
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !live,
  );
}
