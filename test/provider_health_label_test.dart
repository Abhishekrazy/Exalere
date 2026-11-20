import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/ui/widgets/settings/provider_health_label.dart';

/// The store persists a verdict per add-on but used to show nothing, so telling
/// a working add-on from a dead one meant re-running the check. These tests pin
/// the wording the row now shows.
void main() {
  ProviderTestReport report({
    required ProviderHealth health,
    required String streamsDetail,
    ProviderStageOutcome streamsOutcome = ProviderStageOutcome.passed,
  }) => ProviderTestReport(
    providerId: 'p',
    providerName: 'P',
    health: health,
    finishedAt: DateTime(2026),
    stages: [
      ProviderStageResult(
        stage: ProviderTestStage.streams,
        outcome: streamsOutcome,
        detail: streamsDetail,
      ),
    ],
  );

  test('a working add-on names what it produced', () {
    final healthy = report(
      health: ProviderHealth.working,
      streamsDetail: '4 source(s), first MP4',
    );

    expect(PluginHealth.label(ProviderHealth.working, healthy), contains('4'));
    expect(PluginHealth.shortLabel(ProviderHealth.working, healthy), 'Working');
  });

  test('a failed add-on says why, not just that it failed', () {
    final broken = report(
      health: ProviderHealth.failed,
      streamsDetail: 'no playable source',
      streamsOutcome: ProviderStageOutcome.failed,
    );

    final label = PluginHealth.label(ProviderHealth.failed, broken);
    expect(label, startsWith('Failed'));
    expect(label, contains('no playable source'));
  });

  test('an untested add-on spends no badge at all', () {
    expect(PluginHealth.isBadgeWorthy(ProviderHealth.untested), isFalse);
    expect(PluginHealth.isBadgeWorthy(ProviderHealth.working), isTrue);
    expect(PluginHealth.isBadgeWorthy(ProviderHealth.failed), isTrue);
    expect(PluginHealth.isBadgeWorthy(ProviderHealth.testing), isTrue);
  });

  test('a verdict without a report still reads sensibly', () {
    expect(PluginHealth.label(ProviderHealth.working, null), 'Working');
    expect(PluginHealth.label(ProviderHealth.failed, null), 'Failed');
    expect(PluginHealth.label(ProviderHealth.testing, null), 'Testing…');
  });
}
