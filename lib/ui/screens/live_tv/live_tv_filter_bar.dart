import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

class LiveTvFilterBar extends StatelessWidget {
  final String selectedCountry;
  final String countryDisplayName;
  final Set<String> selectedLanguages;
  final String languageDisplayName;
  final String selectedCategory;
  final bool isSearchVisible;
  final bool hasSearchQuery;
  final VoidCallback onCountryTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onSearchToggle;

  const LiveTvFilterBar({
    super.key,
    required this.selectedCountry,
    required this.countryDisplayName,
    required this.selectedLanguages,
    required this.languageDisplayName,
    required this.selectedCategory,
    required this.isSearchVisible,
    required this.hasSearchQuery,
    required this.onCountryTap,
    required this.onLanguageTap,
    required this.onCategoryTap,
    required this.onSearchToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            // Country Filter Icon Button
            _buildFilterIconButton(
              context: context,
              icon: Icons.public_rounded,
              tooltip: 'Country: $countryDisplayName',
              isActive: selectedCountry != 'ALL',
              activeColor: theme.colorScheme.primary,
              onTap: onCountryTap,
            ),
            const SizedBox(width: 8),

            // Language Filter Icon Button
            _buildFilterIconButton(
              context: context,
              icon: Icons.translate_rounded,
              tooltip: 'Languages: $languageDisplayName',
              isActive:
                  !selectedLanguages.contains('ALL') &&
                  selectedLanguages.isNotEmpty,
              activeColor: theme.colorScheme.secondary,
              onTap: onLanguageTap,
            ),
            const SizedBox(width: 8),

            // Category Filter Icon Button
            _buildFilterIconButton(
              context: context,
              icon: Icons.category_rounded,
              tooltip:
                  'Category: ${selectedCategory == 'All' ? 'All Categories' : selectedCategory}',
              isActive: selectedCategory != 'All',
              activeColor: theme.colorScheme.primary,
              onTap: onCategoryTap,
            ),
            const SizedBox(width: 8),

            // Search Toggle Icon Button
            _buildFilterIconButton(
              context: context,
              icon: isSearchVisible
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              tooltip: isSearchVisible ? 'Close search' : 'Search channels',
              isActive: isSearchVisible || hasSearchQuery,
              activeColor: theme.colorScheme.primary,
              onTap: onSearchToggle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isActive,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final effActiveColor = activeColor ?? theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: TvFocusable(
        scaleFactor: 1.12,
        borderRadius: tokens.borderRadiusPill,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive
                ? effActiveColor.withValues(alpha: 0.16)
                : tokens.surfaceElevated,
            borderRadius: tokens.borderRadiusPill,
            border: Border.all(
              color: isActive
                  ? effActiveColor.withValues(alpha: 0.8)
                  : tokens.borderSubtle,
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: effActiveColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? effActiveColor : tokens.textSecondary,
              ),
              if (isActive)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: effActiveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
