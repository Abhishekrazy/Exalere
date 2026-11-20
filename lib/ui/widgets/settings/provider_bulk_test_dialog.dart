import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/exalere_plugin.dart';
import '../../theme/app_tokens.dart';
import '../tv/tv_popup_scope.dart';
import '../../../services/bulk_provider_test.dart';
import '../../../services/media_provider_plugin.dart';
import '../../../services/provider_diagnostics_service.dart';
import '../../../ui/widgets/tv_focusable.dart';

/// Runs the health check over **every installed add-on** and reports the verdict
/// per add-on, so a user can see which of their sources actually play without
/// opening each one.
class ProviderBulkTestDialog extends StatefulWidget {
  const ProviderBulkTestDialog({
    super.key,
    required this.providers,
    this.bulk = const BulkProviderTest(),
  });

  final List<MediaProviderPlugin> providers;

  /// Injected by tests; production uses the default (a real diagnostics run).
  final BulkProviderTest bulk;

  static Future<void> show(
    BuildContext context, {
    required List<MediaProviderPlugin> providers,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProviderBulkTestDialog(providers: providers),
    );
  }

  @override
  State<ProviderBulkTestDialog> createState() => _ProviderBulkTestDialogState();
}

class _ProviderBulkTestDialogState extends State<ProviderBulkTestDialog> {
  final List<BulkTestResult> _results = [];
  bool _running = true;
  BulkTestSummary? _summary;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final summary = await widget.bulk.run(
      widget.providers,
      onResult: (result) {
        if (!mounted) return;
        setState(() => _results.add(result));
      },
      isCancelled: () => _cancelled,
    );
    if (!mounted) return;
    setState(() {
      _running = false;
      _summary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final total = widget.providers.length;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
            margin: const EdgeInsets.all(20),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(
                color: tokens.borderSubtle,
                width: AppStroke.border,
              ),
              shadows: tokens.getCardShadows(),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        color: tokens.primaryAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add-on health',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _running
                            ? '${_results.length}/$total'
                            : (_summary?.headline ?? ''),
                        style: TextStyle(
                          color: _running
                              ? tokens.textSecondary
                              : (_summary?.allWorking ?? false
                                    ? tokens.liveColor
                                    : tokens.textSecondary),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final ok = result.outcome == ProviderHealth.working;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                ok
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                size: 18,
                                color: ok
                                    ? tokens.liveColor
                                    : tokens.errorColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result.providerName,
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      result.detail,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${result.elapsed.inSeconds}s',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_running) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      minHeight: 3,
                      color: theme.colorScheme.primary,
                      backgroundColor: tokens.surfaceCard,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TvFocusable(
                        autofocus: true,
                        onTap: () {
                          _cancelled = true;
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: theme.colorScheme.primary,
                          ),
                          child: Text(
                            _running ? 'Stop' : 'Close',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
      ),
    );
  }
}

/// Builds the plugins behind [configs], skipping any that cannot be created.
List<MediaProviderPlugin> bulkTestPlugins(
  List<ExalerePluginConfig> configs,
  MediaProviderPlugin Function(ExalerePluginConfig config) create,
) {
  final plugins = <MediaProviderPlugin>[];
  for (final config in configs) {
    try {
      plugins.add(create(config));
    } catch (_) {
      // A broken install must not stop the others from being tested.
    }
  }
  return plugins;
}
