import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TvSpatialNavigation navigates to right candidate and stops at edge',
    (tester) async {
      final focusNode1 = FocusNode(debugLabel: 'Item1');
      final focusNode2 = FocusNode(debugLabel: 'Item2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvFocusable(
                    focusNode: focusNode1,
                    autofocus: true,
                    child: const SizedBox(
                      width: 80,
                      height: 80,
                      child: Text('1'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TvFocusable(
                    focusNode: focusNode2,
                    child: const SizedBox(
                      width: 80,
                      height: 80,
                      child: Text('2'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);

      // Press D-Pad Right -> moves to Item 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusNode2.hasFocus, isTrue);
      expect(focusNode1.hasFocus, isFalse);

      // Press D-Pad Right again -> Nothing available to the right -> does nothing and stays on Item 2!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusNode2.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation navigates down and does nothing when at bottom edge',
    (tester) async {
      final focusTop = FocusNode(debugLabel: 'Top');
      final focusBottom = FocusNode(debugLabel: 'Bottom');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvFocusable(
                    focusNode: focusTop,
                    autofocus: true,
                    child: const SizedBox(
                      width: 100,
                      height: 50,
                      child: Text('Top'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TvFocusable(
                    focusNode: focusBottom,
                    child: const SizedBox(
                      width: 100,
                      height: 50,
                      child: Text('Bottom'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);

      // Press D-Pad Down -> moves to Bottom
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusBottom.hasFocus, isTrue);

      // Press D-Pad Down again -> Nothing below -> stays on Bottom
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusBottom.hasFocus, isTrue);

      // Press D-Pad Up -> moves back to Top
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);

      // Press D-Pad Up again -> Nothing above -> stays on Top
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation stops at end of horizontal shelf and does not jump down to a shelf below on D-Pad Right',
    (tester) async {
      final ep1 = FocusNode(debugLabel: 'Episode1');
      final ep2 = FocusNode(debugLabel: 'Episode2');
      final related1 = FocusNode(debugLabel: 'Related1');
      final related2 = FocusNode(debugLabel: 'Related2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Row 1: Episodes (y: 50..150)
                Row(
                  children: [
                    TvFocusable(
                      focusNode: ep1,
                      autofocus: true,
                      child: const SizedBox(
                        width: 100,
                        height: 100,
                        child: Text('Ep 1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      focusNode: ep2,
                      child: const SizedBox(
                        width: 100,
                        height: 100,
                        child: Text('Ep 2'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60), // Clear vertical gap between rows
                // Row 2: Related (y: 210..310) - positioned further right
                Padding(
                  padding: const EdgeInsets.only(left: 150),
                  child: Row(
                    children: [
                      TvFocusable(
                        focusNode: related1,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Text('Related 1'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TvFocusable(
                        focusNode: related2,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Text('Related 2'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);

      // Move Right to Ep 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isTrue);

      // Press Right again on Ep 2:
      // Related 1 and Related 2 are further right (x: 150+ and 240+), but are in a row below!
      // Must NOT jump down to Related 1 or Related 2!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isTrue);
      expect(related1.hasFocus, isFalse);
      expect(related2.hasFocus, isFalse);

      // Pressing Down on Ep 2 DOES move down to Related row
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isFalse);
      expect(related1.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation stops at start of horizontal shelf and does not jump up to a button above on D-Pad Left',
    (tester) async {
      final resumeBtn = FocusNode(debugLabel: 'ResumeBtn');
      final seasonChip = FocusNode(debugLabel: 'SeasonChip');
      final ep1 = FocusNode(debugLabel: 'Episode1');
      final ep2 = FocusNode(debugLabel: 'Episode2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 0: Action button (y: ~50)
                  TvFocusable(
                    focusNode: resumeBtn,
                    child: const SizedBox(
                      width: 120,
                      height: 40,
                      child: Text('Resume'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Row 1: Season chip (y: ~110, small width ~50px)
                  TvFocusable(
                    focusNode: seasonChip,
                    child: const SizedBox(
                      width: 50,
                      height: 32,
                      child: Text('S1'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Row 2: Episodes row (y: ~162)
                  Row(
                    children: [
                      TvFocusable(
                        focusNode: ep1,
                        autofocus: true,
                        child: const SizedBox(
                          width: 200,
                          height: 120,
                          child: Text('Ep 1'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      TvFocusable(
                        focusNode: ep2,
                        child: const SizedBox(
                          width: 200,
                          height: 120,
                          child: Text('Ep 2'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);

      // When on Ep 1 and pressing Left:
      // Must NOT jump UP to SeasonChip or ResumeBtn!
      // Must do NOTHING and stay on Ep 1!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);
      expect(seasonChip.hasFocus, isFalse);
      expect(resumeBtn.hasFocus, isFalse);

      // Only pressing UP moves focus up to SeasonChip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isFalse);
      expect(seasonChip.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation UP from subpage choice moves directly to Back button, NEVER to sidebar',
    (tester) async {
      final sidebarHome = FocusNode(debugLabel: 'SidebarHome');
      final sidebarSettings = FocusNode(debugLabel: 'SidebarSettings');
      final backBtn = FocusNode(debugLabel: 'SubpageBack');
      final choiceYes = FocusNode(debugLabel: 'ChoiceYes');
      final choiceNo = FocusNode(debugLabel: 'ChoiceNo');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                // TV Sidebar (x: 0..72)
                Container(
                  width: 72,
                  color: Colors.black,
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      TvFocusable(
                        focusNode: sidebarHome,
                        child: const SizedBox(
                          width: 58,
                          height: 52,
                          child: Text('Home'),
                        ),
                      ),
                      const SizedBox(height: 100),
                      TvFocusable(
                        focusNode: sidebarSettings,
                        child: const SizedBox(
                          width: 58,
                          height: 52,
                          child: Text('Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Subpage Content Area (x: 72..end)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 20, 36, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Breadcrumb Button (x: ~108, y: ~20..52)
                        TvFocusable(
                          focusNode: backBtn,
                          child: const SizedBox(
                            width: 72,
                            height: 32,
                            child: Text('Back'),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Choice 1: 'Yes' (autofocused)
                        TvFocusable(
                          focusNode: choiceYes,
                          autofocus: true,
                          child: const SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Text('Yes'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Choice 2: 'No'
                        TvFocusable(
                          focusNode: choiceNo,
                          child: const SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Text('No'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(choiceYes.hasFocus, isTrue);
      expect(sidebarHome.hasFocus, isFalse);
      expect(backBtn.hasFocus, isFalse);

      // Press UP from 'Yes'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // MUST go directly to 'Back' button, NEVER jump to 'Home' in sidebar!
      expect(backBtn.hasFocus, isTrue, reason: 'UP from Yes must focus Back');
      expect(sidebarHome.hasFocus, isFalse, reason: 'Must not focus sidebar');
      expect(choiceYes.hasFocus, isFalse);

      // Press DOWN from 'Back'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // MUST return directly to 'Yes'
      expect(
        choiceYes.hasFocus,
        isTrue,
        reason: 'DOWN from Back must return to Yes',
      );
      expect(backBtn.hasFocus, isFalse);
      expect(sidebarHome.hasFocus, isFalse);

      // Press DOWN from 'Yes'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(choiceNo.hasFocus, isTrue);

      // Press UP from 'No'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(choiceYes.hasFocus, isTrue);
    },
  );
}
