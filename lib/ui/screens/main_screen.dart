import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
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
    final app = context.watch<AppProvider>();
    final isTv = app.isTvMode;
    final isDesktop = MediaQuery.of(context).size.width >= 800 || isTv;

    if (isDesktop) {
      final desktopContent = Scaffold(
        body: Row(
          children: [
            // TV Mode: D-Pad Focusable TV Sidebar | Desktop: Sleek Navigation Rail
            if (isTv)
              _buildTvSidebar(theme)
            else
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (idx) =>
                    setState(() => _currentIndex = idx),
                backgroundColor: theme.colorScheme.surface,
                selectedIconTheme: IconThemeData(
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                unselectedIconTheme: const IconThemeData(
                  color: Colors.white54,
                  size: 22,
                ),
                selectedLabelTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelTextStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                labelType: NavigationRailLabelType.all,
                useIndicator: true,
                indicatorColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 8,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.movie_filter_rounded,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Exalere',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    selectedIcon: Icon(Icons.video_library_rounded),
                    label: Text('My List'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: Text('Settings'),
                  ),
                ],
              ),
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: Colors.white10,
            ),
            Expanded(child: _screens[_currentIndex]),
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
              color: Colors.black.withValues(alpha: 0.65),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
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
                  return const TextStyle(fontSize: 11, color: Colors.white54);
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(
                      color: theme.colorScheme.primary,
                      size: 24,
                    );
                  }
                  return const IconThemeData(color: Colors.white60, size: 22);
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (idx) =>
                    setState(() => _currentIndex = idx),
                backgroundColor: Colors.transparent,
                elevation: 0,
                height: 64,
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
    );
    return mobileContent;
  }

  Widget _buildTvSidebar(ThemeData theme) {
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
      child: Column(
        children: [
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Exalere',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: navItems.length,
              separatorBuilder: (context, _) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final item = navItems[idx];
                final isSelected = _currentIndex == idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TvFocusable(
                    scaleFactor: 1.08,
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _currentIndex = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
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
                                : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$3,
                            style: TextStyle(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.white60,
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
          ),
        ],
      ),
    );
  }
}
