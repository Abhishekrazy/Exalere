import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/app_logger.dart';
import '../../theme/app_tokens.dart';
import '../tv/tv_popup_scope.dart';
import '../tv_focusable.dart';

/// Logging preferences: how much is recorded, and a way to read what was.
///
/// The log exists so a user can answer "why did that fail?" without a cable and
/// a debug build — so the level is adjustable and the buffer is viewable and
/// copyable.
class LoggingSettingsDialog extends StatefulWidget {
  const LoggingSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LoggingSettingsDialog(),
    );
  }

  @override
  State<LoggingSettingsDialog> createState() => _LoggingSettingsDialogState();
}

class _LoggingSettingsDialogState extends State<LoggingSettingsDialog> {
  @override
  void initState() {
    super.initState();
    // Surface the current buffer size immediately.
    AppLogger.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    AppLogger.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final logger = AppLogger.instance;

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
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
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Logging',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${logger.count} line${logger.count == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Recording detail for troubleshooting. Higher levels record '
                  'more, which uses more memory while the app runs.',
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                for (final level in LogLevel.values) ...[
                  _LevelRow(
                    level: level,
                    selected: logger.level == level,
                    onTap: () => logger.setLevel(level),
                  ),
                  if (level != LogLevel.values.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TvFocusable(
                        borderRadius: tokens.borderRadiusSm,
                        onTap: logger.hasEntries
                            ? () => LogViewerDialog.show(context)
                            : null,
                        child: Opacity(
                          opacity: logger.hasEntries ? 1 : 0.45,
                          child: _button(
                            tokens,
                            label: 'View Log',
                            icon: Icons.article_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      borderRadius: tokens.borderRadiusSm,
                      onTap: logger.hasEntries ? logger.clear : null,
                      child: Opacity(
                        opacity: logger.hasEntries ? 1 : 0.45,
                        child: _button(
                          tokens,
                          label: 'Clear',
                          icon: Icons.delete_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Exactly one autofocus: the safe dismiss action.
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: () => Navigator.of(context).pop(),
                      child: _button(
                        tokens,
                        label: 'Done',
                        icon: Icons.check_rounded,
                        emphasized: true,
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

  Widget _button(
    AppTokens tokens, {
    required String label,
    required IconData icon,
    bool emphasized = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized ? tokens.primaryAccent : tokens.surfaceCard,
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(
          color: emphasized ? tokens.borderFocus : tokens.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasized ? tokens.canvasBackground : tokens.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: emphasized ? tokens.canvasBackground : tokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final LogLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvFocusable(
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: 0.14)
              : tokens.surfaceCard,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(
            color: selected ? tokens.borderFocus : tokens.borderSubtle,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? tokens.primaryAccent : tokens.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                  Text(
                    level.description,
                    style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only view of the captured log, with copy and clear.
class LogViewerDialog extends StatefulWidget {
  const LogViewerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LogViewerDialog(),
    );
  }

  @override
  State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
  String? _toast;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Newest first is what a user wants when something just failed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final text = AppLogger.instance.exportText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _toast = 'Copied ${AppLogger.instance.count} lines');
  }

  Color _colorFor(LogLevel level, AppTokens tokens) {
    switch (level) {
      case LogLevel.error:
        return tokens.errorColor;
      case LogLevel.warn:
        return tokens.vipColor;
      case LogLevel.debug:
        return tokens.textMuted;
      case LogLevel.info:
      case LogLevel.off:
        return tokens.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final entries = AppLogger.instance.entries.reversed.toList();

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(18),
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
                      Icons.article_outlined,
                      size: 20,
                      color: tokens.primaryAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Log (${entries.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_toast != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _toast!,
                    style: TextStyle(fontSize: 11.5, color: tokens.liveColor),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: entries.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing recorded yet.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.textMuted,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: tokens.canvasBackground,
                            borderRadius: tokens.borderRadiusSm,
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: ListView.builder(
                            controller: _scroll,
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(10),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  entry.formatted,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.35,
                                    fontFamily: 'monospace',
                                    color: _colorFor(entry.level, tokens),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TvFocusable(
                      borderRadius: tokens.borderRadiusSm,
                      onTap: _copy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Text(
                          'Copy All',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Exactly one autofocus: the safe dismiss action.
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusSm,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent,
                          borderRadius: tokens.borderRadiusSm,
                          border: Border.all(color: tokens.borderFocus),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 12.5,
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

/// Small settings row that opens [LoggingSettingsDialog].
class LoggingSettingsTile extends StatelessWidget {
  const LoggingSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final logger = AppLogger.instance;

    return TvFocusable(
      borderRadius: tokens.borderRadiusSm,
      onTap: () => LoggingSettingsDialog.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surfaceElevated.withValues(alpha: 0.4),
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(color: tokens.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              color: tokens.textPrimary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logging',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Troubleshooting detail: level, view captured log, clear',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              logger.level.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
