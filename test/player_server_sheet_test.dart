import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/ui/screens/player/player_server_sheet.dart';
import 'package:exalere/ui/theme/app_themes.dart';

void main() {
  group('PlayerServerSheet Tests', () {
    testWidgets(
      'Renders fallback multi-resolution options when videoTracks is empty',
      (tester) async {
        VideoTrack? selectedTrack;

        const source = StreamSource(
          quality: 'Auto (Up to 1080p)',
          resolution: '1080p • 720p • 480p',
          format: 'DASH',
          url: 'https://example.com/manifest.mpd',
          availableQualities: ['1080p', '720p', '480p'],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerSheet(
                sources: const [source],
                currentSourceIndex: 0,
                onSourceSelected: (_) {},
                videoTracks: const [],
                onVideoTrackSelected: (t) => selectedTrack = t,
                initialSection: PlayerServerSheetSection.quality,
              ),
            ),
          ),
        );

        expect(find.text('Auto (Adaptive Bitrate)'), findsOneWidget);
        expect(find.text('1080p'), findsOneWidget);
        expect(find.text('720p'), findsOneWidget);
        expect(find.text('480p'), findsOneWidget);

        // Tap 720p tile
        await tester.tap(find.text('720p'));
        await tester.pumpAndSettle();

        expect(selectedTrack, isNotNull);
        expect(selectedTrack!.h, equals(720));
      },
    );

    testWidgets(
      'Selecting Auto option triggers onVideoTrackSelected with VideoTrack.auto()',
      (tester) async {
        VideoTrack? selectedTrack;

        const source = StreamSource(
          quality: 'Auto (Up to 1080p)',
          resolution: '1080p • 720p • 480p',
          format: 'DASH',
          url: 'https://example.com/manifest.mpd',
          availableQualities: ['1080p', '720p', '480p'],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerSheet(
                sources: const [source],
                currentSourceIndex: 0,
                onSourceSelected: (_) {},
                videoTracks: const [],
                onVideoTrackSelected: (t) => selectedTrack = t,
                initialSection: PlayerServerSheetSection.quality,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Auto (Adaptive Bitrate)'));
        await tester.pumpAndSettle();

        expect(selectedTrack, isNotNull);
        expect(selectedTrack!.id, equals('auto'));
      },
    );

    testWidgets(
      'Renders genuine demuxer video tracks when multiple tracks are provided',
      (tester) async {
        VideoTrack? selectedTrack;

        const source = StreamSource(
          quality: 'Auto (Up to 1080p)',
          resolution: '1080p • 720p',
          format: 'DASH',
          url: 'https://example.com/manifest.mpd',
          availableQualities: ['1080p', '720p'],
        );

        const tracks = [
          VideoTrack('1', '1080p FHD', null, w: 1920, h: 1080),
          VideoTrack('2', '720p HD', null, w: 1280, h: 720),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerSheet(
                sources: const [source],
                currentSourceIndex: 0,
                onSourceSelected: (_) {},
                videoTracks: tracks,
                onVideoTrackSelected: (t) => selectedTrack = t,
                initialSection: PlayerServerSheetSection.quality,
              ),
            ),
          ),
        );

        expect(find.text('1080p (1920×1080)'), findsOneWidget);
        expect(find.text('720p (1280×720)'), findsOneWidget);

        await tester.tap(find.text('720p (1280×720)'));
        await tester.pumpAndSettle();

        expect(selectedTrack, isNotNull);
        expect(selectedTrack!.id, equals('2'));
      },
    );
  });
}
