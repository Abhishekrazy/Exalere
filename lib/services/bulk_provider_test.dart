import 'dart:async';

import '../../models/exalere_plugin.dart' show ExalerePluginConfig;
import 'media_provider_plugin.dart';
import 'provider_diagnostics_service.dart';

/// One provider's verdict in a bulk run.
class BulkTestResult {
  const BulkTestResult({
    required this.providerId,
    required this.providerName,
    required this.outcome,
    required this.detail,
    required this.elapsed,
  });

  final String providerId;
  final String providerName;
  final ProviderHealth outcome;

  /// Short reason, e.g. `3 titles · 1 stream` or `timed out after 25s`.
  final String detail;

  final Duration elapsed;
}

/// What a bulk run found.
class BulkTestSummary {
  const BulkTestSummary({required this.results});

  final List<BulkTestResult> results;

  int get working =>
      results.where((r) => r.outcome == ProviderHealth.working).length;

  int get failing => results.length - working;

  bool get allWorking => results.isNotEmpty && failing == 0;

  String get headline => results.isEmpty
      ? 'No add-ons to test'
      : '$working of ${results.length} add-ons working';
}

/// Runs the single-provider health check over every installed add-on.
///
/// The per-add-on dialog already exists (Settings → Add-ons → Test); this is the
/// "Test all" pass behind it, kept as a plain service so the aggregation, the
/// per-provider budget and cancellation are testable without a widget tree.
class BulkProviderTest {
  const BulkProviderTest({
    Future<ProviderTestReport?> Function(
      MediaProviderPlugin provider, {
      Duration? stageTimeout,
    })?
    run,
    this.perProviderBudget = const Duration(seconds: 40),
  }) : _run = run;

  /// Injected in tests; production uses the shared diagnostics service.
  final Future<ProviderTestReport?> Function(
    MediaProviderPlugin provider, {
    Duration? stageTimeout,
  })?
  _run;

  /// A provider that has not finished within this window is reported as timed
  /// out; the next one still runs.
  final Duration perProviderBudget;

  Future<BulkTestSummary> run(
    List<MediaProviderPlugin> providers, {
    void Function(BulkTestResult result)? onResult,
    bool Function()? isCancelled,
  }) async {
    final run = _run ?? ProviderDiagnosticsService.instance.run;
    final results = <BulkTestResult>[];

    for (final provider in providers) {
      if (isCancelled?.call() ?? false) break;

      final watch = Stopwatch()..start();
      BulkTestResult result;
      try {
        final report = await run(
          provider,
          stageTimeout: perProviderBudget,
        ).timeout(perProviderBudget + const Duration(seconds: 5));
        result = BulkTestResult(
          providerId: provider.id,
          providerName: provider.name,
          // A null report means nothing could be tested — usually the add-on
          // is no longer registered.
          outcome: report?.health ?? ProviderHealth.untested,
          detail: report == null ? 'no engine to test' : _summarise(report),
          elapsed: watch.elapsed,
        );
      } on TimeoutException {
        result = BulkTestResult(
          providerId: provider.id,
          providerName: provider.name,
          outcome: ProviderHealth.failed,
          detail: 'timed out after ${perProviderBudget.inSeconds}s',
          elapsed: watch.elapsed,
        );
      } catch (error) {
        result = BulkTestResult(
          providerId: provider.id,
          providerName: provider.name,
          outcome: ProviderHealth.failed,
          detail: 'failed: $error',
          elapsed: watch.elapsed,
        );
      }
      results.add(result);
      onResult?.call(result);
    }

    return BulkTestSummary(results: results);
  }

  static String _summarise(ProviderTestReport report) => report.summary;
}

/// Convenience for callers that only have configs at hand.
List<MediaProviderPlugin> providersForConfigs(
  List<ExalerePluginConfig> configs,
  MediaProviderPlugin Function(ExalerePluginConfig config) create,
) => [for (final config in configs) create(config)];
