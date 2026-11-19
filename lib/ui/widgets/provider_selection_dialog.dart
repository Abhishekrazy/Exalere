import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/plugin_provider.dart';
import '../../services/provider_registry.dart';
import '../theme/app_tokens.dart';
import 'tv/tv_popup_scope.dart';
import 'tv_focusable.dart';

class _ProviderOptionItem {
  final String id;
  final String title;
  final String description;
  final String badge;
  final IconData icon;

  const _ProviderOptionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.icon,
  });
}

/// Dialog allowing user to select their active discovery & catalog provider.
/// Defaults to TMDB on first install as the official metadata and discovery catalog.
class ProviderSelectionDialog extends StatefulWidget {
  final bool isFromSettings;

  const ProviderSelectionDialog({super.key, this.isFromSettings = false});

  static Future<void> show(
    BuildContext context, {
    bool isFromSettings = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: isFromSettings,
      builder: (ctx) => ProviderSelectionDialog(isFromSettings: isFromSettings),
    );
  }

  @override
  State<ProviderSelectionDialog> createState() =>
      _ProviderSelectionDialogState();
}

class _ProviderSelectionDialogState extends State<ProviderSelectionDialog> {
  late String _selectedProviderId;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    _selectedProviderId = app.selectedCatalogProvider;
  }

  List<_ProviderOptionItem> _buildOptions() {
    final pluginProvider = context.read<PluginProvider?>();
    final installedPlugins = pluginProvider?.plugins ?? [];

    final list = <_ProviderOptionItem>[
      const _ProviderOptionItem(
        id: 'tmdb',
        title: 'TMDB (The Movie Database)',
        description:
            'Comprehensive global catalog, official trailers, ratings, and trending charts.',
        badge: 'Recommended • Official',
        icon: Icons.movie_filter_rounded,
      ),
    ];
    // The seeded TMDB plugin resolves to the same provider id as the built-in
    // catalog above; listing it again rendered two rows that both looked
    // selected. One row per provider id, built-in entries win.
    final seenIds = <String>{for (final item in list) item.id};

    for (final p in installedPlugins) {
      if (!p.isEnabled) continue;
      if (!seenIds.add(p.id)) continue;
      final engine = ProviderRegistry().getProvider(p.id);
      final supportsFeeds = engine?.supportsCatalogFeeds ?? false;

      list.add(
        _ProviderOptionItem(
          id: p.id,
          title: p.name,
          description: supportsFeeds
              ? 'Real-time catalog feeds and direct playable streams.'
              : 'Direct playable stream resolver for titles.',
          badge: supportsFeeds ? 'Feeds + Streams' : 'Streams Only',
          icon: Icons.extension_rounded,
        ),
      );
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 540 || size.height < 600;
    final options = _buildOptions();

    return TvPopupScope(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (size.width * 0.85).clamp(340.0, 620.0),
              maxHeight: (size.height * 0.85).clamp(380.0, 680.0),
            ),
            margin: const EdgeInsets.all(20),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 20 : 28,
              vertical: isCompact ? 18 : 24,
            ),
            decoration: tokens.getShapeDecoration(
              color: tokens.surfaceElevated,
              radius: tokens.cardRadius,
              side: BorderSide(
                color: tokens.borderSubtle,
                width: AppStroke.border,
              ),
              shadows: tokens.getCardShadows(),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.15),
                        radius: tokens.cardRadius * 0.7,
                      ),
                      child: Icon(
                        Icons.hub_rounded,
                        color: tokens.primaryAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Content Provider',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: isCompact ? 17 : 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose which catalog powers Home, Movies, and Series discovery.',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: isCompact ? 12 : 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 14 : 18),

                // Options grid: two compact columns keep every provider on
                // screen at once instead of a long single-file list.
                Flexible(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      const gap = 10.0;
                      final columnWidth = (constraints.maxWidth - gap) / 2;
                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final item in options)
                              SizedBox(
                                width: columnWidth,
                                child: _ProviderOptionCard(
                                  item: item,
                                  selected: item.id == _selectedProviderId,
                                  isCompact: isCompact,
                                  onTap: () => setState(
                                    () => _selectedProviderId = item.id,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: isCompact ? 14 : 18),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.isFromSettings) ...[
                      TvFocusable(
                        borderRadius: tokens.borderRadiusPill,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: tokens.getShapeDecoration(
                            color: tokens.surfaceCard,
                            radius: 999.0,
                            side: BorderSide(
                              color: tokens.borderSubtle,
                              width: AppStroke.border,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    TvFocusable(
                      autofocus: true,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final app = context.read<AppProvider>();
                        await app.setSelectedCatalogProvider(
                          _selectedProviderId,
                        );
                        await app.setHasPromptedProviderSelection(true);
                        if (mounted) {
                          navigator.pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.primaryAccent,
                          radius: 999.0,
                          shadows: [
                            BoxShadow(
                              color: tokens.primaryAccent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'Confirm Selection',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
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

/// Compact selectable provider card for the two-column grid.
class _ProviderOptionCard extends StatelessWidget {
  const _ProviderOptionCard({
    required this.item,
    required this.selected,
    required this.isCompact,
    required this.onTap,
  });

  final _ProviderOptionItem item;
  final bool selected;
  final bool isCompact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return TvFocusable(
      scaleFactor: 1.03,
      shape: tokens.shapeSm,
      borderRadius: tokens.borderRadiusSm,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 11 : 13,
          vertical: isCompact ? 10 : 12,
        ),
        decoration: tokens.getShapeDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: 0.14)
              : tokens.surfaceCard.withValues(alpha: 0.6),
          radius: tokens.cardRadius * 0.6,
          side: BorderSide(
            color: selected ? tokens.primaryAccent : tokens.borderSubtle,
            width: selected ? AppStroke.focus : AppStroke.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? tokens.primaryAccent : tokens.textMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Icon(
                  item.icon,
                  color: selected ? tokens.primaryAccent : tokens.textSecondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: isCompact ? 12.5 : 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: isCompact ? 10.5 : 11.5,
                height: 1.3,
              ),
            ),
            if (item.badge.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: tokens.getShapeDecoration(
                  color: selected
                      ? tokens.primaryAccent.withValues(alpha: 0.2)
                      : tokens.surfaceElevated,
                  radius: 8,
                  side: BorderSide(
                    color: selected
                        ? tokens.primaryAccent
                        : tokens.borderSubtle,
                    width: AppStroke.border,
                  ),
                  shadows: const [],
                ),
                child: Text(
                  item.badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? tokens.primaryAccent
                        : tokens.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
