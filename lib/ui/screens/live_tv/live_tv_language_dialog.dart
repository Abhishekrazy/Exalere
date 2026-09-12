import 'package:flutter/material.dart';

import '../../../services/iptv_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

class LiveTvLanguageDialog extends StatefulWidget {
  final Set<String> selectedLanguages;
  final ValueChanged<Set<String>> onLanguagesSelected;

  const LiveTvLanguageDialog({
    super.key,
    required this.selectedLanguages,
    required this.onLanguagesSelected,
  });

  @override
  State<LiveTvLanguageDialog> createState() => _LiveTvLanguageDialogState();
}

class _LiveTvLanguageDialogState extends State<LiveTvLanguageDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<IptvLanguage> _filtered = [];
  late Set<String> _pending;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _filtered = IptvProvider.popularLanguages;
    _pending = Set<String>.from(widget.selectedLanguages);
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
        _filtered = IptvProvider.popularLanguages;
      } else {
        _filtered = IptvProvider.popularLanguages.where((l) {
          return l.name.toLowerCase().contains(q) ||
              l.nativeName.toLowerCase().contains(q) ||
              l.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  void _toggle(String code) {
    setState(() {
      if (code == 'ALL') {
        _pending = {'ALL'};
      } else {
        _pending.remove('ALL');
        if (_pending.contains(code)) {
          _pending.remove(code);
          if (_pending.isEmpty) _pending = {'ALL'};
        } else {
          _pending.add(code);
        }
      }
    });
  }

  void _apply() {
    widget.onLanguagesSelected(Set<String>.from(_pending));
    Navigator.of(context).pop();
  }

  void _clear() {
    setState(() => _pending = {'ALL'});
  }

  bool get _isFiltered => !_pending.contains('ALL') && _pending.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isAllSelected = _pending.contains('ALL') || _pending.isEmpty;

    return Center(
      child: Material(
        color: tokens.canvasBackground.withValues(alpha: 0),
        child: Container(
          width: 500,
          height: 600,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: tokens.getShapeDecoration(
            color: tokens.surfaceElevated,
            radius: tokens.cardRadius * 1.2,
            side: BorderSide(
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            shadows: tokens.getCardShadows(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.15,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.translate_rounded,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Languages',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        Text(
                          'Pick one or more broadcast languages.',
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TvFocusable(
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
                            ? theme.colorScheme.secondary
                            : tokens.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TvFocusable(
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
              // Animated search field
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isSearchOpen
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
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
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search languages…',
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
                secondChild: const SizedBox(height: 8),
              ),
              // "All Languages" row
              TvFocusable(
                autofocus: isAllSelected,
                scaleFactor: 1.03,
                borderRadius: tokens.borderRadiusSm,
                onTap: () => _toggle('ALL'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isAllSelected
                        ? theme.colorScheme.secondary.withValues(alpha: 0.12)
                        : null,
                    borderRadius: tokens.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 20,
                        color: isAllSelected
                            ? theme.colorScheme.secondary
                            : tokens.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All Languages',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isAllSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isAllSelected
                                ? theme.colorScheme.secondary
                                : tokens.textPrimary,
                          ),
                        ),
                      ),
                      _CheckBox(
                        checked: isAllSelected,
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 8,
                color: tokens.borderSubtle.withValues(alpha: 0.5),
              ),
              // Language list
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching languages found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        clipBehavior: Clip.antiAlias,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: tokens.borderSubtle.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (context, index) {
                          final l = _filtered[index];
                          final isChecked = _pending.contains(
                            l.code.toUpperCase(),
                          );
                          return TvFocusable(
                            scaleFactor: 1.03,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () => _toggle(l.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? theme.colorScheme.secondary.withValues(
                                        alpha: 0.1,
                                      )
                                    : null,
                                borderRadius: tokens.borderRadiusSm,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.translate_rounded,
                                    size: 18,
                                    color: isChecked
                                        ? theme.colorScheme.secondary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isChecked
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isChecked
                                                ? theme.colorScheme.secondary
                                                : tokens.textPrimary,
                                          ),
                                        ),
                                        if (l.nativeName != l.name) ...[
                                          Text(
                                            l.nativeName,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: tokens.textMuted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.surfaceCard,
                                      borderRadius: tokens.borderRadiusXs,
                                      border: Border.all(
                                        color: tokens.borderSubtle,
                                      ),
                                    ),
                                    child: Text(
                                      l.code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tokens.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _CheckBox(
                                    checked: isChecked,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Footer: Clear + Apply
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_isFiltered) ...[
                    TvFocusable(
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _clear,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceCard,
                          borderRadius: tokens.borderRadiusPill,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear_all_rounded,
                              size: 16,
                              color: tokens.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TvFocusable(
                      autofocus: !isAllSelected,
                      borderRadius: tokens.borderRadiusPill,
                      onTap: _apply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: tokens.borderRadiusPill,
                        ),
                        child: Center(
                          child: Text(
                            _isFiltered
                                ? 'Apply (${_pending.length} selected)'
                                : 'Apply',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondary,
                            ),
                          ),
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
    );
  }
}

/// Lightweight checkbox indicator for multi-select language rows.
class _CheckBox extends StatelessWidget {
  final bool checked;
  final Color color;

  const _CheckBox({required this.checked, required this.color});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? color : tokens.surfaceCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: checked ? color : tokens.borderSubtle,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(
              Icons.check_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.onSecondary,
            )
          : null,
    );
  }
}
