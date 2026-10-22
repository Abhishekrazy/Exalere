import 'dart:async';

import '../models/media_item.dart';
import '../models/stream_source.dart';
import 'provider_registry.dart';

/// One step of a provider health check.
enum ProviderTestStage {
  /// Can it list its own catalog?
  catalog,

  /// Can it find a title by name?
  search,

  /// Can it return details (synopsis, seasons) for a title it found?
  metadata,

  /// Can it actually hand back a playable stream?
  streams;

  String get label {
    switch (this) {
      case ProviderTestStage.catalog:
        return 'Catalog';
      case ProviderTestStage.search:
        return 'Search';
      case ProviderTestStage.metadata:
        return 'Metadata';
      case ProviderTestStage.streams:
        return 'Streams';
    }
  }
}

/// Outcome of a single stage.
enum ProviderStageOutcome {
  passed,
  failed,

  /// Not applicable to this provider (e.g. no catalog capability), or it could
  /// not be attempted because an earlier stage found nothing to work with.
  skipped,
}

/// Overall verdict for a provider.
enum ProviderHealth {
  /// Never checked.
  untested,

  /// A check is running.
  testing,

  /// The provider produced a playable stream during the check.
  working,

  /// The provider was reachable in no useful way, or produced no stream.
  failed,
}

/// Result of one stage, with a human-readable explanation.
class ProviderStageResult {
  const ProviderStageResult({
    required this.stage,
    required this.outcome,
    required this.detail,
    this.itemCount = 0,
    this.elapsed = Duration.zero,
  });

  final ProviderTestStage stage;
  final ProviderStageOutcome outcome;
  final String detail;
  final int itemCount;
  final Duration elapsed;
}

/// Full report for one provider.
class ProviderTestReport {
  const ProviderTestReport({
    required this.providerId,
    required this.providerName,
    required this.stages,
    required this.health,
    required this.finishedAt,
  });

  final String providerId;
  final String providerName;
  final List<ProviderStageResult> stages;
  final ProviderHealth health;
  final DateTime finishedAt;

  ProviderStageResult? stageOf(ProviderTestStage stage) {
    for (final result in stages) {
      if (result.stage == stage) return result;
    }
    return null;
  }

  /// One-line summary for a badge or a toast.
  String get summary {
    switch (health) {
      case ProviderHealth.working:
        final streams = stageOf(ProviderTestStage.streams);
        return streams?.detail ?? 'Working';
      case ProviderHealth.failed:
        // Lead with the stage that actually blocks playback. Reporting an
        // earlier incidental failure (an empty catalog, say) would hide the real
        // reason a provider cannot be played.
        final blocking = stageOf(ProviderTestStage.streams);
        if (blocking != null &&
            blocking.outcome == ProviderStageOutcome.failed) {
          return '${blocking.stage.label}: ${blocking.detail}';
        }
        if (stages.isEmpty) return 'Failed';
        final failedStage = stages.firstWhere(
          (s) => s.outcome == ProviderStageOutcome.failed,
          orElse: () => stages.last,
        );
        return '${failedStage.stage.label}: ${failedStage.detail}';
      case ProviderHealth.testing:
        return 'Testing…';
      case ProviderHealth.untested:
        return 'Not tested';
    }
  }
}

/// Checks whether an installed provider actually works, stage by stage.
///
/// Mirrors how the app really uses a provider — list, search, look up details,
/// resolve a stream — so a pass means a playable link exists *right now*, not
/// merely that the plugin installed. Each stage is skipped rather than failed
/// when the provider does not claim that capability, so a streams-only addon is
/// not marked broken for having no catalog.
class ProviderDiagnosticsService {
  ProviderDiagnosticsService._();

  static final ProviderDiagnosticsService instance =
      ProviderDiagnosticsService._();

  /// Titles used to probe search. Several are tried because a provider may
  /// legitimately not carry the first one.
  static const List<String> probeTitles = [
    'Dune',
    'The Matrix',
    'Breaking Bad',
  ];

  /// How long a single stage may take before it is reported as timed out.
  static const Duration defaultStageTimeout = Duration(seconds: 25);

