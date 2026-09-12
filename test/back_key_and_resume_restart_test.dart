import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/screens/player/player_key_handler.dart';
import 'package:exalere/ui/widgets/tv/tv_details_action_bar.dart';

class _FakePlayer extends Fake implements Player {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerKeyHandler Back Key Tests', () {
    test('Back key down consumes event, and Back key up hides controls', () {
      bool controlsHidden = false;
      bool popped = false;

      final player = _FakePlayer();

      final downEvent = const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.goBack,
        timeStamp: Duration.zero,
      );

      final downResult = PlayerKeyHandler.handleKeyEvent(
        event: downEvent,
        isTv: true,
        isControlsLocked: false,
        showControls: true,
        isFullscreen: true,
        player: player,
        onShowUnlockButton: () {},
        onHideTvControls: () => controlsHidden = true,
        onRevealTvControls: () {},
        onToggleFullscreen: () {},
        onPop: () => popped = true,
        showToast: (_) {},
        onDoubleTapSeek: (_) {},
        onUserActivity: () {},
        onStartHideTimer: () {},
        onToggleSubtitle: () {},
        onTriggerSkip: () {},
        hasActiveSkip: false,
      );

      // On key down: event is consumed/handled, but action has not started yet
      expect(downResult, equals(KeyEventResult.handled));
      expect(controlsHidden, isFalse);
      expect(popped, isFalse);

      final upEvent = const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.goBack,
        timeStamp: Duration.zero,
      );

      final upResult = PlayerKeyHandler.handleKeyEvent(
        event: upEvent,
        isTv: true,
        isControlsLocked: false,
        showControls: true,
        isFullscreen: true,
        player: player,
        onShowUnlockButton: () {},
        onHideTvControls: () => controlsHidden = true,
        onRevealTvControls: () {},
        onToggleFullscreen: () {},
        onPop: () => popped = true,
        showToast: (_) {},
        onDoubleTapSeek: (_) {},
        onUserActivity: () {},
        onStartHideTimer: () {},
        onToggleSubtitle: () {},
        onTriggerSkip: () {},
        hasActiveSkip: false,
      );

      // On key up: action executes
      expect(upResult, equals(KeyEventResult.handled));
      expect(controlsHidden, isTrue);
      expect(popped, isFalse);
    });

    test('Back key down consumes event, and Back key up when controls are hidden pops player', () {
      bool controlsHidden = false;
      bool popped = false;

      final player = _FakePlayer();

      final downEvent = const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.goBack,
        timeStamp: Duration.zero,
      );

      final downResult = PlayerKeyHandler.handleKeyEvent(
        event: downEvent,
        isTv: true,
        isControlsLocked: false,
        showControls: false,
        isFullscreen: true,
        player: player,
        onShowUnlockButton: () {},
        onHideTvControls: () => controlsHidden = true,
        onRevealTvControls: () {},
        onToggleFullscreen: () {},
        onPop: () => popped = true,
        showToast: (_) {},
        onDoubleTapSeek: (_) {},
        onUserActivity: () {},
        onStartHideTimer: () {},
        onToggleSubtitle: () {},
        onTriggerSkip: () {},
        hasActiveSkip: false,
      );

      expect(downResult, equals(KeyEventResult.handled));
      expect(controlsHidden, isFalse);
      expect(popped, isFalse);

      final upEvent = const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.goBack,
        timeStamp: Duration.zero,
      );

      final upResult = PlayerKeyHandler.handleKeyEvent(
        event: upEvent,
        isTv: true,
        isControlsLocked: false,
        showControls: false,
        isFullscreen: true,
        player: player,
        onShowUnlockButton: () {},
        onHideTvControls: () => controlsHidden = true,
        onRevealTvControls: () {},
        onToggleFullscreen: () {},
        onPop: () => popped = true,
        showToast: (_) {},
        onDoubleTapSeek: (_) {},
        onUserActivity: () {},
        onStartHideTimer: () {},
        onToggleSubtitle: () {},
        onTriggerSkip: () {},
        hasActiveSkip: false,
      );

      expect(upResult, equals(KeyEventResult.handled));
      expect(controlsHidden, isFalse);
      expect(popped, isTrue);
    });
  });

  group('TvDetailsActionBar Resume & Restart Tests', () {
    testWidgets('Renders only Play button when hasResume is false', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.netflixBlack.themeData,
          home: Scaffold(
            body: TvDetailsActionBar(
              playButtonFocusNode: focusNode,
              playButtonLabel: 'Play',
              hasResume: false,
              onPlay: () {},
              isFavorite: false,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Restart'), findsNothing);
      expect(find.byIcon(Icons.replay_rounded), findsNothing);
      expect(find.text('My List'), findsOneWidget);

      focusNode.dispose();
    });

    testWidgets('Renders Resume and Restart button when hasResume is true', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      bool restarted = false;
      bool played = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.netflixBlack.themeData,
          home: Scaffold(
            body: TvDetailsActionBar(
              playButtonFocusNode: focusNode,
              playButtonLabel: 'Resume S1 E3',
              hasResume: true,
              onRestart: () => restarted = true,
              onPlay: () => played = true,
              isFavorite: true,
              onToggleFavorite: () {},
            ),
          ),
        ),
      );

      expect(find.text('Resume S1 E3'), findsOneWidget);
      expect(find.text('Restart'), findsOneWidget);
      expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
      expect(find.text('In My List'), findsOneWidget);

      // Tap Play/Resume
      await tester.tap(find.text('Resume S1 E3'));
      expect(played, isTrue);
      expect(restarted, isFalse);

      // Tap Restart
      await tester.tap(find.text('Restart'));
      expect(restarted, isTrue);

      focusNode.dispose();
    });
  });

  group('Details PopScope Shield Tests', () {
    testWidgets('PopScope ignores pop if child route closed recently', (
      WidgetTester tester,
    ) async {
      bool popped = false;
      DateTime? lastChildPoppedTime = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              final now = DateTime.now();
              if (lastChildPoppedTime != null &&
                  now.difference(lastChildPoppedTime).inMilliseconds < 600) {
                return;
              }
              popped = true;
            },
            child: const Scaffold(body: Text('Parent Screen')),
          ),
        ),
      );

      final popScope = tester.widget<PopScope>(
        find.byWidgetPredicate((w) => w is PopScope && w.canPop == false),
      );
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pump();

      expect(popped, isFalse);

      // Simulate passage of time past 600ms
      lastChildPoppedTime = DateTime.now().subtract(
        const Duration(milliseconds: 700),
      );
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pump();

      expect(popped, isTrue);
    });
  });
}
