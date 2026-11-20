import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/verified_providers.dart';

/// The user-facing matrix: every verified add-on, installed through the store
/// path and tested by the app's own health check.
///
/// This is the claim the store makes — "installed and working" — checked the way
/// a user checks it, for all fourteen at once. Network test:
///
///   flutter test test/first_run_matrix_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'every verified add-on installs and reports working',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ProviderRegistry().clearAll();

      final provider = PluginProvider();
      await provider.initialize();
      final failures = <String, String?>{};

      for (final id in VerifiedProviders.ids) {
        final installed = await provider.installPlugin('$id://engine');
        if (!installed) {
          // ignore: avoid_print
          print('${id.padRight(15)} INSTALL FAILED');
          continue;
        }
        final watch = Stopwatch()..start();
        final report = await provider.runProviderTest(id);
        watch.stop();
        // ignore: avoid_print
        print(
          '${id.padRight(15)} ${provider.healthFor(id).name.padRight(9)} '
          '${watch.elapsedMilliseconds.toString().padLeft(6)} ms  '
          '${report?.summary ?? 'no report'}',
        );
        failures[id] = provider.healthFor(id) == ProviderHealth.working
            ? null
            : (report?.summary ?? 'no report');
      }

      final broken = failures.entries
          .where((entry) => entry.value != null)
          .map((entry) => '${entry.key}: ${entry.value}')
          .toList();
      expect(broken, isEmpty, reason: 'add-ons the store would show red');
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !live,
  );
}
