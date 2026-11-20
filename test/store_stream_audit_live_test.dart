import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/plugins/plugins.dart';
import 'package:exalere/providers/plugin_provider.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/services/verified_providers.dart';

/// The store's promise, tested entry by entry: anything that claims streams
/// either plays, carries the Verified badge, or says in so many words why it
/// cannot. Network test:
///   flutter test test/store_stream_audit_live_test.dart --dart-define=LIVE=1
const liveFlag = String.fromEnvironment('LIVE');
const live = liveFlag == '1' || liveFlag == 'true';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'every stream-claiming store entry is verified, tagged, or playing',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ProviderRegistry().clearAll();

      final provider = PluginProvider();
      await provider.initialize();
      final catalog = provider.communityCatalog;

      final excuses = <String>[];
      final broken = <String>[];

      for (final item in catalog) {
        if (VerifiedProviders.isVerified(item.id)) continue;
        if (VerifiedProviders.unavailableReason(item.id) != null) continue;
        // Rows that map onto a verified engine are a second door to it.
        if (VerifiedProviders.isVerified(item.id.split('.').last)) continue;

        var claimsStreams = true;
        try {
          final config = ExalerePluginConfig(
            id: item.id,
            name: item.name,
            baseUrl: item.manifestUrl,
            addedAt: DateTime.now(),
          );
          claimsStreams = createPlugin(config).supportsStreams;
        } catch (_) {
          // A row that cannot even build a plugin cannot play either.
          broken.add('${item.id} (no engine)');
          continue;
        }
        if (!claimsStreams) continue;

        if (!await provider.installPlugin(item.manifestUrl)) {
          broken.add('${item.id} (will not install)');
          continue;
        }
        final report = await provider.runProviderTest(item.id);
        final health = provider.healthFor(item.id);
        if (health == ProviderHealth.working) {
          // ignore: avoid_print
          print('${item.id.padRight(30)} working — ${report?.summary}');
        } else {
          broken.add('${item.id} (${report?.summary ?? 'no report'})');
        }
        if (report?.knownIssue != null) excuses.add(item.id);
      }

      expect(
        broken,
        isEmpty,
        reason:
            'these claim a stream but neither play nor say why: '
            '${broken.join(' | ')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !live,
  );
}
