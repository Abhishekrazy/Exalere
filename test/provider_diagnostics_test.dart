import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/services/provider_registry.dart';

/// Configurable stand-in for a real engine, so every stage outcome is provable.
class _FakeProvider extends MediaProviderPlugin {
  _FakeProvider({
    this.catalogItems = const [],
    this.searchItems = const [],
    this.detailsAvailable = true,
    this.streams = const [],
    this.supportsCatalog = true,
    this.supportsSearchFlag = true,
    this.throwOnSearch = false,
    this.hangOnSearch = false,
    this.supportsMetadataFlag = true,
  });

  @override
  String get id => 'fake';

  final List<MediaItem> catalogItems;
  final List<MediaItem> searchItems;
  final bool detailsAvailable;
  final List<StreamSource> streams;
  final bool supportsCatalog;
  final bool supportsSearchFlag;
  final bool throwOnSearch;
  final bool hangOnSearch;
  final bool supportsMetadataFlag;

  @override
  String get name => 'Fake $id';

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMetadata => supportsMetadataFlag;

  @override
  bool get supportsCatalogFeeds => supportsCatalog;

  @override
  bool get supportsSearch => supportsSearchFlag;

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async => catalogItems;

  @override
  Future<List<MediaItem>> search(String query) async {
    if (throwOnSearch) throw Exception('upstream returned HTML not JSON');
    if (hangOnSearch) {
      await Future<void>.delayed(const Duration(seconds: 30));
    }
    return searchItems;
  }

  @override
  Future<MediaDetails?> getDetails(String id) async {
    if (!detailsAvailable) return null;
    return MediaDetails(
      id: id,
      title: 'Resolved $id',
      mediaType: MediaType.movie,
      seasons: const [],
    );
  }

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
  }) async => streams;
}

MediaItem _item(String id, [String title = 'Dune']) =>
    MediaItem(id: id, title: title, mediaType: MediaType.movie, year: '2021');

const _playable = StreamSource(
  quality: '1080p',
  resolution: '1920x1080',
  format: 'HLS',
  url: 'https://cdn.example/a.m3u8',
);

