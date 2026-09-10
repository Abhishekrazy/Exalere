import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/providers/cast_provider.dart';
import 'package:exalere/services/cast_service.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';

void main() {
  group('TV Remote Navigation & Focus Tests', () {
    testWidgets('TvFocusable invokes onTap when D-Pad Select or Enter is pressed', (WidgetTester tester) async {
      bool tapped = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              focusNode: focusNode,
              onTap: () => tapped = true,
              child: const Text('TV Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('TV Card Content'), findsOneWidget);

      // Focus the widget
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);

      // Send D-Pad Center / Select key event
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(tapped, isTrue);

      // Reset and send Enter key event
      tapped = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(tapped, isTrue);

      // Reset and send Gamepad A key event
      tapped = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
      await tester.pump();

      expect(tapped, isTrue);

      focusNode.dispose();
    });

    testWidgets('TvFocusable triggers onFocusChange callback', (WidgetTester tester) async {
      bool? focusedState;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TvFocusable(
              focusNode: focusNode,
              onFocusChange: (f) => focusedState = f,
              child: const Text('Focus Test'),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusedState, isTrue);

      focusNode.unfocus();
      await tester.pump();
      expect(focusedState, isFalse);

      focusNode.dispose();
    });
  });

  group('Casting & CastService Tests', () {
    test('AppCastService buildCastMedia injects MovieBox HTTP headers and identifies HLS', () {
      final service = AppCastService();
      final item = MediaItem(
        id: 'test-1',
        title: 'Interstellar',
        mediaType: MediaType.movie,
        backdropUrl: 'https://image.tmdb.org/t/p/original/backdrop.jpg',
      );

      const source = StreamSource(
        quality: '1080p',
        resolution: '1920x1080',
        format: 'HLS',
        url: 'https://stream.moviebox.ph/manifest.m3u8',
        headers: {
          'User-Agent': 'MovieBox/1.0',
          'Referer': 'https://moviebox.ph/',
        },
      );

      const subtitles = [
        SubtitleOption(language: 'en', name: 'English', url: 'https://sub.url/en.vtt'),
        SubtitleOption(language: 'es', name: 'Spanish', url: 'https://sub.url/es.srt'),
      ];

      final castMedia = service.buildCastMedia(
        item: item,
        source: source,
        startPosition: const Duration(seconds: 120),
        subtitles: subtitles,
      );

      expect(castMedia.url, 'https://stream.moviebox.ph/manifest.m3u8');
      expect(castMedia.type, CastMediaType.hls);
      expect(castMedia.title, 'Interstellar');
      expect(castMedia.imageUrl, 'https://image.tmdb.org/t/p/original/backdrop.jpg');
      expect(castMedia.httpHeaders['User-Agent'], 'MovieBox/1.0');
      expect(castMedia.httpHeaders['Referer'], 'https://moviebox.ph/');
      expect(castMedia.startPosition, const Duration(seconds: 120));
      expect(castMedia.subtitles.length, 2);
      expect(castMedia.subtitles.first.label, 'English');
      expect(castMedia.subtitles.first.format, 'vtt');
      expect(castMedia.subtitles.last.format, 'srt');
    });

    test('AppCastService buildCastMedia detects MP4 correctly', () {
      final service = AppCastService();
      final item = MediaItem(
        id: 'test-2',
        title: 'Dark Knight',
        mediaType: MediaType.movie,
      );

      const source = StreamSource(
        quality: '720p',
        resolution: '1280x720',
        format: 'MP4',
        url: 'https://stream.cdn/video.mp4',
        headers: {},
      );

      final castMedia = service.buildCastMedia(
        item: item,
        source: source,
      );

      expect(castMedia.type, CastMediaType.mp4);
      expect(castMedia.title, 'Dark Knight');
    });

    test('CastProvider initializes with default disconnected state', () {
      final provider = CastProvider();

      expect(provider.isConnected, isFalse);
      expect(provider.isCasting, isFalse);
      expect(provider.isPlaying, isFalse);
      expect(provider.connectedDevice, isNull);
      expect(provider.discoveredDevices, isEmpty);
      expect(provider.sessionState, SessionState.disconnected);
      expect(provider.position, Duration.zero);
      expect(provider.duration, Duration.zero);

      provider.dispose();
    });

    testWidgets('TvFocusable supports directional navigation between multiple items', (WidgetTester tester) async {
      final node1 = FocusNode(debugLabel: 'Btn1');
      final node2 = FocusNode(debugLabel: 'Btn2');
      final node3 = FocusNode(debugLabel: 'Btn3');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                TvFocusable(focusNode: node1, autofocus: true, child: const Text('Button 1')),
                TvFocusable(focusNode: node2, child: const Text('Button 2')),
                TvFocusable(focusNode: node3, child: const Text('Button 3')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(node1.hasFocus, isTrue);
      expect(node2.hasFocus, isFalse);

      // Send Right arrow key event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(node1.hasFocus, isFalse);
      expect(node2.hasFocus, isTrue);

      // Send Right arrow key event again
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(node2.hasFocus, isFalse);
      expect(node3.hasFocus, isTrue);

      // Send Left arrow key event
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(node2.hasFocus, isTrue);
      expect(node3.hasFocus, isFalse);

      node1.dispose();
      node2.dispose();
      node3.dispose();
    });
  });
}
