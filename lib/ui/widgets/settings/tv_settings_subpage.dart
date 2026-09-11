import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../tv_focusable.dart';

class TvSettingChoice<T> {
  final String label;
  final String? description;
  final T value;
  final IconData? icon;
  final bool closeOnSelect;
  final VoidCallback? onTap;

  const TvSettingChoice({
    required this.label,
    this.description,
    required this.value,
    this.icon,
    this.closeOnSelect = true,
    this.onTap,
  });
}

/// A dedicated 10-foot subpage for an individual setting on Android TV.
/// Shows the setting title, description, and vertically stacked options (e.g. Yes/No or Choice list).
/// Supports multi-level nesting ("page within page within page") and handles TV back keys.
class TvSettingsSubpage<T> extends StatelessWidget {
  final String title;
  final String? description;
  final List<TvSettingChoice<T>> choices;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final VoidCallback onBack;
  final void Function(Widget nextSubpage, [FocusNode? callerFocusNode])?
  onPushSubpage;

  const TvSettingsSubpage({
    super.key,
    required this.title,
    this.description,
    required this.choices,
    required this.selectedValue,
    required this.onSelected,
    required this.onBack,
    this.onPushSubpage,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.browserBack) {
            onBack();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            // From a subpage, Left arrow acts like Back to return to settings home page
            onBack();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            onBack();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Breadcrumb / Back Button
            Row(
              children: [
                TvFocusable(
                  onTap: onBack,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                            event.logicalKey == LogicalKeyboardKey.goBack ||
                            event.logicalKey == LogicalKeyboardKey.escape ||
                            event.logicalKey == LogicalKeyboardKey.backspace ||
                            event.logicalKey ==
                                LogicalKeyboardKey.browserBack)) {
                      onBack();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  scaleFactor: 1.08,
                  shape: tokens.shapePill,
                  borderRadius: tokens.borderRadiusPill,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: tokens.getShapeDecoration(
                      color: tokens.surfaceElevated.withValues(alpha: 0.6),
                      radius: tokens.cornerStyle == CornerStyle.sharp
                          ? 0.0
                          : 20.0,
                      side: BorderSide(color: tokens.borderSubtle, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Vertically Stacked Options (Up-Down D-Pad Navigation)
            Expanded(
              child: ListView.separated(
                itemCount: choices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  final isSelected = choice.value == selectedValue;

                  return TvFocusable(
                    autofocus:
                        isSelected ||
                        (index == 0 &&
                            !choices.any((c) => c.value == selectedValue)),
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                              event.logicalKey == LogicalKeyboardKey.goBack ||
                              event.logicalKey == LogicalKeyboardKey.escape ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.backspace ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.browserBack)) {
                        onBack();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    scaleFactor: 1.02,
                    shape: tokens.shapeSm,
                    borderRadius: tokens.borderRadiusSm,
                    onTap: () {
                      if (choice.onTap != null) {
                        choice.onTap!();
                      } else {
                        onSelected(choice.value);
                      }
                      if (choice.closeOnSelect) {
                        onBack();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: tokens.getShapeDecoration(
                        color: isSelected
                            ? tokens.primaryAccent.withValues(alpha: 0.12)
                            : tokens.surfaceElevated.withValues(alpha: 0.45),
                        radius: (tokens.cardRadius * 0.65).clamp(4.0, 10.0),
                        side: BorderSide(
                          color: isSelected
                              ? tokens.primaryAccent.withValues(alpha: 0.6)
                              : tokens.borderSubtle,
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? tokens.primaryAccent
                                : tokens.textMuted,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          if (choice.icon != null) ...[
                            Icon(
                              choice.icon,
                              color: isSelected
                                  ? tokens.primaryAccent
                                  : tokens.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  choice.label,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.bold,
                                    color: isSelected
                                        ? tokens.primaryAccent
                                        : tokens.textPrimary,
                                  ),
                                ),
                                if (choice.description != null &&
                                    choice.description!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    choice.description!,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              color: tokens.primaryAccent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
