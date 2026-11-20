import '../../../services/provider_diagnostics_service.dart';

/// Turns a stored verdict into the short label the add-on list shows.
///
/// The store already persists every Test/Test-all result (`PluginProvider`
/// keeps a [ProviderHealth] and the last report per id) but nothing displayed
/// them, so a user had to re-run the check to remember which add-on worked.
/// Pure text so it is tested without a widget tree; colour stays in the widget,
/// where the theme tokens live.
class PluginHealth {
  const PluginHealth._();

  static String label(ProviderHealth health, ProviderTestReport? report) {
    switch (health) {
      case ProviderHealth.working:
        final streams = report?.stageOf(ProviderTestStage.streams)?.detail;
        return streams == null || streams.isEmpty
            ? 'Working'
            : 'Working · $streams';
      case ProviderHealth.failed:
        final reason = report?.summary;
        return reason == null || reason.isEmpty ? 'Failed' : 'Failed · $reason';
      case ProviderHealth.testing:
        return 'Testing…';
      case ProviderHealth.untested:
        return 'Not tested';
    }
  }

  /// Whether the label deserves a badge at all: an untested add-on should not
  /// spend a chip saying so, but one being tested should.
  static bool isBadgeWorthy(ProviderHealth health) =>
      health != ProviderHealth.untested;

  /// Compact form for a two-column TV row, where only a few words fit.
  static String shortLabel(ProviderHealth health, ProviderTestReport? report) {
    switch (health) {
      case ProviderHealth.working:
        return 'Working';
      case ProviderHealth.failed:
        return 'Failed';
      case ProviderHealth.testing:
        return 'Testing…';
      case ProviderHealth.untested:
        return 'Not tested';
    }
  }
}
