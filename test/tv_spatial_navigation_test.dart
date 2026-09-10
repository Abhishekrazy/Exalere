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
}
