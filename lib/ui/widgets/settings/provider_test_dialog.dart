import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/plugin_provider.dart';
import '../../../services/provider_diagnostics_service.dart';
import '../../theme/app_tokens.dart';
import '../tv/tv_popup_scope.dart';
import '../tv_focusable.dart';

/// Runs a provider health check and shows each stage as it settles.
///
/// This is the answer to "I installed a provider and still see nothing": it
/// separates "cannot list anything" from "lists titles but has no stream", which
/// are different problems with different fixes.
class ProviderTestDialog extends StatefulWidget {
  const ProviderTestDialog({
    super.key,
    required this.providerId,
    required this.providerName,
  });

  final String providerId;
  final String providerName;

  static Future<ProviderTestReport?> show(
    BuildContext context, {
    required String providerId,
    required String providerName,
  }) {
    return showDialog<ProviderTestReport>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProviderTestDialog(
        providerId: providerId,
        providerName: providerName,
      ),
    );
  }

  @override
  State<ProviderTestDialog> createState() => _ProviderTestDialogState();
}

class _ProviderTestDialogState extends State<ProviderTestDialog> {
  final Map<ProviderTestStage, ProviderStageResult> _results = {};
  ProviderTestReport? _report;
  bool _isRunning = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final provider = context.read<PluginProvider>();
    final report = await provider.runProviderTest(
      widget.providerId,
      onStage: (result) {
        if (!mounted) return;
        setState(() => _results[result.stage] = result);
      },
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final report = _report;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(color: tokens.borderSubtle, width: 1.5),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.science_rounded,
                      size: 22,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Testing ${widget.providerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Checking this provider the same way the app uses it: list, '
                  'search, look up, then resolve a stream.',
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final stage in ProviderTestStage.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StageRow(
                      stage: stage,
                      result: _results[stage],
                      pending: _results[stage] == null && _isRunning,
                    ),
                  ),
                if (report != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: report.health == ProviderHealth.working
                          ? tokens.liveColor.withValues(alpha: 0.14)
                          : tokens.errorColor.withValues(alpha: 0.14),
                      borderRadius: tokens.borderRadiusSm,
                      border: Border.all(
                        color: report.health == ProviderHealth.working
                            ? tokens.liveColor.withValues(alpha: 0.4)
                            : tokens.errorColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      report.health == ProviderHealth.working
                          ? 'Working — ${report.summary}'
                          : 'Not working — ${report.summary}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isRunning)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: tokens.primaryAccent,
                          ),
                        ),
                      ),
                    // Exactly one autofocus, and it is always available: a dialog
                    // with no focused element leaves a D-Pad user unable to act.
                    // Dismissing mid-run is safe — the run continues in the
                    // provider and still records its verdict.
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: () => Navigator.of(context).pop(_report),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderFocus),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: tokens.canvasBackground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.stage,
    required this.result,
    required this.pending,
  });

  final ProviderTestStage stage;
  final ProviderStageResult? result;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final outcome = result?.outcome;

    final IconData icon;
    final Color color;
    if (outcome == ProviderStageOutcome.passed) {
      icon = Icons.check_circle_rounded;
      color = tokens.liveColor;
    } else if (outcome == ProviderStageOutcome.failed) {
      icon = Icons.cancel_rounded;
      color = tokens.errorColor;
    } else if (outcome == ProviderStageOutcome.skipped) {
      icon = Icons.remove_circle_outline_rounded;
      color = tokens.textMuted;
    } else if (pending) {
      icon = Icons.hourglass_empty_rounded;
      color = tokens.textMuted;
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      color = tokens.textMuted;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        SizedBox(
          width: 74,
          child: Text(
            stage.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            result?.detail ?? (pending ? 'Waiting…' : '—'),
            style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}
