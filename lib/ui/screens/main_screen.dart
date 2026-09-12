import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../widgets/dpad/dpad.dart';

import '../../providers/app_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/initial_language_dialog.dart';
import '../widgets/tv/tv_exit_dialog.dart';
import '../widgets/tv_focusable.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'live_tv_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<FocusNode> _sidebarFocusNodes;

  @override
  void initState() {
    super.initState();
    _sidebarFocusNodes = List.generate(
      5,
      (i) => FocusNode(debugLabel: 'TvSidebar_$i'),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLanguage();
    });
  }

  Future<void> _checkInitialLanguage() async {
    if (!mounted) return;
    // Do not show initial dialog automatically in widget test environment
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) return;
    final app = context.read<AppProvider>();
    if (!app.hasPromptedInitialLanguage) {
      await InitialLanguageDialog.show(context);
    }
  }

  @override
  void dispose() {
    for (final node in _sidebarFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool _sidebarFocused = false;

  Future<void> _handleBack() async {
    if (!mounted) return;
    final app = context.read<AppProvider>();
    final isTv = app.isTvMode;
    if (isTv) {
      // If currently inside an inner settings subpage or one was just popped,
      // let the settings view handle it; do not escape to sidebar.
      if (_currentIndex == 4 &&
          (app.isSettingsSubpageOpen || app.hadRecentSettingsSubpagePop)) {
        return;
      }
      if (_sidebarFocused) {
        // Already on sidebar → show exit dialog
        await TvExitDialog.show(context);
        // Restore sidebar focus after dialog closes
        if (mounted && _sidebarFocusNodes[_currentIndex].canRequestFocus) {
          _sidebarFocusNodes[_currentIndex].requestFocus();
        }
      } else {
        // First Back press: move focus from page content to sidebar item
        if (_sidebarFocusNodes[_currentIndex].canRequestFocus) {
          _sidebarFocusNodes[_currentIndex].requestFocus();
        } else {
          // Fallback: try any sidebar node
          for (final node in _sidebarFocusNodes) {
            if (node.canRequestFocus) {
              node.requestFocus();
              break;
            }
          }
        }
        // Mark sidebar as focused so next Back press shows exit dialog
        setState(() => _sidebarFocused = true);
      }
    } else {
      // Mobile / Desktop: navigate back to Home tab first, then exit
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      } else {
        TvExitDialog.show(context);
      }
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LiveTvScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final isDesktop = MediaQuery.of(context).size.width >= 800 || isTv;

    final Widget content;
    if (isDesktop) {
      content = Scaffold(
        extendBodyBehindAppBar: true,
        body: Row(
          children: [
            // TV Mode: D-Pad Focusable TV Sidebar | Desktop/Landscape: Scrollable Navigation Rail
            if (isTv)
              SafeArea(
                top: false,
                bottom: false,
                left: true,
                right: false,
                child: _buildTvSidebar(context, theme),
              )
            else
              Container(
                color: theme.colorScheme.surface,
                child: SafeArea(
                  top: true,
                  bottom: true,
                  left: true,
                  right: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              groupAlignment: 0.0,
                              selectedIndex: _currentIndex,
                              onDestinationSelected: (idx) =>
                                  setState(() => _currentIndex = idx),
                              backgroundColor: Colors.transparent,
                              selectedIconTheme: IconThemeData(
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              unselectedIconTheme: IconThemeData(
                                color: tokens.textSecondary,
                                size: 22,
                              ),
                              selectedLabelTextStyle: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              unselectedLabelTextStyle: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                              labelType: NavigationRailLabelType.all,
                              useIndicator: true,
                              indicatorColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              leading: const SizedBox(height: 8),
                              destinations: const [
                                NavigationRailDestination(
                                  icon: Icon(Icons.home_outlined),
                                  selectedIcon: Icon(Icons.home_rounded),
                                  label: Text('Home'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.search_outlined),
                                  selectedIcon: Icon(Icons.search_rounded),
                                  label: Text('Search'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.live_tv_outlined),
                                  selectedIcon: Icon(Icons.live_tv_rounded),
                                  label: Text('Live TV'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.video_library_outlined),
                                  selectedIcon: Icon(
                                    Icons.video_library_rounded,
                                  ),
                                  label: Text('My List'),
                                ),
                                NavigationRailDestination(
                                  icon: Icon(Icons.settings_outlined),
                                  selectedIcon: Icon(Icons.settings_rounded),
                                  label: Text('Settings'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            VerticalDivider(thickness: 1, width: 1, color: tokens.borderSubtle),
            Expanded(
              child: SafeArea(
                top: !isTv,
                bottom: false,
                left: false,
                right: true,
                child: MediaQuery.removeViewInsets(
                  context: context,
                  removeBottom: true,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    removeBottom: true,
                    removeLeft: true,
                    removeRight: true,
                    child: _screens[_currentIndex],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      content = Scaffold(
        extendBody: true,
        body: _screens[_currentIndex],
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: tokens.surfaceCard.withValues(alpha: 0.75),
                border: Border(
                  top: BorderSide(color: tokens.borderSubtle, width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    indicatorColor: theme.colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        );
                      }
                      return TextStyle(fontSize: 11, color: tokens.textMuted);
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return IconThemeData(
                          color: theme.colorScheme.primary,
                          size: 24,
                        );
                      }
                      return IconThemeData(
                        color: tokens.textSecondary,
                        size: 22,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) =>
                        setState(() => _currentIndex = idx),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    height: 62,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.search_outlined),
                        selectedIcon: Icon(Icons.search_rounded),
                        label: 'Search',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.live_tv_outlined),
                        selectedIcon: Icon(Icons.live_tv_rounded),
                        label: 'Live TV',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bookmark_outline_rounded),
                        selectedIcon: Icon(Icons.bookmark_rounded),
                        label: 'My List',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings_rounded),
                        label: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.goBack)) {
            final app = context.read<AppProvider>();
            if (_currentIndex == 4 &&
                (app.isSettingsSubpageOpen ||
                    app.hadRecentSettingsSubpagePop)) {
              return KeyEventResult.ignored;
            }
            _handleBack();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: content,
      ),
    );
  }

  Widget _buildTvSidebar(BuildContext context, ThemeData theme) {
    final tokens = context.tokens;
    final navItems = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.search_rounded, Icons.search_outlined, 'Search'),
      (Icons.live_tv_rounded, Icons.live_tv_outlined, 'Live TV'),
      (Icons.video_library_rounded, Icons.video_library_outlined, 'My List'),
      (Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
    ];

    return Container(
      width: 72,
      color: theme.colorScheme.surface,
      child: Center(
        child: DpadRegion(
          memoryKey: 'tv_sidebar',
          enter: DpadEnterBehavior.restore,
          verticalEdge: DpadEdgeBehavior.stop,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int idx = 0; idx < navItems.length; idx++) ...[
                  if (idx > 0) const SizedBox(height: 6),
                  Builder(
                    builder: (context) {
                      final item = navItems[idx];
                      final isSelected = _currentIndex == idx;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        child: TvFocusable(
                          focusNode: _sidebarFocusNodes[idx],
                          scaleFactor: 1.08,
                          borderRadius: tokens.borderRadiusSm,
                          onTap: () => setState(() => _currentIndex = idx),
                          // Track sidebar focus so _handleBack knows where focus is
                          onFocusChange: (focused) {
                            if (_sidebarFocused != focused) {
                              setState(() => _sidebarFocused = focused);
                            }
                          },
                          child: Container(
                            width: 58,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.15,
                                    )
                                  : tokens.canvasBackground.withValues(
                                      alpha: 0.0,
                                    ),
                              borderRadius: tokens.borderRadiusSm,
                              border: isSelected
                                  ? Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.35),
                                      width: 1.0,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected ? item.$1 : item.$2,
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : tokens.textSecondary,
                                  size: 21,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.$3,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : tokens.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 10,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