  /// Runs every applicable stage against [provider].
  ///
  /// [onStage] fires as each stage settles, so a UI can show progress.
  /// [stageTimeout] is overridable so tests do not have to wait out the real one.
  Future<ProviderTestReport> run(
    MediaProviderPlugin provider, {
    void Function(ProviderStageResult result)? onStage,
    Duration? stageTimeout,
  }) async {
    final timeout = stageTimeout ?? defaultStageTimeout;
    final results = <ProviderStageResult>[];

    // The candidate every later stage works from, discovered by whichever of
    // catalog/search actually finds something.
    MediaItem? candidate;

    // --- 1. Catalog ------------------------------------------------------
    if (!provider.supportsCatalogFeeds) {
      results.add(_skip(ProviderTestStage.catalog, 'No catalog capability'));
    } else {
      final result = await _timed(ProviderTestStage.catalog, timeout, () async {
        final items = await provider.getCatalogFeed(
          category: 'featured',
          page: 1,
        );
        if (items.isEmpty) {
          return (ProviderStageOutcome.failed, 'Returned no titles', 0);
        }
        candidate ??= items.first;
        return (
          ProviderStageOutcome.passed,
          '${items.length} titles',
          items.length,
        );
      });
      results.add(result);
      onStage?.call(result);
    }

    // --- 2. Search -------------------------------------------------------
    if (!provider.supportsSearch) {
      results.add(_skip(ProviderTestStage.search, 'No search capability'));
    } else {
      final result = await _timed(ProviderTestStage.search, timeout, () async {
        for (final query in probeTitles) {
          final items = await provider.search(query);
          if (items.isNotEmpty) {
            candidate ??= items.first;
            return (
              ProviderStageOutcome.passed,
              'Found "${items.first.title}" for "$query"',
              items.length,
            );
          }
        }
        return (
          ProviderStageOutcome.failed,
          'No results for ${probeTitles.join(', ')}',
          0,
        );
      });
      results.add(result);
      onStage?.call(result);
    }

    // --- 3. Metadata -----------------------------------------------------
    final target = candidate;
    if (target == null) {
      results.add(
        _skip(ProviderTestStage.metadata, 'Nothing found to look up'),
      );
      results.add(_skip(ProviderTestStage.streams, 'Nothing found to play'));
      return _report(provider, results);
    }

    // A streams-only provider never claimed metadata, so reporting a red
    // failure here would invent a problem. Skipping keeps the verdict honest.
    if (!provider.supportsMetadata) {
      final skipped = _skip(
        ProviderTestStage.metadata,
        'No metadata capability',
      );
      results.add(skipped);
      onStage?.call(skipped);
    } else {
      final metadataResult = await _timed(
        ProviderTestStage.metadata,
        timeout,
        () async {
          final details = await provider.getDetails(target.id);
          if (details == null) {
            return (
              ProviderStageOutcome.failed,
              'No details for "${target.title}"',
              0,
            );
          }
          final seasonNote = details.seasons.isNotEmpty
              ? ', ${details.seasons.length} seasons'
              : '';
          return (
            ProviderStageOutcome.passed,
            'Details for "${details.title}"$seasonNote',
            1,
          );
        },
      );
      results.add(metadataResult);
      onStage?.call(metadataResult);
    }

    // --- 4. Streams ------------------------------------------------------
    final streamsResult = await _timed(
      ProviderTestStage.streams,
      timeout,
      () async {
        final streams = await provider.getStreams(
          subjectId: target.id,
          title: target.title,
          year: target.year,
          isSeries: target.isSeries,
          originProviderId: target.effectiveProviderId,
        );
        final usable = streams.where((s) => s.url.isNotEmpty).toList();
        if (usable.isEmpty) {
          return (
            ProviderStageOutcome.failed,
            'No playable stream for "${target.title}"',
            0,
          );
        }
        return (
          ProviderStageOutcome.passed,
          _describeStreams(usable),
          usable.length,
        );
      },
    );
    results.add(streamsResult);
    onStage?.call(streamsResult);

    return _report(provider, results);
  }

  /// `3 streams · 4K HDR · 1080p`, so the verdict is informative at a glance.
  static String _describeStreams(List<StreamSource> streams) {
    final qualities = <String>{};
    for (final stream in streams) {
      final quality = stream.quality.trim();
      if (quality.isNotEmpty) qualities.add(quality);
    }
    final buffer = StringBuffer()..write('${streams.length} stream');
    if (streams.length != 1) buffer.write('s');
    if (qualities.isNotEmpty) {
      buffer.write(' · ${qualities.take(3).join(' · ')}');
    }
    return buffer.toString();
  }

  ProviderTestReport _report(
    MediaProviderPlugin provider,
    List<ProviderStageResult> stages,
  ) {
    // A playable stream is the only real proof of health. Catalog and search
    // passing while streams fails means the provider is installed but useless,
    // which is exactly the failure users cannot otherwise diagnose.
    final hasStreamPass = stages.any(
      (s) =>
          s.stage == ProviderTestStage.streams &&
          s.outcome == ProviderStageOutcome.passed,
    );

    return ProviderTestReport(
      providerId: provider.id,
      providerName: provider.name,
      stages: stages,
      health: hasStreamPass ? ProviderHealth.working : ProviderHealth.failed,
      finishedAt: DateTime.now(),
    );
  }

  static ProviderStageResult _skip(ProviderTestStage stage, String detail) =>
      ProviderStageResult(
        stage: stage,
        outcome: ProviderStageOutcome.skipped,
        detail: detail,
      );

  /// Runs [body] with a timeout, converting a throw into a failed stage whose
  /// message is useful rather than a stack trace.
  Future<ProviderStageResult> _timed(
    ProviderTestStage stage,
    Duration timeout,
    Future<(ProviderStageOutcome, String, int)> Function() body,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final (outcome, detail, count) = await body().timeout(timeout);
      stopwatch.stop();
      return ProviderStageResult(
        stage: stage,
        outcome: outcome,
        detail: detail,
        itemCount: count,
        elapsed: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return ProviderStageResult(
        stage: stage,
        outcome: ProviderStageOutcome.failed,
        detail: 'Timed out after ${timeout.inSeconds}s',
        elapsed: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      // Provider errors are frequently HTML or DNS noise; keep it short.
      final message = e.toString().replaceFirst('Exception: ', '');
      return ProviderStageResult(
        stage: stage,
        outcome: ProviderStageOutcome.failed,
        detail: message.length > 120
            ? '${message.substring(0, 120)}…'
            : message,
        elapsed: stopwatch.elapsed,
      );
    }
  }
}
