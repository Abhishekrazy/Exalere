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

  group('focus is handed back when a popup closes', () {
    /// Opens a dialog from a control that actually holds the D-Pad focus, which
    /// is what every screen does. While the dialog is up, [TvFocusable] disables
    /// the control behind it, so without explicit hand-back the remote is left
    /// with no focused element and the user has to D-Pad from scratch.
    Widget harness({
      required FocusNode opener,
      required FocusNode dialogBtn,
      bool includeSibling = false,
    }) {
      return MaterialApp(
        builder: (context, child) =>
            Dpad(child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: Column(
            children: [
              TvFocusable(
                focusNode: opener,
                autofocus: true,
                onTap: () => showDialog<void>(
                  context: opener.context!,
                  builder: (_) => TvPopupScope(
                    child: AlertDialog(
                      content: TvFocusable(
                        focusNode: dialogBtn,
                        autofocus: true,
                        onTap: () {},
                        child: const Text('Dialog Button'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open Popup'),
              ),
              if (includeSibling)
                TvFocusable(
                  focusNode: FocusNode(debugLabel: 'Sibling'),
                  onTap: () {},
                  child: const Text('Sibling'),
                ),
            ],
          ),
        ),
      );
    }

    testWidgets('returns to the control that opened the dialog', (
      tester,
    ) async {
      final opener = FocusNode(debugLabel: 'Opener');
      final dialogBtn = FocusNode(debugLabel: 'DialogBtn');

      await tester.pumpWidget(harness(opener: opener, dialogBtn: dialogBtn));
      await tester.pumpAndSettle();
      expect(opener.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(dialogBtn.hasFocus, isTrue);

      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      expect(
        opener.hasFocus,
        isTrue,
        reason: 'closing a popup must restore the focus it took',
      );
    });

    testWidgets('survives a sibling rebuilding in between', (tester) async {
      final opener = FocusNode(debugLabel: 'Opener');
      final dialogBtn = FocusNode(debugLabel: 'DialogBtn');

      await tester.pumpWidget(
        harness(opener: opener, dialogBtn: dialogBtn, includeSibling: true),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();

      expect(opener.hasFocus, isTrue);
    });

    testWidgets('unwinds one popup layer at a time', (tester) async {
      final opener = FocusNode(debugLabel: 'Opener');
      final firstBtn = FocusNode(debugLabel: 'FirstDialogBtn');
      final secondBtn = FocusNode(debugLabel: 'SecondDialogBtn');

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              Dpad(child: child ?? const SizedBox.shrink()),
          home: Scaffold(
            body: TvFocusable(
              focusNode: opener,
              autofocus: true,
              onTap: () => showDialog<void>(
                context: opener.context!,
                builder: (firstCtx) => TvPopupScope(
                  child: AlertDialog(
                    content: TvFocusable(
                      focusNode: firstBtn,
                      autofocus: true,
                      onTap: () => showDialog<void>(
                        context: firstCtx,
                        builder: (_) => TvPopupScope(
                          child: AlertDialog(
                            content: TvFocusable(
                              focusNode: secondBtn,
                              autofocus: true,
                              onTap: () {},
                              child: const Text('Second'),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('First'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(firstBtn.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(secondBtn.hasFocus, isTrue);

      // Close the inner popup: focus belongs to the control that opened it.
      Navigator.of(
        tester.element(find.widgetWithText(AlertDialog, 'Second')),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        firstBtn.hasFocus,
        isTrue,
        reason: 'closing the inner popup must land back on its opener',
      );

      // Close the outer popup: focus goes back to the page control.
      Navigator.of(
        tester.element(find.widgetWithText(AlertDialog, 'First')),
      ).pop();
      await tester.pumpAndSettle();
      expect(
        opener.hasFocus,
        isTrue,
        reason: 'closing the outer popup must land back on the page',
      );
    });
  });
}
