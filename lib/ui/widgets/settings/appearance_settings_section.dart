import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../theme/app_themes.dart';
import '../app_button.dart';
import '../app_surface.dart';
import '../tv_focusable.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tokens = context.tokens;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select App Theme (MovieBox-TUI presets)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(AppThemes.allThemes.length, (idx) {
              final t = AppThemes.allThemes[idx];
              final isSel = app.currentThemeIndex == idx;
              return TvFocusable(
                onTap: () => app.setThemeIndex(idx),
                borderRadius: tokens.borderRadiusSm,
                scaleFactor: 1.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.cardColor,
                    borderRadius: tokens.borderRadiusSm,
                    border: Border.all(
                      color: isSel ? t.primaryColor : tokens.borderSubtle,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 16),

          // Corner Geometry Section
          Text(
            'Corner Geometry Style',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Globally controls card, surface, and button corners across the application',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildCornerOption(
                context,
                label: 'Rounded',
                icon: Icons.rounded_corner_rounded,
                style: CornerStyle.rounded,
                isSelected: app.cornerStyle == CornerStyle.rounded,
                onTap: () => app.setCornerStyle(CornerStyle.rounded),
              ),
              const SizedBox(width: 8),
              _buildCornerOption(
                context,
                label: 'Sharp (90°)',
                icon: Icons.square_outlined,
                style: CornerStyle.sharp,
                isSelected: app.cornerStyle == CornerStyle.sharp,
                onTap: () => app.setCornerStyle(CornerStyle.sharp),
              ),
              const SizedBox(width: 8),
              _buildCornerOption(
                context,
                label: 'Cut (Bevel)',
                icon: Icons.hexagon_outlined,
                style: CornerStyle.cut,
                isSelected: app.cornerStyle == CornerStyle.cut,
                onTap: () => app.setCornerStyle(CornerStyle.cut),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: tokens.borderSubtle),
          const SizedBox(height: 16),

          // Surface Morphism Effect Section
          Text(
            'Card Surface Morphism Effect',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dynamic aesthetic effect applied to cards, modals, and interactive surfaces',
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMorphismOption(
                context,
                label: 'Classic Flat',
                icon: Icons.layers_outlined,
                morphism: SurfaceMorphism.standard,
                isSelected: app.surfaceMorphism == SurfaceMorphism.standard,
                onTap: () => app.setSurfaceMorphism(SurfaceMorphism.standard),
              ),
              _buildMorphismOption(
                context,
                label: 'Apple Glass',
                icon: Icons.blur_on_rounded,
                morphism: SurfaceMorphism.glass,
                isSelected: app.surfaceMorphism == SurfaceMorphism.glass,
                onTap: () => app.setSurfaceMorphism(SurfaceMorphism.glass),
              ),
              _buildMorphismOption(
                context,
                label: 'Neomorphic',
                icon: Icons.contrast_rounded,
                morphism: SurfaceMorphism.neomorphic,
                isSelected: app.surfaceMorphism == SurfaceMorphism.neomorphic,
                onTap: () => app.setSurfaceMorphism(SurfaceMorphism.neomorphic),
              ),
              _buildMorphismOption(
                context,
                label: '3D Clay',
                icon: Icons.bubble_chart_rounded,
                morphism: SurfaceMorphism.clay,
                isSelected: app.surfaceMorphism == SurfaceMorphism.clay,
                onTap: () => app.setSurfaceMorphism(SurfaceMorphism.clay),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Live Interactive Component Preview
          AppSurface(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: tokens.primaryAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Component Preview',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${app.surfaceMorphism.name.toUpperCase()} Surface • ${app.cornerStyle.name.toUpperCase()} Corners',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton.primary(
                  label: 'Action',
                  size: AppButtonSize.sm,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required CornerStyle style,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final borderSide = BorderSide(
      color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
      width: isSelected ? 1.5 : 1.0,
    );

    return Expanded(
      child: TvFocusable(
        onTap: onTap,
        borderRadius: style == CornerStyle.sharp
            ? BorderRadius.zero
            : BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: ShapeDecoration(
            color: isSelected
                ? tokens.primaryAccent.withValues(alpha: 0.2)
                : tokens.surfaceElevated,
            shape: style == CornerStyle.sharp
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: borderSide,
                  )
                : (style == CornerStyle.cut
                      ? BeveledRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: borderSide,
                        )
                      : RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: borderSide,
                        )),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? tokens.primaryAccent : tokens.textSecondary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? tokens.primaryAccent : tokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMorphismOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required SurfaceMorphism morphism,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final tokens = context.tokens;
    final borderSide = BorderSide(
      color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
      width: isSelected ? 1.5 : 1.0,
    );
    return TvFocusable(
      onTap: onTap,
      borderRadius: tokens.borderRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: tokens.getShapeDecoration(
          color: isSelected
              ? tokens.primaryAccent.withValues(alpha: 0.2)
              : tokens.surfaceElevated,
          side: borderSide,
          radius: tokens.borderRadiusSm.topLeft.x,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? tokens.primaryAccent : tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? tokens.primaryAccent : tokens.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
