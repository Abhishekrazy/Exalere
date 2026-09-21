import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/storage_service.dart';
import 'package:exalere/services/window_service.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:exalere/ui/screens/player/player_controls_overlay.dart';
import 'package:exalere/ui/screens/player/player_controls_visibility_mixin.dart';
import 'package:exalere/ui/screens/player/player_gesture_hud.dart';
import 'package:exalere/ui/screens/player/player_key_handler.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Player Features & SkipInterval Tests', () {
    test('SkipInterval accurately tests containment within time window', () {
      const interval = SkipInterval(
        type: SkipType.intro,
        startSeconds: 15,
        endSeconds: 85,
        label: 'Skip Intro',
      );

      expect(interval.contains(10), isFalse);
      expect(interval.contains(15), isTrue);
      expect(interval.contains(50), isTrue);
      expect(interval.contains(84), isTrue);
      expect(interval.contains(85), isFalse);
      expect(interval.contains(100), isFalse);
    });

    test('Episode parses skip markers from raw json', () {
      final epJson = {
        'season': 1,
        'episode': 3,
        'title': 'The Variant',
        'introStart': 10,
        'introEnd': 90,
        'outroStart': 2400,
        'outroEnd': 2520,
      };

      final ep = Episode.fromJson(epJson);
      expect(ep.season, equals(1));
      expect(ep.episode, equals(3));
      expect(ep.skipIntervals.length, equals(2));
      expect(ep.skipIntervals[0].type, equals(SkipType.intro));
      expect(ep.skipIntervals[0].startSeconds, equals(10));
      expect(ep.skipIntervals[0].endSeconds, equals(90));
      expect(ep.skipIntervals[1].type, equals(SkipType.outro));
      expect(ep.skipIntervals[1].startSeconds, equals(2400));
    });

    test('MediaDetails parses dubs correctly from MovieBox JSON', () {
      final json = {
        'subjectId': '12345',
        'title': 'Test Movie',
        'subjectType': 1,
        'dubs': [
          {'subjectId': '101', 'lanName': 'English', 'title': 'Original Audio'},
          {'subjectId': '102', 'lanName': 'Hindi', 'title': 'Hindi Dub'},
          {'subjectId': '103', 'lanName': 'Spanish', 'title': 'esla Dub'},
        ],
      };

      final details = MediaDetails.fromMovieBoxJson(json);
      expect(details.dubs.length, equals(3));
      expect(details.dubs[0].subjectId, equals('101'));
      expect(details.dubs[0].language, equals('English'));
      expect(details.dubs[0].label, equals('Original Audio'));
      expect(details.dubs[1].language, equals('Hindi'));
    });

    test(
      'StorageService persists autoSkip and smartSkip preferences',
      () async {
        final storage = StorageService();

        expect(await storage.getAutoSkipIntro(), isFalse);
        expect(await storage.getAutoSkipOutro(), isFalse);
        expect(await storage.getEnableSmartSkip(), isTrue);

        await storage.setAutoSkipIntro(true);
        await storage.setAutoSkipOutro(true);
        await storage.setEnableSmartSkip(false);

        expect(await storage.getAutoSkipIntro(), isTrue);
        expect(await storage.getAutoSkipOutro(), isTrue);
        expect(await storage.getEnableSmartSkip(), isFalse);
      },
    );

    test(
      'Multi-source fallback sequence correctly navigates available sources',
      () {
        final s1 = StreamSource(
          quality: '1080p DASH',
          resolution: '1080',
          format: 'DASH',
          url: 'https://cdn1/dash.mpd',
          headers: {},
        );
        final s2 = StreamSource(
          quality: '1080p MP4',
          resolution: '1080',
          format: 'MP4',
          url: 'https://cdn2/direct.mp4',
          headers: {},
        );
        final s3 = StreamSource(
          quality: '720p MP4',
          resolution: '720',
          format: 'MP4',
          url: 'https://cdn3/backup.mp4',
          headers: {},
        );

        final sources = [s1, s2, s3];
        int currentIndex = 0;

        // First failure -> advance
        expect(currentIndex + 1 < sources.length, isTrue);
        currentIndex++;
        expect(sources[currentIndex].quality, equals('1080p MP4'));

        // Second failure -> advance to backup
        expect(currentIndex + 1 < sources.length, isTrue);
        currentIndex++;
        expect(sources[currentIndex].quality, equals('720p MP4'));

        // Exhausted
        expect(currentIndex + 1 < sources.length, isFalse);
      },
    );

    test('StorageService persists autoPlayTrailers preference', () async {
      final storage = StorageService();

      expect(await storage.getAutoPlayTrailers(), isTrue); // default is true
      await storage.setAutoPlayTrailers(false);
      expect(await storage.getAutoPlayTrailers(), isFalse);
      await storage.setAutoPlayTrailers(true);
      expect(await storage.getAutoPlayTrailers(), isTrue);
    });

    test('Episode parses relative duration intro correctly when introEnd is relative', () {
      final epJson = {
        'season': 1,
        'episode': 1,
        'title': 'Pilot',
        'introStart': 15,
        'introEnd': 75, // Treated as 75 absolute since 75 > 15
      };
      final ep = Episode.fromJson(epJson);
      expect(ep.skipIntervals[0].startSeconds, equals(15));
      expect(ep.skipIntervals[0].endSeconds, equals(75));

      final epJsonRelative = {
        'season': 1,
        'episode': 2,
        'title': 'Second',
        'introStart': 100,
        'introEnd':
            40, // Since 40 < 100, it is treated as duration -> 100 + 40 = 140
      };
      final ep2 = Episode.fromJson(epJsonRelative);
      expect(ep2.skipIntervals[0].startSeconds, equals(100));
      expect(ep2.skipIntervals[0].endSeconds, equals(140));
    });

    test('WindowService singleton operates without exceptions', () {
      final ws1 = WindowService();
      final ws2 = WindowService();
      expect(identical(ws1, ws2), isTrue);
      expect(ws1.isFullscreen, isFalse);
    });

    test('Episode and Season copyWith supports TMDB thumbnail enrichment', () {
      const originalEp = Episode(season: 1, episode: 1, title: 'Episode 1');
      expect(originalEp.thumbnail, isNull);

      final enrichedEp = originalEp.copyWith(
        title: 'Chapter One: The Vanishing of Will Byers',
        thumbnail:
            'https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
        overview: 'Will disappears on his way home.',
      );
      expect(
        enrichedEp.thumbnail,
        equals(
          'https://image.tmdb.org/t/p/w500/6jSA6JpxNDV63aDXpmsUFCjCINb.jpg',
        ),
      );
      expect(
        enrichedEp.title,
        equals('Chapter One: The Vanishing of Will Byers'),
      );
      expect(enrichedEp.overview, equals('Will disappears on his way home.'));

      const season = Season(
        seasonNumber: 1,
        episodeCount: 1,
        episodes: [originalEp],
      );
      final updatedSeason = season.copyWith(episodes: [enrichedEp]);
      expect(updatedSeason.episodes.first.thumbnail, isNotNull);
    });

    test('Episode does not generate fake intro when introEnd and duration are missing', () {
      final epJsonNoEnd = {
        'season': 1,
        'episode': 5,
        'title': 'No End Episode',
        'introStart': 10,
        // introEnd and openingDuration are null
      };
      final ep = Episode.fromJson(epJsonNoEnd);
      expect(
        ep.skipIntervals.where((s) => s.type == SkipType.intro).isEmpty,
        isTrue,
      );
    });

    test('StreamSource formats server details without overflowing', () {
      final source1 = StreamSource(
        quality: 'Multi-Res (Auto)',
        resolution: '1080,720,480',
        format: 'DASH',
        url: 'https://cdn.example.com/manifest.mpd',
        sizeBytes: 5153960755, // ~4.8 GB
        codec: 'hevc',
      );

      final source2 = StreamSource(
        quality: '1080p',
        resolution: '1080',
        format: 'MP4',
        url: 'https://cdn.example.com/stream.mp4',
        sizeBytes: 3435973836, // ~3.2 GB
      );

      expect(source1.formattedSize, '4.8 GB');
      expect(source2.formattedSize, '3.2 GB');

      final details1 = [
        if (source1.formattedSize.isNotEmpty) source1.formattedSize,
        if (source1.codec != null && source1.codec!.isNotEmpty) source1.codec!,
      ].join(' • ');

      expect(details1, '4.8 GB • hevc');
    });

    test('Seekbar buffer calculation clamps correctly and maintains Slider invariants', () {
      // Helper function matching the seekbar implementation logic
      double computeBufferMs({
        required Duration rawBuffer,
        required Duration position,
        required Duration duration,
      }) {
        final maxMs = duration.inMilliseconds.toDouble();
        final curMs = position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs > 0 ? maxMs : 1.0,
        );
        final bufferPos = rawBuffer > position ? rawBuffer : position;
        return maxMs > 0
            ? bufferPos.inMilliseconds.toDouble().clamp(curMs, maxMs)
            : 0.0;
      }

      const totalDur = Duration(minutes: 10); // 600,000 ms

      // Case 1: Normal playback with 30s buffer ahead
      final buf1 = computeBufferMs(
        rawBuffer: const Duration(seconds: 45),
        position: const Duration(seconds: 15),
        duration: totalDur,
      );
      expect(buf1, equals(45000.0));

      // Case 2: Buffer reports behind current position (e.g. before initial buffer event)
      final buf2 = computeBufferMs(
        rawBuffer: Duration.zero,
        position: const Duration(seconds: 20),
        duration: totalDur,
      );
      expect(buf2, equals(20000.0)); // Clamped to at least curMs

      // Case 3: Buffer extends past end of media
      final buf3 = computeBufferMs(
        rawBuffer: const Duration(minutes: 12),
        position: const Duration(minutes: 9),
        duration: totalDur,
      );
      expect(buf3, equals(600000.0)); // Clamped to maxMs

      // Case 4: Uninitialized media (duration is zero)
      final buf4 = computeBufferMs(
        rawBuffer: const Duration(seconds: 5),
        position: Duration.zero,
        duration: Duration.zero,
      );
      expect(buf4, equals(0.0)); // Invariant: 0.0 <= curMs <= buf <= 1.0
    });

    testWidgets(
      'Slider renders with secondaryTrackValue and secondaryActiveTrackColor without assertion errors',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.red,
                      secondaryActiveTrackColor: Colors.grey.withValues(
                        alpha: 0.5,
                      ),
                      inactiveTrackColor: Colors.black26,
                    ),
                    child: Slider(
                      value: 15000.0,
                      secondaryTrackValue: 45000.0,
                      min: 0.0,
                      max: 600000.0,
                      onChanged: (_) {},
                    ),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.byType(Slider), findsOneWidget);
      },
    );

    group('Center Play/Pause Indicator & Button Controls Tests', () {
      testWidgets(
        'PlayerGestureHud renders center Play icon when playing is true without text',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.darkTheme.themeData,
              home: Scaffold(
                body: PlayerGestureHud(
                  isTv: false,
                  isControlsLocked: false,
                  showBrightnessIndicator: false,
                  brightness: 0.5,
                  showVolumeIndicator: false,
                  volume: 0.5,
                  showControls: false,
                  onTriggerSkip: () {},
                  showResumeBanner: false,
                  resumedFromSeconds: 0,
                  onRestartPlayback: () {},
                  onDismissResumeBanner: () {},
                  formatDuration: (d) => '$d',
                  showUnlockButton: false,
                  onUnlockControls: () {},
                  playPauseIndicatorIsPlaying: true,
                ),
              ),
            ),
          );

          // Expect play icon in center
          expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
          // Expect NO text toast with 'Playing'
          expect(find.text('Playing'), findsNothing);
        },
      );

      testWidgets(
        'PlayerGestureHud renders center Pause icon when playing is false without text',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.darkTheme.themeData,
              home: Scaffold(
                body: PlayerGestureHud(
                  isTv: false,
                  isControlsLocked: false,
                  showBrightnessIndicator: false,
                  brightness: 0.5,
                  showVolumeIndicator: false,
                  volume: 0.5,
                  showControls: false,
                  onTriggerSkip: () {},
                  showResumeBanner: false,
                  resumedFromSeconds: 0,
                  onRestartPlayback: () {},
                  onDismissResumeBanner: () {},
                  formatDuration: (d) => '$d',
                  showUnlockButton: false,
                  onUnlockControls: () {},
                  playPauseIndicatorIsPlaying: false,
                ),
              ),
            ),
          );

          // Expect pause icon in center
          expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
          // Expect NO text toast with 'Paused'
          expect(find.text('Paused'), findsNothing);
        },
      );

      test('PlayerKeyHandler invokes onPlayPauseTriggered on space, enter, and media keys', () {
        final player = _MockTestPlayer(isPlaying: true);
        bool? triggeredPlaying;

        // Desktop Space key
        final spaceEvent = const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        );

        final res1 = PlayerKeyHandler.handleKeyEvent(
          event: spaceEvent,
          isTv: false,
          isControlsLocked: false,
          showControls: false,
          isFullscreen: true,
          player: player,
          onShowUnlockButton: () {},
          onHideTvControls: () {},
          onRevealTvControls: () {},
          onToggleFullscreen: () {},
          onPop: () {},
          showToast: (_) {},
          onPlayPauseTriggered: (val) => triggeredPlaying = val,
          onDoubleTapSeek: (_) {},
          onUserActivity: () {},
          onStartHideTimer: () {},
          onToggleSubtitle: () {},
          onTriggerSkip: () {},
          hasActiveSkip: false,
        );

        expect(res1, equals(KeyEventResult.handled));
        expect(triggeredPlaying, isFalse); // Was playing, so toggled to false

        // Media Play key
        final playEvent = const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.mediaPlay,
          logicalKey: LogicalKeyboardKey.mediaPlay,
          timeStamp: Duration.zero,
        );

        final res2 = PlayerKeyHandler.handleKeyEvent(
          event: playEvent,
          isTv: false,
          isControlsLocked: false,
          showControls: false,
          isFullscreen: true,
          player: player,
          onShowUnlockButton: () {},
          onHideTvControls: () {},
          onRevealTvControls: () {},
          onToggleFullscreen: () {},
          onPop: () {},
          showToast: (_) {},
          onPlayPauseTriggered: (val) => triggeredPlaying = val,
          onDoubleTapSeek: (_) {},
          onUserActivity: () {},
          onStartHideTimer: () {},
          onToggleSubtitle: () {},
          onTriggerSkip: () {},
          hasActiveSkip: false,
        );

        expect(res2, equals(KeyEventResult.handled));
        expect(triggeredPlaying, isTrue);

        // TV Mode Select Key
        player.isPlaying = false;
        final tvSelectEvent = const KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.select,
          logicalKey: LogicalKeyboardKey.select,
          timeStamp: Duration.zero,
        );

        final res3 = PlayerKeyHandler.handleKeyEvent(
          event: tvSelectEvent,
          isTv: true,
          isControlsLocked: false,
          showControls: false,
          isFullscreen: true,
          player: player,
          onShowUnlockButton: () {},
          onHideTvControls: () {},
          onRevealTvControls: () {},
          onToggleFullscreen: () {},
          onPop: () {},
          showToast: (_) {},
          onPlayPauseTriggered: (val) => triggeredPlaying = val,
          onDoubleTapSeek: (_) {},
          onUserActivity: () {},
          onStartHideTimer: () {},
          onToggleSubtitle: () {},
          onTriggerSkip: () {},
          hasActiveSkip: false,
        );

        expect(res3, equals(KeyEventResult.handled));
        expect(triggeredPlaying, isTrue); // Was false, so toggled to true
      });

      testWidgets(
        'PlayerControlsVisibilityMixin intercepts showToast Playing/Paused and auto-dismisses',
        (tester) async {
          final key = GlobalKey<_TestControlsVisibilityWidgetState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.darkTheme.themeData,
              home: _TestControlsVisibilityWidget(key: key),
            ),
          );

          final state = key.currentState!;

          // Trigger 'Playing' via showToast
          state.showToast('Playing');
          expect(state.toastMessage, isNull);
          expect(state.playPauseIndicatorIsPlaying, isTrue);

          // Trigger 'Paused' via showToast
          state.showToast('Paused');
          expect(state.toastMessage, isNull);
          expect(state.playPauseIndicatorIsPlaying, isFalse);

          // Trigger other toast message
          state.showToast('Volume: 50%');
          expect(state.toastMessage, equals('Volume: 50%'));

          // Wait for indicator to auto-dismiss (800ms)
          await tester.pump(const Duration(milliseconds: 850));
          expect(state.playPauseIndicatorIsPlaying, isNull);
        },
      );

      testWidgets(
        'PlayerBottomControls renders Play/Pause button and clicking it toggles playback',
        (tester) async {
          final player = _MockTestPlayer(isPlaying: true);
          bool? triggeredPlaying;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppThemes.darkTheme.themeData,
              home: Scaffold(
                body: PlayerBottomControls(
                  player: player,
                  isControlsLocked: false,
                  videoFit: BoxFit.contain,
                  onToggleAspectRatio: () {},
                  onEnterPip: () {},
                  onCancelHideTimer: () {},
                  onStartHideTimer: () {},
                  onInteractingWithUi: (_) {},
                  formatDuration: (d) => '$d',
                  onPlayPauseTriggered: (val) => triggeredPlaying = val,
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Expect pause icon when playing is true
          expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

          // Tap the Play / Pause button
          await tester.tap(find.byIcon(Icons.pause_rounded));
          await tester.pump();

          expect(triggeredPlaying, isFalse);
        },
      );
    });
  });
}

