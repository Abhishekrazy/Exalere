import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exalere/services/provider_diagnostics_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/settings/provider_test_dialog.dart';

/// The dialog is what a user taps when "I installed an add-on and see nothing".
/// These tests drive it with a scripted run so the four stages, the progress
/// callbacks and the final verdict are pinned without the network.
void main() {
  ProviderStageResult stage(
    ProviderTestStage stage,
    ProviderStageOutcome outcome,
    String detail,
  ) => ProviderStageResult(stage: stage, outcome: outcome, detail: detail);

  Widget app(Widget child) => MaterialApp(
    theme: AppThemes.darkTheme.themeData,
    home: Scaffold(body: child),
  );

  testWidgets('shows every stage and the verdict as they settle', (
    tester,
  ) async {
    final report = ProviderTestReport(
      providerId: 'fake',
      providerName: 'Fake',
      health: ProviderHealth.working,
      finishedAt: DateTime(2026),
      stages: [
        stage(ProviderTestStage.catalog, ProviderStageOutcome.passed, '12'),
        stage(ProviderTestStage.search, ProviderStageOutcome.passed, 'ok'),
        stage(ProviderTestStage.metadata, ProviderStageOutcome.skipped, 'n/a'),
        stage(ProviderTestStage.streams, ProviderStageOutcome.passed, '2'),
      ],
    );

    await tester.pumpWidget(
      app(
        Provider(
          create: (_) => null,
          child: ProviderTestDialog(
            providerId: 'fake',
            providerName: 'Fake',
            runTest: (id, {onStage}) async {
              for (final result in report.stages) {
                onStage?.call(result);
              }
              return report;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Catalog', 'Search', 'Metadata', 'Streams']) {
      expect(find.textContaining(label), findsWidgets);
    }
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('reports a run that produced no report', (tester) async {
    await tester.pumpWidget(
      app(
        Provider(
          create: (_) => null,
          child: const ProviderTestDialog(
            providerId: 'missing',
            providerName: 'Missing',
            runTest: _noReport,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The dialog must still offer a way out rather than spin forever.
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('a failing add-on also shows the reason the store knows', (
    tester,
  ) async {
    final report = ProviderTestReport(
      providerId: 'hdhub4u',
      providerName: 'HDHub4u',
      health: ProviderHealth.failed,
      finishedAt: DateTime(2026),
      knownIssue: 'A post resolves no playable source (checked 2026-11-20)',
      stages: [
        stage(ProviderTestStage.catalog, ProviderStageOutcome.passed, '43'),
        stage(ProviderTestStage.search, ProviderStageOutcome.passed, '3'),
        stage(ProviderTestStage.metadata, ProviderStageOutcome.skipped, 'n/a'),
        stage(
          ProviderTestStage.streams,
          ProviderStageOutcome.failed,
          'No playable source',
        ),
      ],
    );

    await tester.pumpWidget(
      app(
        Provider(
          create: (_) => null,
          child: ProviderTestDialog(
            providerId: 'hdhub4u',
            providerName: 'HDHub4u',
            runTest: (id, {onStage}) async => report,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Not working'), findsWidgets);
    expect(
      find.textContaining('resolves no playable source'),
      findsWidgets,
      reason: 'the dialog should not leave the user guessing',
    );
  });
}

/// A run that produced nothing: the dialog must still close.
Future<ProviderTestReport?> _noReport(
  String id, {
  void Function(ProviderStageResult result)? onStage,
}) async => null;
