import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/ui/screens/player/player_server_sheet.dart';
import 'package:exalere/ui/theme/app_themes.dart';

void main() {
  group('PlayerServerDialog & PlayerQualityDialog Tests', () {
    testWidgets(
      'PlayerServerDialog renders providers and selects single-stream provider',
      (tester) async {
        int? selectedIdx;

        const sources = [
          StreamSource(
            quality: '1080p',
            resolution: '1920x1080',
            format: 'DASH',
            url: 'https://example.com/s1.mpd',
            server: 'MovieBox Primary',
            providerName: 'MovieBox Engine',
          ),
          StreamSource(
            quality: '1080p',
            resolution: '1920x1080',
            format: 'HLS',
            url: 'https://example.com/s2.m3u8',
            server: '4KHDHub Backup',
            providerName: '4K HD Hub',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerDialog(
                sources: sources,
                currentSourceIndex: 0,
                onSourceSelected: (idx) => selectedIdx = idx,
              ),
            ),
          ),
        );

        // Header & provider names must be present
        expect(find.text('Select Provider'), findsOneWidget);
        expect(find.text('MovieBox Engine'), findsOneWidget);
        expect(find.text('4K HD Hub'), findsOneWidget);

        // Video Quality options must NOT be present
        expect(find.text('Video Quality'), findsNothing);
        expect(find.text('Auto (Adaptive Bitrate)'), findsNothing);

        // Tap second provider (single stream -> immediately selects)
        await tester.tap(find.text('4K HD Hub'));
        await tester.pumpAndSettle();

        expect(selectedIdx, equals(1));
      },
    );

    testWidgets(
      'PlayerServerDialog drills down into multi-stream provider and supports back navigation',
      (tester) async {
        int? selectedIdx;

        const sources = [
          StreamSource(
            quality: '4K',
            resolution: '3840x2160',
            format: 'MKV',
            url: 'https://example.com/4k.mkv',
            server: 'Cloudflare R2 (4K)',
            providerName: '4K HD Hub',
          ),
          StreamSource(
            quality: '1080p',
            resolution: '1920x1080',
            format: 'MKV',
            url: 'https://example.com/1080p.mkv',
            server: 'Cloudflare R2 (1080p)',
            providerName: '4K HD Hub',
          ),
          StreamSource(
            quality: '1080p',
            resolution: '1920x1080',
            format: 'MP4',
            url: 'https://example.com/mb.mp4',
            server: 'MovieBox Stream',
            providerName: 'MovieBox Engine',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerDialog(
                sources: sources,
                currentSourceIndex: 0,
                onSourceSelected: (idx) => selectedIdx = idx,
              ),
            ),
          ),
        );

        // In Step 1: Providers view
        expect(find.text('Select Provider'), findsOneWidget);
        expect(find.text('4K HD Hub'), findsOneWidget);
        expect(find.text('2 streams'), findsOneWidget);
        expect(find.text('MovieBox Engine'), findsOneWidget);

        // Tap 4K HD Hub (has 2 streams -> drills down to Step 2)
        await tester.tap(find.text('4K HD Hub'));
        await tester.pumpAndSettle();

        // Step 2: Streams view for 4K HD Hub
        expect(find.text('Cloudflare R2 (4K)'), findsOneWidget);
        expect(find.text('Cloudflare R2 (1080p)'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        // Test back button navigation
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // Should return to Step 1
        expect(find.text('Select Provider'), findsOneWidget);

        // Drill down again and select the second stream (index 1)
        await tester.tap(find.text('4K HD Hub'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cloudflare R2 (1080p)'));
        await tester.pumpAndSettle();

        expect(selectedIdx, equals(1));
      },
    );

    testWidgets(
      'PlayerQualityDialog renders ONLY quality options and triggers onVideoTrackSelected',
      (tester) async {
        VideoTrack? selectedTrack;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerQualityDialog(
                videoTracks: const [],
                fallbackQualities: const ['1080p', '720p', '480p'],
                currentQuality: 'Auto (Up to 1080p)',
                onVideoTrackSelected: (t) => selectedTrack = t,
              ),
            ),
          ),
        );

        // Header & quality tiers must be present
        expect(find.text('Video Quality'), findsOneWidget);
        expect(find.text('Auto (Adaptive Bitrate)'), findsOneWidget);
        expect(find.text('1080p'), findsOneWidget);
        expect(find.text('720p'), findsOneWidget);
        expect(find.text('480p'), findsOneWidget);

        // Streaming Servers must NOT be present
        expect(find.text('Streaming Servers'), findsNothing);

        // Tap 720p tile
        await tester.tap(find.text('720p'));
        await tester.pumpAndSettle();

        expect(selectedTrack, isNotNull);
        expect(selectedTrack!.h, equals(720));
      },
    );

    testWidgets(
      'PlayerQualityDialog Selecting Auto option triggers onVideoTrackSelected with VideoTrack.auto()',
      (tester) async {
        VideoTrack? selectedTrack;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerQualityDialog(
                videoTracks: const [],
                fallbackQualities: const ['1080p', '720p', '480p'],
                currentQuality: 'Auto (Up to 1080p)',
                onVideoTrackSelected: (t) => selectedTrack = t,
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
      'PlayerQualityDialog renders genuine demuxer video tracks when multiple tracks are provided',
      (tester) async {
        VideoTrack? selectedTrack;

        const tracks = [
          VideoTrack('1', '1080p FHD', null, w: 1920, h: 1080),
          VideoTrack('2', '720p HD', null, w: 1280, h: 720),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerQualityDialog(
                videoTracks: tracks,
                fallbackQualities: const ['1080p', '720p'],
                currentQuality: '1080p',
                onVideoTrackSelected: (t) => selectedTrack = t,
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

    testWidgets(
      'PlayerServerSheet facade delegates to respective dialog based on initialSection',
      (tester) async {
        const source = StreamSource(
          quality: '1080p',
          resolution: '1920x1080',
          format: 'DASH',
          url: 'https://example.com/manifest.mpd',
          server: 'Test Server',
          availableQualities: ['1080p', '720p'],
        );

        // 1. When initialSection is quality -> renders quality dialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerSheet(
                sources: const [source],
                currentSourceIndex: 0,
                onSourceSelected: (_) {},
                onVideoTrackSelected: (_) {},
                initialSection: PlayerServerSheetSection.quality,
              ),
            ),
          ),
        );

        expect(find.text('Video Quality'), findsOneWidget);
        expect(find.text('Select Provider'), findsNothing);

        // 2. When initialSection is servers -> renders server dialog
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: PlayerServerSheet(
                sources: const [source],
                currentSourceIndex: 0,
                onSourceSelected: (_) {},
                initialSection: PlayerServerSheetSection.servers,
              ),
            ),
          ),
        );

        expect(find.text('Select Provider'), findsOneWidget);
        expect(find.text('Test Server'), findsOneWidget);
      },
    );
  });
}
