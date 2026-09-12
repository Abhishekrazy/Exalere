import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv/tv_popup_scope.dart';
import '../../widgets/tv_focusable.dart';

class LiveTvCategoryDialog extends StatefulWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const LiveTvCategoryDialog({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<LiveTvCategoryDialog> createState() => _LiveTvCategoryDialogState();
}

class _LiveTvCategoryDialogState extends State<LiveTvCategoryDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filtered = [];
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.categories;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.categories;
      } else {
        _filtered = widget.categories
            .where((cat) => cat.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'all':
        return Icons.auto_awesome_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'entertainment':
        return Icons.theater_comedy_rounded;
      case 'movies':
        return Icons.movie_filter_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      case 'documentary':
        return Icons.menu_book_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'religious':
      case 'religion':
        return Icons.temple_hindu_rounded;
      case 'comedy':
        return Icons.mood_rounded;
      case 'lifestyle':
        return Icons.spa_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'weather':
        return Icons.cloud_rounded;
      case 'culture':
        return Icons.account_balance_rounded;
      case 'animation':
        return Icons.palette_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return TvPopupScope(
      child: Dialog(
        backgroundColor: tokens.surfaceElevated,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: tokens.borderRadiusLg,
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16 : 48,
          vertical: isCompact ? 24 : 36,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.category_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Select Live TV Category',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: tokens.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            // Search toggle button in header
                            TvFocusable(
                              scaleFactor: 1.1,
                              borderRadius: tokens.borderRadiusPill,
                              onTap: () {
                                setState(() => _isSearchOpen = !_isSearchOpen);
                                if (!_isSearchOpen) {
                                  _searchCtrl.clear();
                                  _onSearch('');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  _isSearchOpen
                                      ? Icons.search_off_rounded
                                      : Icons.search_rounded,
                                  color: _isSearchOpen
                                      ? theme.colorScheme.primary
                                      : tokens.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            TvFocusable(
                              scaleFactor: 1.1,
                              borderRadius: tokens.borderRadiusPill,
                              onTap: () => Navigator.of(context).pop(),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: tokens.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Filter channels by genre or broadcast category.',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                    // Animated search field
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _isSearchOpen
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: tokens.borderRadiusMd,
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            onChanged: _onSearch,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search categories…',
                              hintStyle: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: tokens.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: tokens.textSecondary,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        _onSearch('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      secondChild: const SizedBox(height: 10),
                    ),
                  ],
                ),
              ),
              // Categories list
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching categories found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: tokens.borderSubtle.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) {
                          final cat = _filtered[index];
                          final isSelected = cat == widget.selectedCategory;
                          final icon = _getCategoryIcon(cat);
                          return TvFocusable(
                            autofocus: isSelected,
                            scaleFactor: 1.03,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () {
                              widget.onCategorySelected(cat);
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      )
                                    : null,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      cat == 'All' ? 'All Categories' : cat,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : tokens.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 18,
                                    ),
                                  ],
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
      ),
    );
  }
}
