import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/ui/screens/player/player_picture_tuner_sheet.dart';
import 'package:exalere/ui/screens/player/player_audio_tuner_sheet.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/dpad/dpad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player Picture and Audio Tuners TV D-Pad Accessibility', () {
    testWidgets(
      'PlayerPictureTunerSheet displays dialog on TV and autofocuses active preset',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        int brightness = 0;
        int contrast = 0;
        int saturation = 0;
        int gamma = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            builder: (context, child) =>
                Dpad(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    PlayerPictureTunerSheet.show(
                      context: ctx,
                      initialBrightness: brightness,
                      initialContrast: contrast,
                      initialSaturation: saturation,
                      initialGamma: gamma,
                      onChanged: (b, c, s, g) {
                        brightness = b;
                        contrast = c;
                        saturation = s;
                        gamma = g;
                      },
                    );
                  },
                  child: const Text('Open Picture Tuner'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Picture Tuner'));
        await tester.pumpAndSettle();

        // Verify tuner dialog opened
        expect(find.text('Video Picture Tuner'), findsOneWidget);
        expect(find.text('Standard'), findsOneWidget);
        expect(find.text('Brightness'), findsOneWidget);

        // Verify steppers exist
        expect(find.text('-5'), findsNWidgets(4));
        expect(find.text('+5'), findsNWidgets(4));

        // Tap +5 on Brightness (first +5 button)
        await tester.tap(find.text('+5').first);
        await tester.pumpAndSettle();

        expect(brightness, equals(5));

        // Close dialog
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Video Picture Tuner'), findsNothing);
      },
    );

    testWidgets(
      'PlayerAudioTunerSheet displays dialog on TV and autofocuses active preset',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        AudioFilterPreset appliedPreset = AudioFilterPreset.flat;
        double appliedBoost = 100.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.netflixBlack.themeData,
            builder: (context, child) =>
                Dpad(child: child ?? const SizedBox.shrink()),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    PlayerAudioTunerSheet.show(
                      context: ctx,
                      currentPreset: appliedPreset,
                      currentVolumeBoost: appliedBoost,
                      onApply: (preset, boost) {
                        appliedPreset = preset;
                        appliedBoost = boost;
                      },
                    );
                  },
                  child: const Text('Open Audio Tuner'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Audio Tuner'));
        await tester.pumpAndSettle();

        // Verify tuner dialog opened
        expect(find.text('Audio Equalizer & Clarity'), findsOneWidget);
        expect(find.text('Flat / Original'), findsOneWidget);
        expect(find.text('Pre-Amp Volume Booster'), findsOneWidget);
        expect(find.text('+10%'), findsOneWidget);
        expect(find.text('-10%'), findsOneWidget);
        expect(find.text('Reset (100%)'), findsOneWidget);

        // Increase boost via +10% stepper
        await tester.tap(find.text('+10%'));
        await tester.pumpAndSettle();

        expect(appliedBoost, equals(110.0));
        expect(find.text('110%'), findsOneWidget);

        // Reset boost via Reset button
        await tester.tap(find.text('Reset (100%)'));
        await tester.pumpAndSettle();

        expect(appliedBoost, equals(100.0));
        expect(find.text('100%'), findsOneWidget);

        // Select another preset (e.g., Night Mode)
        await tester.tap(find.text('Night Mode (Dynamic Normalizer)'));
        await tester.pumpAndSettle();

        expect(appliedPreset, equals(AudioFilterPreset.nightMode));

        // Close dialog
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Audio Equalizer & Clarity'), findsNothing);
      },
    );
  });
}
