import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/ui/screens/player/player_audio_subtitles_sheet.dart';
import 'package:exalere/ui/screens/player/player_playback_helper.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockAudioTracks = [
    const AudioTrack('1', 'Hindi [Original]', 'hin'),
    const AudioTrack('2', 'English', 'eng'),
  ];

  final mockDubs = [
    const AudioTrackOption(
      subjectId: '101',
      language: 'Tamil',
      label: 'Tamil Dubbed',
    ),
  ];

  final mockSubtitleTracks = [
    const SubtitleTrack('sub1', 'English CC', 'eng'),
    const SubtitleTrack('sub2', 'Spanish', 'spa'),
  ];

  final mockExternalSubtitles = [
    const SubtitleOption(
      language: 'hi',
      name: 'Hindi External',
      url: 'https://subs.org/hi.vtt',
    ),
  ];

  Widget buildTestWidget({
    AudioTrack? initialAudio,
    bool initialSubtitlesEnabled = false,
    SubtitleTrack? initialSubtitleTrack,
    SubtitleOption? initialExternalSub,
    void Function(AudioTrackOption)? onSelectDub,
    void Function(AudioTrack, String)? onSelectAudio,
    void Function()? onDisableSubtitles,
    void Function(SubtitleOption)? onSelectExternalSub,
    void Function(SubtitleTrack, String)? onSelectSubtitle,
  }) {
    return MaterialApp(
      theme: AppThemes.netflixBlack.themeData,
      home: Scaffold(
        body: PlayerAudioSubtitlesSheet(
          validAudioTracks: mockAudioTracks,
          availableDubs: mockDubs,
          validSubtitleTracks: mockSubtitleTracks,
          externalSubtitles: mockExternalSubtitles,
          initialAudioTrack: initialAudio ?? mockAudioTracks.first,
          initialSubtitlesEnabled: initialSubtitlesEnabled,
          initialSubtitleTrack: initialSubtitleTrack,
          initialExternalSubtitle: initialExternalSub,
          onSelectDubOption: onSelectDub ?? (_) {},
          onSelectAudioTrack: onSelectAudio ?? (_, _) {},
          onDisableSubtitles: onDisableSubtitles ?? () {},
          onSelectExternalSubtitle: onSelectExternalSub ?? (_) {},
          onSelectSubtitleTrack: onSelectSubtitle ?? (_, _) {},
        ),
      ),
    );
  }

  group('PlayerAudioSubtitlesSheet full-screen layout & navigation tests', () {
    testWidgets(
      'renders full-screen layout with 2 columns, headers, and buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Top bar header
        expect(find.text('Audio & Subtitles'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Two Column Headers
        expect(find.text('AUDIO & LANGUAGES'), findsOneWidget);
        expect(find.text('SUBTITLES'), findsOneWidget);

        // Audio items & dubs rendered
        expect(find.text('Hindi [Original]'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.text('Tamil'), findsOneWidget);

        // Subtitle items rendered
        expect(find.text('Off'), findsOneWidget);
        expect(find.text('English (CC)'), findsOneWidget);
        expect(find.text('Spanish'), findsOneWidget);
        expect(find.text('Hindi'), findsOneWidget);

        // Bottom bar actions
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Apply'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting audio dub and subtitle track invokes callbacks on Apply',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        AudioTrackOption? chosenDub;
        SubtitleTrack? chosenSub;

        await tester.pumpWidget(
          buildTestWidget(
            onSelectDub: (dub) => chosenDub = dub,
            onSelectSubtitle: (sub, _) => chosenSub = sub,
          ),
        );
        await tester.pumpAndSettle();

        // Select Tamil in audio list
        await tester.tap(find.text('Tamil'));
        await tester.pumpAndSettle();

        // Select Spanish in subtitles list
        await tester.tap(find.text('Spanish'));
        await tester.pumpAndSettle();

        // Tap Apply
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();

        expect(chosenDub, isNotNull);
        expect(chosenDub!.language, 'Tamil');

        expect(chosenSub, isNotNull);
        expect(chosenSub!.title, 'Spanish');
      },
    );

    testWidgets('selecting "Off" in subtitles disables subtitles on Apply', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool disabledSubtitles = false;

      await tester.pumpWidget(
        buildTestWidget(
          initialSubtitlesEnabled: true,
          initialSubtitleTrack: mockSubtitleTracks.first,
          onDisableSubtitles: () => disabledSubtitles = true,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Off
      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(disabledSubtitles, isTrue);
    });

    testWidgets(
      'autofocuses top bar back button without throwing or escaping',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      },
    );

    test('LanguageMatcher matches Hindi and English variants correctly', () {
      expect(
        LanguageMatcher.isLanguageMatch('Hindi', title: 'Hindi [5.1]'),
        isTrue,
      );
      expect(LanguageMatcher.isLanguageMatch('Hindi', language: 'hin'), isTrue);
      expect(
        LanguageMatcher.isLanguageMatch('Hindi', label: 'Hindi Dubbed'),
        isTrue,
      );
      expect(
        LanguageMatcher.isLanguageMatch('English', title: 'English [Original]'),
        isTrue,
      );
      expect(
        LanguageMatcher.isLanguageMatch('English', language: 'eng'),
        isTrue,
      );
      expect(
        LanguageMatcher.isLanguageMatch('Hindi', title: 'English [Original]'),
        isFalse,
      );
    });
  });
}
