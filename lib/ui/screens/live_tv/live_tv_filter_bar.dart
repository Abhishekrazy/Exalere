import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../../widgets/tv_focusable.dart';

class LiveTvFilterBar extends StatefulWidget {
  final String selectedCountry;
  final String countryDisplayName;
  final Set<String> selectedLanguages;
  final String languageDisplayName;
  final String selectedCategory;
  final bool isFavoritesOnly;
  final bool isSearchVisible;
  final bool hasSearchQuery;
  final VoidCallback onCountryTap;
  final VoidCallback onLanguageTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onFavoritesToggle;
  final VoidCallback onPlaylistsTap;
  final VoidCallback onSearchToggle;

  /// Optional: focus node for the first filter button (Country) for TV Up nav.
  final FocusNode? firstButtonFocusNode;

  /// Optional: legacy focusNode prop maintained for compatibility.
  final FocusNode? focusNode;

  /// Called when D-Pad Down is pressed from any filter button on TV.
  final VoidCallback? onDownFocus;

  const LiveTvFilterBar({
    super.key,
    required this.selectedCountry,
    required this.countryDisplayName,
    required this.selectedLanguages,
    required this.languageDisplayName,
    required this.selectedCategory,
    this.isFavoritesOnly = false,
    required this.isSearchVisible,
    required this.hasSearchQuery,
    required this.onCountryTap,
    required this.onLanguageTap,
    required this.onCategoryTap,
    required this.onFavoritesToggle,
    required this.onPlaylistsTap,
    required this.onSearchToggle,
    this.firstButtonFocusNode,
    this.focusNode,
    this.onDownFocus,
  });

  @override
  State<LiveTvFilterBar> createState() => _LiveTvFilterBarState();
}

class _LiveTvFilterBarState extends State<LiveTvFilterBar> {
  final List<FocusNode> _internalNodes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _internalNodes) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _getNode(int index) {
    if (index == 0) {
      return widget.firstButtonFocusNode ??
          widget.focusNode ??
          _getInternalNode(0);
    }
    return _getInternalNode(index);
  }

  FocusNode _getInternalNode(int index) {
    while (_internalNodes.length <= index) {
      _internalNodes.add(
        FocusNode(debugLabel: 'liveTvFilterNode_${_internalNodes.length}'),
      );
    }
    return _internalNodes[index];
  }

  FocusOnKeyEventCallback _keyHandler(int index, int total) {
    return (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          widget.onDownFocus != null) {
        widget.onDownFocus!();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (index < total - 1) {
          final nextNode = _getNode(index + 1);
          nextNode.requestFocus();
          if (nextNode.context != null && nextNode.context!.mounted) {
            Scrollable.ensureVisible(
              nextNode.context!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (index > 0) {
          final prevNode = _getNode(index - 1);
          prevNode.requestFocus();
          if (prevNode.context != null && prevNode.context!.mounted) {
            Scrollable.ensureVisible(
              prevNode.context!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            );
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const totalButtons = 6;

    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 6),
      child: SizedBox(
        height: 52,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              // 0. Country Filter Icon Button
              _buildFilterIconButton(
                context: context,
                index: 0,
                total: totalButtons,
                buttonFocusNode: _getNode(0),
                icon: Icons.public_rounded,
                tooltip: 'Country: ${widget.countryDisplayName}',
                isActive: widget.selectedCountry != 'ALL',
                activeColor: theme.colorScheme.primary,
                onTap: widget.onCountryTap,
              ),
              const SizedBox(width: 8),

              // 1. Language Filter Icon Button
              _buildFilterIconButton(
                context: context,
                index: 1,
                total: totalButtons,
                buttonFocusNode: _getNode(1),
                icon: Icons.translate_rounded,
                tooltip: 'Languages: ${widget.languageDisplayName}',
                isActive:
                    !widget.selectedLanguages.contains('ALL') &&
                    widget.selectedLanguages.isNotEmpty,
                activeColor: theme.colorScheme.secondary,
                onTap: widget.onLanguageTap,
              ),
              const SizedBox(width: 8),

              // 2. Category Filter Icon Button
              _buildFilterIconButton(
                context: context,
                index: 2,
                total: totalButtons,
                buttonFocusNode: _getNode(2),
                icon: Icons.category_rounded,
                tooltip:
                    'Category: ${widget.selectedCategory == 'All' ? 'All Categories' : widget.selectedCategory}',
                isActive: widget.selectedCategory != 'All',
                activeColor: theme.colorScheme.primary,
                onTap: widget.onCategoryTap,
              ),
              const SizedBox(width: 8),

              // 3. Favorites Toggle Icon Button
              _buildFilterIconButton(
                context: context,
                index: 3,
                total: totalButtons,
                buttonFocusNode: _getNode(3),
                icon: widget.isFavoritesOnly
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                tooltip: widget.isFavoritesOnly
                    ? 'Show all channels'
                    : 'Favorite channels',
                isActive: widget.isFavoritesOnly,
                activeColor: context.tokens.vipColor,
                onTap: widget.onFavoritesToggle,
              ),
              const SizedBox(width: 8),

              // 4. Multi-M3U Playlists Icon Button
              _buildFilterIconButton(
                context: context,
                index: 4,
                total: totalButtons,
                buttonFocusNode: _getNode(4),
                icon: Icons.playlist_play_rounded,
                tooltip: 'M3U Playlists',
                isActive: false,
                activeColor: theme.colorScheme.primary,
                onTap: widget.onPlaylistsTap,
              ),
              const SizedBox(width: 8),

              // 5. Search Toggle Icon Button
              _buildFilterIconButton(
                context: context,
                index: 5,
                total: totalButtons,
                buttonFocusNode: _getNode(5),
                icon: widget.isSearchVisible
                    ? Icons.search_off_rounded
                    : Icons.search_rounded,
                tooltip: widget.isSearchVisible
                    ? 'Close search'
                    : 'Search channels',
                isActive: widget.isSearchVisible || widget.hasSearchQuery,
                activeColor: theme.colorScheme.primary,
                onTap: widget.onSearchToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterIconButton({
    required BuildContext context,
    required int index,
    required int total,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isActive,
    Color? activeColor,
    FocusNode? buttonFocusNode,
  }) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final effActiveColor = activeColor ?? theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: TvFocusable(
        focusNode: buttonFocusNode,
        scaleFactor: 1.12,
        borderRadius: tokens.borderRadiusPill,
        onTap: onTap,
        onKeyEvent: _keyHandler(index, total),
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
