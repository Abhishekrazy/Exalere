import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/screens/player/player_category_sheets.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/dpad/dpad.dart';

/// The TV player bar used to carry one pill per feature. These sheets are where
/// those features went, so each test pins that a control still exists and still
/// fires its callback - a moved control that silently stops working would be
/// worse than the crowded bar.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: AppThemes.darkTheme.themeData,
    builder: (context, content) =>
        Dpad(child: content ?? const SizedBox.shrink()),
    home: Scaffold(body: child),
  );

  group('Video sheet', () {
    testWidgets('offers ratio, picture, speed and stats', (tester) async {
      var aspectTaps = 0;
      var pictureTaps = 0;
      var speedTaps = 0;
      var statsTaps = 0;

      await tester.pumpWidget(
        host(
          PlayerVideoSheet(
            videoFit: BoxFit.contain,
            playbackSpeed: 1.0,
            isStatsVisible: false,
            onToggleAspectRatio: () => aspectTaps++,
            onOpenPictureTuner: () => pictureTaps++,
            onSelectSpeed: () => speedTaps++,
            onToggleStatsOverlay: () => statsTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aspect ratio'), findsOneWidget);
      expect(find.text('Fit'), findsOneWidget);
      expect(find.text('Picture tuner'), findsOneWidget);
      expect(find.text('Playback speed'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('Stats for nerds'), findsOneWidget);

      await tester.tap(find.text('Aspect ratio'));
      await tester.tap(find.text('Picture tuner'));
      await tester.tap(find.text('Playback speed'));
      await tester.tap(find.text('Stats for nerds'));
      await tester.pumpAndSettle();

      expect(aspectTaps, 1);
      expect(pictureTaps, 1);
      expect(speedTaps, 1);
      expect(statsTaps, 1);
    });

    testWidgets('hides speed on live TV and reports the current ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          PlayerVideoSheet(
            videoFit: BoxFit.cover,
            playbackSpeed: 1.5,
            isStatsVisible: true,
            isLive: true,
            onToggleAspectRatio: () {},
            onToggleStatsOverlay: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      // Live has no playback speed to change.
      expect(find.text('Playback speed'), findsNothing);
      // No tuner callback was supplied, so the row is absent rather than dead.
      expect(find.text('Picture tuner'), findsNothing);
    });
  });

  group('Extras sheet', () {
    testWidgets('offers sleep, party and the audio output rows', (
      tester,
    ) async {
      var sleepTaps = 0;
      var partyTaps = 0;
      var eqTaps = 0;
      var audioOnlyTaps = 0;

      await tester.pumpWidget(
        host(
          PlayerExtrasSheet(
            onOpenSleepTimer: () => sleepTaps++,
            onOpenWatchParty: () => partyTaps++,
            onOpenAudioTuner: () => eqTaps++,
            onToggleAudioOnly: () => audioOnlyTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep timer'), findsOneWidget);
      expect(find.text('Watch party'), findsOneWidget);
      expect(find.text('Equalizer & clarity'), findsOneWidget);
      expect(find.text('Audio-only mode'), findsOneWidget);

      await tester.tap(find.text('Sleep timer'));
      await tester.tap(find.text('Watch party'));
      await tester.tap(find.text('Equalizer & clarity'));
      await tester.tap(find.text('Audio-only mode'));
      await tester.pumpAndSettle();

      expect(sleepTaps, 1);
      expect(partyTaps, 1);
      expect(eqTaps, 1);
      expect(audioOnlyTaps, 1);
    });

    testWidgets('shows only what is available', (tester) async {
      await tester.pumpWidget(
        host(const PlayerExtrasSheet(onOpenSleepTimer: _noop)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep timer'), findsOneWidget);
      expect(find.text('Watch party'), findsNothing);
      expect(find.text('Audio-only mode'), findsNothing);
    });
  });
}

void _noop() {}
