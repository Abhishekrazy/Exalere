import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/bulk_provider_test.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/provider_bulk_test_dialog.dart';

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
) => ProviderTestReport(
  providerId: provider.id,
  providerName: provider.name,
  health: health,
  finishedAt: DateTime(2026),
  stages: [
    ProviderStageResult(
      stage: ProviderTestStage.streams,
      outcome: health == ProviderHealth.working
          ? ProviderStageOutcome.passed
          : ProviderStageOutcome.failed,
      detail: health == ProviderHealth.working
          ? '1 source(s)'
          : 'Streams: no source',
    ),
  ],
);

Widget _app(Widget child) => MaterialApp(
  theme: AppThemes.darkTheme.themeData,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('lists every add-on with its verdict', (tester) async {
    final providers = [_Provider('a', 'Working A'), _Provider('b', 'Broken B')];
    final bulk = BulkProviderTest(
      run: (provider, {Duration? stageTimeout}) async => _report(
        provider,
        provider.id == 'b' ? ProviderHealth.failed : ProviderHealth.working,
      ),
    );

    await tester.pumpWidget(
      _app(ProviderBulkTestDialog(providers: providers, bulk: bulk)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Working A'), findsOneWidget);
    expect(find.text('Broken B'), findsOneWidget);
    expect(find.text('1 source(s)'), findsOneWidget);
    // report.summary prefixes the failing stage label.
    expect(find.textContaining('no source'), findsOneWidget);
    expect(find.text('1 of 2 add-ons working'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('offers Stop while the run is in flight', (tester) async {
    final providers = [_Provider('slow', 'Slow One')];
    final bulk = BulkProviderTest(
      run: (provider, {Duration? stageTimeout}) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return _report(provider, ProviderHealth.working);
      },
    );

    await tester.pumpWidget(
      _app(ProviderBulkTestDialog(providers: providers, bulk: bulk)),
    );
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsOneWidget);
    expect(find.text('1 of 1 add-ons working'), findsOneWidget);
  });
}
