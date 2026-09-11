import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_tokens.dart';
import '../app_surface.dart';
import '../tv_focusable.dart';
import 'tv_setting_tile.dart';

class TvInterfaceSettingsSection extends StatelessWidget {
  const TvInterfaceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'TV & LEANBACK INTERFACE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvSettingSwitchTile(
                title: 'Android TV Mode',
                subtitle: 'Optimizes the interface for 10-foot viewing, D-pad remote navigation, direct playback, and TV player controls',
                icon: Icons.tv_rounded,
                value: app.isTvMode,
                onChanged: (val) => app.setTvMode(val),
              ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: tokens.borderSubtle,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.aspect_ratio_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UI Scale Density',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scales grid density, card sizes, and text layouts',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScaleChip(
                          context,
                          label: 'Compact (85%)',
                          scale: 0.85,
                          currentScale: app.uiScale,
                          onSelect: () => app.setUiScale(0.85),
                        ),
                        _buildScaleChip(
                          context,
                          label: 'Standard (100%)',
                          scale: 1.0,
                          currentScale: app.uiScale,
                          onSelect: () => app.setUiScale(1.0),
                        ),
                        _buildScaleChip(
                          context,
                          label: 'Comfortable (115%)',
                          scale: 1.15,
                          currentScale: app.uiScale,
                          onSelect: () => app.setUiScale(1.15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Parental Controls
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            'CONTENT & PARENTAL CONTROLS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: tokens.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: TvSettingSwitchTile(
            icon: Icons.shield_outlined,
            title: 'Filter Adult / 18+ Content',
            subtitle: 'Hide explicit, ecchi, and age-restricted titles from search results and feeds',
            value: app.filterAdultContent,
            onChanged: (val) => app.setFilterAdultContent(val),
          ),
        ),
      ],
    );
  }

  Widget _buildScaleChip(
    BuildContext context, {
    required String label,
    required double scale,
    required double currentScale,
    required VoidCallback onSelect,
  }) {
    final tokens = context.tokens;
    final isSelected = (currentScale - scale).abs() < 0.05;
    return TvFocusable(
      onTap: onSelect,
      borderRadius: tokens.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.primaryAccent.withValues(alpha: 0.25)
              : tokens.surfaceElevated,
          borderRadius: tokens.borderRadiusSm,
          border: Border.all(
            color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? tokens.primaryAccent : tokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
