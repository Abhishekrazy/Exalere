import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/app_feature.dart';
import '../theme/app_tokens.dart';
import '../widgets/tv_focusable.dart';

/// Full-screen or modal dialog showcasing all built-in features and capabilities in Exalere.
class FeaturesShowcaseDialog extends StatefulWidget {
  const FeaturesShowcaseDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: context.tokens.shadowColor.withValues(alpha: 0.8),
      builder: (context) => const FeaturesShowcaseDialog(),
    );
  }

  @override
  State<FeaturesShowcaseDialog> createState() => _FeaturesShowcaseDialogState();
}

class _FeaturesShowcaseDialogState extends State<FeaturesShowcaseDialog> {
  FeatureCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppFeature> get _filteredFeatures {
    var list = AppFeaturesCatalog.allFeatures;
    if (_selectedCategory != null) {
      list = list.where((f) => f.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (f) =>
                f.title.toLowerCase().contains(q) ||
                f.description.toLowerCase().contains(q) ||
                f.category.label.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final size = MediaQuery.of(context).size;
    final totalFeatures = AppFeaturesCatalog.totalCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 800,
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
          decoration: tokens.getShapeDecoration(
            color: tokens.canvasBackground.withValues(alpha: 0.94),
            radius: tokens.cardRadius * 1.5,
            side: BorderSide(
              color: tokens.borderSubtle.withValues(alpha: 0.8),
              width: 1.2,
            ),
            shadows: [
              BoxShadow(
                color: tokens.shadowColor.withValues(alpha: 0.65),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: tokens.getShapeDecoration(
                        color: tokens.primaryAccent.withValues(alpha: 0.16),
                        radius: tokens.cardRadius,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: tokens.primaryAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Features & Capabilities',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: tokens.getShapeDecoration(
                                  color: tokens.primaryAccent.withValues(
                                    alpha: 0.22,
                                  ),
                                  radius: tokens.cardRadius,
                                  side: BorderSide(
                                    color: tokens.primaryAccent.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '$totalFeatures Built-in',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: tokens.primaryAccent,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Explore everything Exalere has to offer across Mobile, TV & Desktop',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TvFocusable(
                      autofocus: false,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceElevated,
                          radius: tokens.cardRadius,
                          side: BorderSide(color: tokens.borderSubtle),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 2. Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: tokens.getShapeDecoration(
                          color: tokens.surfaceElevated,
                          radius: tokens.cardRadius,
                          side: BorderSide(color: tokens.borderSubtle),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: tokens.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                style: TextStyle(
                                  color: tokens.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search among $totalFeatures features...',
                                  hintStyle: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Icon(
                                  Icons.cancel_rounded,
                                  color: tokens.textMuted,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Category Horizontal Pills
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  clipBehavior: Clip.none,
                  children: [
                    _buildCategoryChip(
                      label: 'All Features ($totalFeatures)',
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                      icon: Icons.apps_rounded,
                    ),
                    const SizedBox(width: 8),
                    ...FeatureCategory.values.map((cat) {
                      final count = AppFeaturesCatalog.getBy(cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategoryChip(
                          label: '${cat.label} ($count)',
                          isSelected: _selectedCategory == cat,
                          onTap: () => setState(() => _selectedCategory = cat),
                          icon: cat.icon,
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. Features List
              Expanded(
                child: _filteredFeatures.isEmpty
                    ? Center(
                        child: Text(
                          'No features found matching "$_searchQuery"',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 20),
                        itemCount: _filteredFeatures.length,
                        itemBuilder: (context, index) {
                          final f = _filteredFeatures[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TvFocusable(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: tokens.getShapeDecoration(
                                  color: tokens.surfaceCard,
                                  radius: tokens.cardRadius,
                                  side: BorderSide(
                                    color: tokens.borderSubtle.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: tokens.getShapeDecoration(
                                        color: tokens.surfaceElevated,
                                        radius: tokens.cardRadius,
                                        side: BorderSide(
                                          color: tokens.borderSubtle,
                                        ),
                                      ),
                                      child: Icon(
                                        f.icon,
                                        color: f.isHighlight
                                            ? tokens.primaryAccent
                                            : tokens.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  f.title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: tokens.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (f.isNew) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: tokens
                                                      .getShapeDecoration(
                                                        color: tokens.liveColor
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        radius:
                                                            tokens.cardRadius,
                                                        side: BorderSide(
                                                          color:
                                                              tokens.liveColor,
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                  child: Text(
                                                    'NEW',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: tokens.liveColor,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (f.isHighlight &&
                                                  !f.isNew) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: tokens
                                                      .getShapeDecoration(
                                                        color: tokens.vipColor
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                        radius:
                                                            tokens.cardRadius,
                                                        side: BorderSide(
                                                          color:
                                                              tokens.vipColor,
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                  child: Text(
                                                    'FEATURED',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: tokens.vipColor,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            f.description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: tokens.textSecondary,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final tokens = context.tokens;

    return TvFocusable(
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: tokens.getShapeDecoration(
            color: isSelected
                ? tokens.primaryAccent.withValues(alpha: 0.22)
                : tokens.surfaceElevated,
            radius: tokens.cardRadius * 1.5,
            side: BorderSide(
              color: isSelected ? tokens.primaryAccent : tokens.borderSubtle,
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? tokens.primaryAccent : tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
