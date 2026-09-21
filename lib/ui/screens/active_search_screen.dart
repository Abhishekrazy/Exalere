import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../providers/app_provider.dart';
import '../../services/voice_search_service.dart';
import '../theme/app_themes.dart';
import '../widgets/search_media_card.dart';
import '../widgets/tv_focusable.dart';
import 'details_screen.dart';
import 'tv_details_screen.dart';

/// Dedicated search screen displaying exclusively the search input bar,
/// voice search controls, and live search results without category clutter.
class ActiveSearchScreen extends StatefulWidget {
  final bool autoStartVoice;
  final String? initialQuery;

  const ActiveSearchScreen({
    super.key,
    this.autoStartVoice = false,
    this.initialQuery,
  });

  @override
  State<ActiveSearchScreen> createState() => _ActiveSearchScreenState();
}

class _ActiveSearchScreenState extends State<ActiveSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _firstResultCardFocusNode = FocusNode(
    debugLabel: 'ActiveSearchFirstResult',
  );

  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'ActiveSearchInput',
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (_firstResultCardFocusNode.canRequestFocus) {
            _safeFocus(_firstResultCardFocusNode);
            return KeyEventResult.handled;
          }
          final moved = node.focusInDirection(TraversalDirection.down);
          if (moved) return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            _controller.selection.baseOffset <= 0) {
          final moved = node.focusInDirection(TraversalDirection.left);
          if (moved) return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );

  final VoiceSearchService _voiceService = VoiceSearchService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSearchFocused = false;
  bool _isVoiceListening = false;
  String _spokenWords = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final app = context.read<AppProvider>();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      app.search(widget.initialQuery!);
    } else if (app.searchQuery.isNotEmpty) {
      _controller.text = app.searchQuery;
    }

    _searchFocusNode.addListener(_onSearchFocusChanged);
    _controller.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.autoStartVoice) {
        _startVoiceSearch();
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  void _safeFocus(FocusNode node) {
    if (node.canRequestFocus) {
      node.requestFocus();
      if (node.context != null) {
        Scrollable.ensureVisible(
          node.context!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _controller.removeListener(_onControllerChanged);
    _searchFocusNode.dispose();
    _firstResultCardFocusNode.dispose();
    _controller.dispose();
    _pulseController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _startVoiceSearch() async {
    setState(() {
      _isVoiceListening = true;
      _spokenWords = '';
    });
    _pulseController.repeat(reverse: true);

    await _voiceService.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _spokenWords = words;
          _controller.text = words;
        });

        if (isFinal && words.trim().isNotEmpty) {
          _finishVoiceSearch(words.trim());
        }
      },
      onError: (error) {
        if (!mounted) return;
        debugPrint('Voice recognition error: ${error.errorMsg}');
        setState(() {
          _isVoiceListening = false;
        });
        _pulseController.stop();
        _pulseController.reset();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.errorMsg.isNotEmpty
                  ? error.errorMsg
                  : 'Voice recognition unavailable.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  void _finishVoiceSearch(String query) {
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isVoiceListening = false;
    });
    _voiceService.stopListening();

    if (query.isNotEmpty) {
      context.read<AppProvider>().search(query);
      _searchFocusNode.unfocus();
    }
  }

  void _cancelVoiceSearch() {
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isVoiceListening = false;
    });
    _voiceService.cancelListening();
  }

  void _handleItemSelect(MediaItem item, [String? heroTag]) {
    final isTv = context.read<AppProvider>().isTvMode;
    if (isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(mediaItem: item)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailsScreen(mediaItem: item, heroTag: heroTag),
        ),
      );
    }
  }

  void _submitSearch() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) {
      context.read<AppProvider>().search(query);
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final width = MediaQuery.of(context).size.width;
    final isTv = app.isTvMode;
    final uiScale = app.uiScale;

    // Responsive grid columns
    int crossAxisCount;
    if (isTv) {
      if (width < 900) {
        crossAxisCount = 5;
      } else if (width < 1200) {
        crossAxisCount = 6;
      } else if (width < 1600) {
        crossAxisCount = 7;
      } else {
        crossAxisCount = 8;
      }
    } else {
      if (width < 450) {
        crossAxisCount = 2;
      } else if (width < 700) {
        crossAxisCount = 3;
      } else if (width < 950) {
        crossAxisCount = 4;
      } else if (width < 1250) {
        crossAxisCount = 5;
      } else if (width < 1600) {
        crossAxisCount = 6;
      } else {
        crossAxisCount = 7;
      }
    }

    if (uiScale < 0.92) {
      crossAxisCount = (crossAxisCount + 1).clamp(2, 9);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar with Back Button, Search Field, Voice Mic, and Search Button
            Padding(
              padding: EdgeInsets.fromLTRB(
                isTv ? 24 : 16,
                isTv ? 12 : 12,
                isTv ? 24 : 16,
                8,
              ),
              child: Row(
                children: [
                  // Back Button
                  TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: tokens.borderRadiusMd,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: isTv ? 44 : 50,
                      width: isTv ? 44 : 50,
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusMd,
                        border: Border.all(
                          color: tokens.borderSubtle,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: tokens.textPrimary,
                        size: isTv ? 20 : 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Search Text Input
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusMd,
                        border: Border.all(
                          color: _isSearchFocused
                              ? tokens.borderFocus
                              : tokens.borderSubtle,
                          width: _isSearchFocused ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          if (_isSearchFocused)
                            BoxShadow(
                              color: tokens.primaryAccent.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            )
                          else
                            BoxShadow(
                              color: tokens.shadowColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: TextField(
                        focusNode: _searchFocusNode,
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (query) {
                          _submitSearch();
                        },
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: isTv ? 14 : 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search movies, series, anime across providers...',
                          hintStyle: TextStyle(
                            color: tokens.textMuted,
                            fontSize: isTv ? 13 : 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: tokens.textSecondary,
                            size: isTv ? 18 : 20,
                          ),
                          suffixIcon: _controller.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: tokens.textSecondary,
                                    size: isTv ? 18 : 20,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    app.clearSearch();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isTv ? 10 : 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Voice Search Mic Button
                  TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: tokens.borderRadiusMd,
                    onTap: () {
                      if (_isVoiceListening) {
                        _finishVoiceSearch(_spokenWords);
                      } else {
                        _startVoiceSearch();
                      }
                    },
                    child: Container(
                      height: isTv ? 44 : 50,
                      width: isTv ? 44 : 50,
                      decoration: BoxDecoration(
                        color: _isVoiceListening
                            ? tokens.primaryAccent.withValues(alpha: 0.2)
                            : tokens.surfaceElevated,
                        borderRadius: tokens.borderRadiusMd,
                        border: Border.all(
                          color: _isVoiceListening
                              ? tokens.primaryAccent
                              : tokens.borderSubtle,
                          width: _isVoiceListening ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isVoiceListening
                                ? tokens.primaryAccent.withValues(alpha: 0.35)
                                : tokens.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isVoiceListening
                            ? ScaleTransition(
                                scale: _pulseAnimation,
                                child: Icon(
                                  Icons.mic_rounded,
                                  color: tokens.primaryAccent,
                                  size: isTv ? 20 : 22,
                                ),
                              )
                            : Icon(
                                Icons.mic_rounded,
                                color: tokens.textPrimary,
                                size: isTv ? 20 : 22,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search Action Button
                  TvFocusable(
                    scaleFactor: 1.05,
                    borderRadius: tokens.borderRadiusMd,
                    onTap: _submitSearch,
                    child: Container(
                      height: isTv ? 44 : 50,
                      padding: EdgeInsets.symmetric(horizontal: isTv ? 16 : 20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: tokens.borderRadiusMd,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: isTv ? 18 : 20,
                          ),
                          if (width >= 600) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 13 : 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Voice Search Live Listening Banner / Card
            if (_isVoiceListening)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTv ? 24 : 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceElevated,
                    borderRadius: tokens.borderRadiusLg,
                    border: Border.all(
                      color: tokens.primaryAccent.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.primaryAccent.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tokens.primaryAccent.withValues(alpha: 0.25),
                          ),
                          child: Icon(
                            Icons.mic_rounded,
                            color: tokens.primaryAccent,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _spokenWords.isNotEmpty ? _spokenWords : 'Listening... Speak now into your remote or microphone',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _spokenWords.isNotEmpty
                                    ? tokens.textPrimary
                                    : tokens.textSecondary,
                                fontSize: isTv ? 13 : 14,
                                fontWeight: _spokenWords.isNotEmpty
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (_spokenWords.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Say search title or tap Search',
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TvFocusable(
                        borderRadius: tokens.borderRadiusSm,
                        onTap: _cancelVoiceSearch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: tokens.borderRadiusSm,
                            border: Border.all(color: tokens.borderSubtle),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Results Content Area
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (app.isSearching)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Scanning catalogue across all providers...',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (app.searchResults.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTv ? 24 : 16,
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: isTv ? 12 : 16,
                          mainAxisSpacing: isTv ? 14 : 18,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = app.searchResults[index];
                          final heroTag = 'search_${item.id}_$index';
                          final total = app.searchResults.length;
                          final isTopRow = index < crossAxisCount;
                          final isFirstCol = index % crossAxisCount == 0;
                          final isLastCol =
                              (index + 1) % crossAxisCount == 0 ||
                              index == total - 1;
                          return SearchMediaCard(
                            item: item,
                            heroTag: heroTag,
                            focusNode: index == 0
                                ? _firstResultCardFocusNode
                                : null,
                            isTopRow: isTopRow,
                            isFirstCol: isFirstCol,
                            isLastCol: isLastCol,
                            onUp: isTopRow
                                ? () {
                                    _safeFocus(_searchFocusNode);
                                    return true;
                                  }
                                : null,
                            onTap: () => _handleItemSelect(item, heroTag),
                          );
                        }, childCount: app.searchResults.length),
                      ),
                    )
                  else if (app.searchQuery.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 64,
                              color: tokens.borderSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Search for movies, TV series, actors, or anime',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Use your remote keyboard or voice button above',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 64,
                              color: tokens.borderSubtle,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No safe results found for "${app.searchQuery}"',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Check the title spelling or try a broader search term',
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
