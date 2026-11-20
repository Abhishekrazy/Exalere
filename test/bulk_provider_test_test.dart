import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/bulk_provider_test.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';

class _Provider extends MediaProviderPlugin {
  _Provider(this.id, this.name);

  @override
  final String id;

  @override
  final String name;

  @override
  bool get supportsStreams => true;

  @override
  Future<List<MediaItem>> search(String query) async => const [];

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async => const [];
}

ProviderTestReport _report(
  MediaProviderPlugin provider,
  ProviderHealth health,
  String streamDetail,
) => ProviderTestReport(
  providerId: provider.id,
  providerName: provider.name,
  health: health,
  finishedAt: DateTime(2026),
  stages: [
    ProviderStageResult(
      stage: ProviderTestStage.catalog,
      outcome: ProviderStageOutcome.passed,
      detail: '3 titles',
    ),
    ProviderStageResult(
      stage: ProviderTestStage.streams,
      outcome: health == ProviderHealth.working
          ? ProviderStageOutcome.passed
          : ProviderStageOutcome.failed,
      detail: streamDetail,
    ),
  ],
);

void main() {
  group('bulk provider test', () {
    test('summarises working and failing add-ons in order', () async {
      final providers = [
        _Provider('a', 'Working A'),
        _Provider('b', 'Broken B'),
        _Provider('c', 'Working C'),
      ];

      final summary = await BulkProviderTest(
        run: (provider, {Duration? stageTimeout}) async => _report(
          provider,
          provider.id == 'b' ? ProviderHealth.failed : ProviderHealth.working,
          provider.id == 'b' ? 'Streams: no source' : '1 source(s)',
        ),
      ).run(providers);

      expect(summary.results.map((r) => r.providerId), ['a', 'b', 'c']);
      expect(summary.working, 2);
      expect(summary.failing, 1);
      expect(summary.allWorking, isFalse);
      expect(summary.headline, '2 of 3 add-ons working');
      expect(
        summary.results.firstWhere((r) => r.providerId == 'b').detail,
        contains('no source'),
      );
    });

    test('reports a thrown check as a failure and keeps going', () async {
      final summary = await BulkProviderTest(
        run: (provider, {Duration? stageTimeout}) async {
          if (provider.id == 'boom') throw StateError('exploded');
          return _report(provider, ProviderHealth.working, '1 source(s)');
        },
      ).run([_Provider('boom', 'Boom'), _Provider('ok', 'Ok')]);

      expect(summary.results, hasLength(2));
      expect(summary.results.first.outcome, ProviderHealth.failed);
      expect(summary.results.first.detail, contains('exploded'));
      expect(summary.results.last.outcome, ProviderHealth.working);
    });

    test('a hanging check times out without stopping the run', () async {
      final summary = await BulkProviderTest(
        perProviderBudget: const Duration(milliseconds: 150),
        run: (provider, {Duration? stageTimeout}) async {
          if (provider.id == 'slow') {
            await Future<void>.delayed(const Duration(seconds: 30));
          }
          return _report(provider, ProviderHealth.working, '1 source(s)');
        },
      ).run([_Provider('slow', 'Slow'), _Provider('fast', 'Fast')]);

      expect(summary.results, hasLength(2));
      expect(summary.results.first.detail, contains('timed out'));
      expect(summary.results.last.outcome, ProviderHealth.working);
    });

    test('reports each result as it lands and honours cancellation', () async {
      final seen = <String>[];
      var cancelled = false;
      final summary =
          await BulkProviderTest(
            run: (provider, {Duration? stageTimeout}) async {
              cancelled = true; // cancel after the first one finishes
              return _report(provider, ProviderHealth.working, '1 source(s)');
            },
          ).run(
            [_Provider('a', 'A'), _Provider('b', 'B')],
            onResult: (result) => seen.add(result.providerId),
            isCancelled: () => cancelled,
          );

      expect(seen, ['a']);
      expect(summary.results, hasLength(1));
    });

    test('an empty install list says so instead of dividing by zero', () async {
      final summary = await BulkProviderTest(
        run: (provider, {Duration? stageTimeout}) async =>
            _report(provider, ProviderHealth.working, '1 source(s)'),
      ).run(const []);

      expect(summary.allWorking, isFalse);
      expect(summary.headline, 'No add-ons to test');
    });
  });

  test('a provider whose engine is gone is reported, not skipped', () async {
    // PluginProvider.runProviderTest returns null when nothing is registered
    // for the id; the bulk run must still say something honest.
    final summary = await BulkProviderTest(
      run: (provider, {Duration? stageTimeout}) async => null,
    ).run([_Provider('gone', 'Gone')]);

    expect(summary.results, hasLength(1));
    expect(summary.results.single.outcome, ProviderHealth.untested);
    expect(summary.results.single.detail, contains('no engine'));
  });
}