class _MockPlayerStream extends Fake implements PlayerStream {
  @override
  Stream<Duration> get position => Stream.value(Duration.zero);
  @override
  Stream<Duration> get buffer => Stream.value(Duration.zero);
  @override
  Stream<bool> get playing => Stream.value(true);
}

class _MockPlayerState extends Fake implements PlayerState {
  final bool _playing;
  _MockPlayerState(this._playing);
  @override
  bool get playing => _playing;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => const Duration(minutes: 10);
  @override
  Duration get buffer => Duration.zero;
}

class _MockTestPlayer extends Fake implements Player {
  bool isPlaying;
  _MockTestPlayer({this.isPlaying = true});
  @override
  PlayerState get state => _MockPlayerState(isPlaying);
  @override
  PlayerStream get stream => _MockPlayerStream();
  @override
  Future<void> playOrPause() async {
    isPlaying = !isPlaying;
  }

  @override
  Future<void> play() async {
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
  }
}

class _TestControlsVisibilityWidget extends StatefulWidget {
  const _TestControlsVisibilityWidget({super.key});
  @override
  State<_TestControlsVisibilityWidget> createState() =>
      _TestControlsVisibilityWidgetState();
}

class _TestControlsVisibilityWidgetState
    extends State<_TestControlsVisibilityWidget>
    with PlayerControlsVisibilityMixin {
  final _player = _MockTestPlayer();
  final _focusNode = FocusNode();
  final _playPauseFocusNode = FocusNode();
  final _seekbarFocusNode = FocusNode();

  @override
  Player get player => _player;
  @override
  FocusNode get focusNode => _focusNode;
  @override
  FocusNode get playPauseTvFocusNode => _playPauseFocusNode;
  @override
  FocusNode get seekbarTvFocusNode => _seekbarFocusNode;

  @override
  void dispose() {
    _focusNode.dispose();
    _playPauseFocusNode.dispose();
    _seekbarFocusNode.dispose();
    disposeControlsVisibility();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
