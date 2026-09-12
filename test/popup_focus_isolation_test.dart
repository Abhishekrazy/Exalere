import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';
import 'package:exalere/ui/widgets/tv/tv_popup_scope.dart';
import 'package:exalere/ui/widgets/dpad/dpad.dart';

void main() {
  testWidgets(
    'TvFocusable automatically sets canRequestFocus=false on background routes',
    (tester) async {
      final behindBtn = FocusNode(debugLabel: 'BehindBtn');
      final dialogBtn = FocusNode(debugLabel: 'DialogBtn');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Dpad(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  TvFocusable(
                    focusNode: behindBtn,
                    autofocus: true,
                    child: const Text('Behind Button'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await showDialog(
                        context: ctx,
                        builder: (dialogCtx) => TvPopupScope(
                          child: AlertDialog(
                            content: TvFocusable(
                              focusNode: dialogBtn,
                              autofocus: true,
                              child: const Text('Dialog Button'),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(behindBtn.hasFocus, isTrue);

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(dialogBtn.hasFocus, isTrue);
      expect(behindBtn.hasFocus, isFalse);

      // Verify behindBtn cannot request focus while dialog is open!
      expect(behindBtn.canRequestFocus, isFalse);

      // Try to programmatically steal focus to behindBtn
      behindBtn.requestFocus();
      await tester.pumpAndSettle();

      expect(
        behindBtn.hasFocus,
        isFalse,
        reason: 'behindBtn MUST NOT take focus while dialog is open!',
      );
      expect(dialogBtn.hasFocus, isTrue, reason: 'dialogBtn must keep focus!');

      // Close dialog
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      // Now dialog is closed, behind route is current again!
      expect(behindBtn.canRequestFocus, isTrue);
    },
  );

  testWidgets(
    'TvPopupScope traps D-Pad directional navigation at popup boundaries',
    (tester) async {
      final behindNode1 = FocusNode(debugLabel: 'BehindCard1');
      final behindNode2 = FocusNode(debugLabel: 'BehindCard2');
      final dialogBtn1 = FocusNode(debugLabel: 'DialogAction1');
      final dialogBtn2 = FocusNode(debugLabel: 'DialogAction2');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Dpad(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  TvFocusable(
                    focusNode: behindNode1,
                    autofocus: true,
                    child: const Text('Behind Card 1'),
                  ),
                  TvFocusable(
                    focusNode: behindNode2,
                    child: const Text('Behind Card 2'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await showDialog(
                        context: ctx,
                        builder: (dialogCtx) => TvPopupScope(
                          child: AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TvFocusable(
                                  focusNode: dialogBtn1,
                                  autofocus: true,
                                  child: const Text('Dialog Action 1'),
                                ),
                                TvFocusable(
                                  focusNode: dialogBtn2,
                                  child: const Text('Dialog Action 2'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(behindNode1.hasFocus, isTrue);

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(dialogBtn1.hasFocus, isTrue);

      // Press D-Pad Up when on the top-most dialog button (should NOT escape to behind cards)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(
        dialogBtn1.hasFocus,
        isTrue,
        reason: 'D-Pad Up must not escape to background cards',
      );

      // Press D-Pad Left & Right at boundary
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(dialogBtn1.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(dialogBtn1.hasFocus, isTrue);

      // Navigate Down to Dialog Action 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(dialogBtn2.hasFocus, isTrue);

      // Press D-Pad Down at bottom of dialog (should NOT escape)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        dialogBtn2.hasFocus,
        isTrue,
        reason: 'D-Pad Down must stop at bottom of popup',
      );

      // Press random keys (letters, numbers)
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(
        dialogBtn2.hasFocus,
        isTrue,
        reason: 'Random keys must not move focus to background',
      );
    },
  );

  testWidgets(
    'TvPopupScope traps Tab and Shift+Tab and cycles within popup buttons',
    (tester) async {
      final dialogBtn1 = FocusNode(debugLabel: 'Btn1');
      final dialogBtn2 = FocusNode(debugLabel: 'Btn2');
      final dialogBtn3 = FocusNode(debugLabel: 'Btn3');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Dpad(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: TvPopupScope(
              child: Column(
                children: [
                  TvFocusable(
                    focusNode: dialogBtn1,
                    autofocus: true,
                    child: const Text('Button 1'),
                  ),
                  TvFocusable(
                    focusNode: dialogBtn2,
                    child: const Text('Button 2'),
                  ),
                  TvFocusable(
                    focusNode: dialogBtn3,
                    child: const Text('Button 3'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(dialogBtn1.hasFocus, isTrue);

      // Tab -> Button 2
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dialogBtn2.hasFocus, isTrue);

      // Tab -> Button 3
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(dialogBtn3.hasFocus, isTrue);

      // Tab on last item -> wraps around to Button 1!
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        dialogBtn1.hasFocus,
        isTrue,
        reason: 'Tab on last button must wrap to first button',
      );

      // Shift+Tab from first item -> wraps around to Button 3!
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(
        dialogBtn3.hasFocus,
        isTrue,
        reason: 'Shift+Tab on first button must wrap to last button',
      );
    },
  );

  testWidgets(
    'TvPopupScope automatically autofocuses first available button when no button has autofocus',
    (tester) async {
      final btn1 = FocusNode(debugLabel: 'FallbackBtn1');
      final btn2 = FocusNode(debugLabel: 'FallbackBtn2');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Dpad(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: TvPopupScope(
              // Neither button has autofocus: true
              child: Column(
                children: [
                  TvFocusable(focusNode: btn1, child: const Text('Button 1')),
                  TvFocusable(focusNode: btn2, child: const Text('Button 2')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // TvPopupScope should automatically grant focus to btn1!
      expect(
        btn1.hasFocus,
        isTrue,
        reason: 'TvPopupScope must guarantee initial focus on first button',
      );
    },
  );
}