void main() {
  final service = ProviderDiagnosticsService.instance;

  group('a fully working provider', () {
    test('is Working and every stage passes', () async {
      final report = await service.run(
        _FakeProvider(
          catalogItems: [_item('1')],
          searchItems: [_item('2')],
          streams: const [_playable],
        ),
      );

      expect(report.health, ProviderHealth.working);
      for (final stage in ProviderTestStage.values) {
        expect(
          report.stageOf(stage)!.outcome,
          ProviderStageOutcome.passed,
          reason: '${stage.label} should have passed',
        );
      }
      expect(
        report.stageOf(ProviderTestStage.streams)!.detail,
        contains('1 stream'),
      );
    });

    test('summarises stream quality for the badge', () async {
      final report = await service.run(
        _FakeProvider(
          searchItems: [_item('1')],
          streams: const [
            _playable,
            StreamSource(
              quality: '4K HDR',
              resolution: '3840x2160',
              format: 'HLS',
              url: 'https://cdn.example/b.m3u8',
            ),
          ],
        ),
      );

      expect(report.health, ProviderHealth.working);
      expect(report.summary, contains('2 streams'));
      expect(report.summary, contains('1080p'));
      expect(report.summary, contains('4K HDR'));
    });
  });

  group('an installed but useless provider', () {
    test('is Failed when it finds titles but no stream', () async {
      final report = await service.run(
        _FakeProvider(searchItems: [_item('1')], streams: const []),
      );

      expect(report.health, ProviderHealth.failed);
      expect(
        report.stageOf(ProviderTestStage.search)!.outcome,
        ProviderStageOutcome.passed,
      );
      expect(
        report.stageOf(ProviderTestStage.streams)!.outcome,
        ProviderStageOutcome.failed,
      );
      // The summary must name the failing stage, not just say "failed".
      expect(report.summary, contains('Streams'));
      expect(report.summary, contains('No playable stream'));
    });

    test('is Failed when it finds nothing at all', () async {
      final report = await service.run(_FakeProvider());

      expect(report.health, ProviderHealth.failed);
      expect(
        report.stageOf(ProviderTestStage.catalog)!.outcome,
        ProviderStageOutcome.failed,
      );
      expect(
        report.stageOf(ProviderTestStage.search)!.outcome,
        ProviderStageOutcome.failed,
      );
      expect(
        report.stageOf(ProviderTestStage.metadata)!.outcome,
        ProviderStageOutcome.skipped,
        reason: 'nothing was found to look up',
      );
      expect(
        report.stageOf(ProviderTestStage.streams)!.outcome,
        ProviderStageOutcome.skipped,
      );
    });

    test('is Failed when details cannot be resolved', () async {
      final report = await service.run(
        _FakeProvider(
          searchItems: [_item('1')],
          detailsAvailable: false,
          streams: const [_playable],
        ),
      );

      expect(
        report.stageOf(ProviderTestStage.metadata)!.outcome,
        ProviderStageOutcome.failed,
      );
      // Streams still ran, so a provider with working playback is not blocked by
      // a metadata gap.
      expect(report.health, ProviderHealth.working);
    });
  });

  group('stage capability skipping', () {
    test(
      'a streams-only addon is not marked broken for having no catalog',
      () async {
        final report = await service.run(
          _FakeProvider(
            supportsCatalog: false,
            searchItems: [_item('1')],
            streams: const [_playable],
          ),
        );

        expect(
          report.stageOf(ProviderTestStage.catalog)!.outcome,
          ProviderStageOutcome.skipped,
        );
        expect(
          report.stageOf(ProviderTestStage.catalog)!.detail,
          'No catalog capability',
        );
        expect(report.health, ProviderHealth.working);
      },
    );

    test('a catalog-only addon skips search but can still pass', () async {
      final report = await service.run(
        _FakeProvider(
          supportsSearchFlag: false,
          catalogItems: [_item('1')],
          streams: const [_playable],
        ),
      );

      expect(
        report.stageOf(ProviderTestStage.search)!.outcome,
        ProviderStageOutcome.skipped,
      );
      expect(
        report.stageOf(ProviderTestStage.search)!.detail,
        'No search capability',
      );
      expect(report.health, ProviderHealth.working);
    });

    test(
      'a provider with neither capability cannot resolve anything',
      () async {
        final report = await service.run(
          _FakeProvider(
            supportsCatalog: false,
            supportsSearchFlag: false,
            streams: const [_playable],
          ),
        );

        expect(report.health, ProviderHealth.failed);
        expect(
          report.stageOf(ProviderTestStage.streams)!.outcome,
          ProviderStageOutcome.skipped,
        );
      },
    );
  });

  group('error handling', () {
    test(
      'a thrown error becomes a short failed detail, not a stack trace',
      () async {
        final report = await service.run(_FakeProvider(throwOnSearch: true));

        final search = report.stageOf(ProviderTestStage.search)!;
        expect(search.outcome, ProviderStageOutcome.failed);
        expect(search.detail, contains('HTML not JSON'));
        expect(search.detail, isNot(contains('package:')));
        expect(search.detail.length, lessThanOrEqualTo(121));
      },
    );

    test('a hanging stage times out and reports it', () async {
      final report = await service.run(
        _FakeProvider(hangOnSearch: true),
        stageTimeout: const Duration(milliseconds: 150),
      );

      final search = report.stageOf(ProviderTestStage.search)!;
      expect(search.outcome, ProviderStageOutcome.failed);
      expect(search.detail, contains('Timed out'));
      expect(report.health, ProviderHealth.failed);
    });

    test('reports the elapsed time of a stage', () async {
      final report = await service.run(_FakeProvider());
      expect(
        report.stageOf(ProviderTestStage.search)!.elapsed,
        greaterThan(Duration.zero),
      );
    });
  });

  group('progress reporting', () {
    test('onStage fires once per applicable stage in order', () async {
      final seen = <ProviderTestStage>[];
      await service.run(
        _FakeProvider(
          catalogItems: [_item('1')],
          searchItems: [_item('2')],
          streams: const [_playable],
        ),
        onStage: (result) => seen.add(result.stage),
      );

      expect(seen, [
        ProviderTestStage.catalog,
        ProviderTestStage.search,
        ProviderTestStage.metadata,
        ProviderTestStage.streams,
      ]);
    });
  });

  group('streams-only providers', () {
    test('metadata is skipped, not failed, when unsupported', () async {
      final report = await service.run(
        _FakeProvider(
          searchItems: [_item('1')],
          streams: const [_playable],
          supportsMetadataFlag: false,
        ),
      );

      final metadata = report.stageOf(ProviderTestStage.metadata)!;
      expect(metadata.outcome, ProviderStageOutcome.skipped);
      expect(metadata.detail, 'No metadata capability');
      // A provider that resolves streams is Working even with no metadata.
      expect(report.health, ProviderHealth.working);
    });

    test('an unsupported metadata stage is never called', () async {
      final provider = _FakeProvider(
        searchItems: [_item('1')],
        streams: const [_playable],
        supportsMetadataFlag: false,
        detailsAvailable: false,
      );
      final report = await service.run(provider);

      // If getDetails had been called with detailsAvailable=false it would have
      // reported a failure; skipping proves the call was avoided entirely.
      expect(
        report.stageOf(ProviderTestStage.metadata)!.outcome,
        ProviderStageOutcome.skipped,
      );
    });

    test('a metadata-capable provider still reports a real failure', () async {
      final report = await service.run(
        _FakeProvider(
          searchItems: [_item('1')],
          detailsAvailable: false,
          streams: const [_playable],
        ),
      );

      expect(
        report.stageOf(ProviderTestStage.metadata)!.outcome,
        ProviderStageOutcome.failed,
        reason: 'capability was claimed, so a missing result is a real failure',
      );
    });
  });

  group('report shape', () {
    test('skipped stages are not counted as failures in the summary', () async {
      final report = await service.run(
        _FakeProvider(
          supportsCatalog: false,
          searchItems: [_item('1')],
          streams: const [_playable],
        ),
      );
      expect(report.summary, isNot(contains('Catalog')));
    });

    test('stageOf returns null for a stage that never ran', () {
      final report = ProviderTestReport(
        providerId: 'x',
        providerName: 'X',
        stages: const [],
        health: ProviderHealth.untested,
        finishedAt: DateTime(2024),
      );
      expect(report.stageOf(ProviderTestStage.streams), isNull);
    });

    test('every stage has a human label', () {
      for (final stage in ProviderTestStage.values) {
        expect(stage.label, isNotEmpty);
      }
    });
  });
}
