import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'ui/widgets/dpad/dpad.dart';

import 'providers/app_provider.dart';
import 'providers/library_provider.dart';
import 'providers/cast_provider.dart';
import 'services/libmpv_helper.dart';
import 'services/update_service.dart';
import 'ui/widgets/app_splash_screen.dart';

Future<void> _initMaterialIcons() async {
  try {
    final fontLoader = FontLoader('MaterialIcons');
    fontLoader.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await fontLoader.load();
  } catch (_) {
    try {
      final fontLoader = FontLoader('MaterialIcons');
      fontLoader.addFont(
        rootBundle.load('assets/fonts/MaterialIcons-Regular.otf'),
      );
      await fontLoader.load();
    } catch (e) {
      debugPrint('MaterialIcons font load error: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Ensure edge-to-edge layout so app uses full screen space behind status/nav bars
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

  // Safeguard Windows libmpv critical sections against ntdll access violations
  LibMpvHelper.ensureCriticalSectionsInitialized();

  // Global uncaught error handling to prevent application termination on player/decoder issues
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('FlutterError stack trace:\n${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error caught: $error');
    return true; // mark error as handled so process does not terminate
  };

  // Optimize image cache budget for low-RAM devices (Android TV / Fire TV sticks)
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 << 20; // 40 MB max

  final appProvider = AppProvider();
  final libraryProvider = LibraryProvider();

  // Parallelize critical local startup in sub-30ms
  await Future.wait([
    _initMaterialIcons(),
    UpdateService.initVersion(),
    appProvider.init(),
    libraryProvider.init(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: libraryProvider),
        ChangeNotifierProvider(create: (_) => CastProvider()),
      ],
      child: const ExalereApp(),
    ),
  );
}

class ExalereApp extends StatelessWidget {
  const ExalereApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return MaterialApp(
      title: 'Exalere',
      debugShowCheckedModeBanner: false,
      theme: app.currentTheme.themeData,
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA):
            const ActivateIntent(),
      },
      home: const AppSplashScreen(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(app.uiScale)),
          child: child ?? const SizedBox.shrink(),
        );
        return Dpad(child: scaled);
      },
    );
  }
}
