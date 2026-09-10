import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../theme/app_tokens.dart';
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

  @override
  void initState() {
    super.initState();
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

    if (isDesktop) {
      final desktopContent = Scaffold(
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
                top: false,
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
      return desktopContent;
    }

    // Mobile / Tablet Frosted Glass Navigation Bar
    final mobileContent = Scaffold(
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
                    return IconThemeData(color: tokens.textSecondary, size: 22);
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
    return mobileContent;
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
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: TvFocusable(
                        scaleFactor: 1.08,
                        borderRadius: tokens.borderRadiusSm,
                        onTap: () => setState(() => _currentIndex = idx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  )
                                : Colors.transparent,
                            borderRadius: tokens.borderRadiusSm,
                            border: isSelected
                                ? Border.all(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected ? item.$1 : item.$2,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : tokens.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                style: TextStyle(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : tokens.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 9.5,
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
    );
  }
}
