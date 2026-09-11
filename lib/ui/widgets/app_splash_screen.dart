import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../screens/main_screen.dart';
import '../theme/app_tokens.dart';

/// Cinematic Google/Gmail-style dynamic branded splash intro screen.
/// Smoothly unveils the Exalere logo with subtle glow and zoom,
/// followed by an ambient fade-in of the wordmark and tagline,
/// seamlessly handing off to [MainScreen].
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key});

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _textSlideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Google-style fluid bouncy scale from 0.72 to 1.0
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );

    // Logo fade-in
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );

    // Wordmark & tagline slide & reveal
    _textFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.85, curve: Curves.easeIn),
    );

    _textSlideAnimation = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Fast fluid transition to MainScreen so user immediately gets to content
    final isTv = context.read<AppProvider>().isTvMode;
    final delayMs = isTv ? 160 : 450;
    final transitionMs = isTv ? 140 : 260;

    Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: Duration(milliseconds: transitionMs),
          pageBuilder: (_, _, _) => const MainScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: Stack(
        children: [
          // Ambient cinematic glow backdrop
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    tokens.primaryAccent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Central Google-style logo reveal
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scaling & glowing logo icon
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: tokens.primaryAccent.withValues(
                                  alpha: 0.35 * _fadeAnimation.value,
                                ),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 96,
                            height: 96,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Elegant Wordmark & Subtitle
                    Transform.translate(
                      offset: Offset(0, _textSlideAnimation.value),
                      child: Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Column(
                          children: [
                            Text(
                              'EXALERE',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Stream Without Limits',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
