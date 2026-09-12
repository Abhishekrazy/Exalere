import 'package:flutter/material.dart';

import '../../../services/iptv_provider.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

class LiveTvCountryDialog extends StatefulWidget {
  final String selectedCountry;
  final IptvProvider iptvProvider;
  final ValueChanged<String> onCountrySelected;

  const LiveTvCountryDialog({
    super.key,
    required this.selectedCountry,
    required this.iptvProvider,
    required this.onCountrySelected,
  });

  @override
  State<LiveTvCountryDialog> createState() => _LiveTvCountryDialogState();
}

class _LiveTvCountryDialogState extends State<LiveTvCountryDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<IptvCountry> _allCountries = IptvProvider.popularCountries;
  List<IptvCountry> _filtered = IptvProvider.popularCountries;
  bool _loading = true;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final list = await widget.iptvProvider.fetchCountries();
    if (mounted) {
      setState(() {
        _allCountries = list;
        _filtered = list;
        _loading = false;
      });
    }
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allCountries;
      } else {
        _filtered = _allCountries
            .where(
              (c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q),
            )
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Dialog(
      backgroundColor: tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.borderRadiusLg,
        side: BorderSide(color: tokens.borderSubtle),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select Live TV Country',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ],
                  ),
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
                'Filter channels and search results by broadcast country.',
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
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search countries…',
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
              // Countries list
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No matching countries found.',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: tokens.borderSubtle.withValues(alpha: 0.5),
                        ),
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final isSelected =
                              c.code.toUpperCase() ==
                              widget.selectedCountry.toUpperCase();
                          return TvFocusable(
                            autofocus: isSelected && index == 0,
                            scaleFactor: 1.03,
                            borderRadius: tokens.borderRadiusSm,
                            onTap: () {
                              widget.onCountrySelected(c.code);
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
                                    c.code == 'ALL'
                                        ? Icons.public_rounded
                                        : Icons.flag_rounded,
                                    size: 18,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      c.name,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
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
                                      c.code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: tokens.textMuted,
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
