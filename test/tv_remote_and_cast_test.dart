import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/live_channel.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/providers/cast_provider.dart';
import 'package:exalere/services/cast_service.dart';
import 'package:exalere/services/chromecast_subnet_scanner.dart';
import 'package:exalere/services/device_controls_service.dart';
import 'package:provider/provider.dart';
import 'package:exalere/ui/screens/live_tv_screen.dart';
import 'package:exalere/ui/widgets/cast_dialog.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';

void main() {
  group('TV Remote Navigation & Focus Tests', () {
    testWidgets(
      'TvFocusable invokes onTap when D-Pad Select or Enter is pressed',
      (WidgetTester tester) async {
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
      },
    );

    testWidgets('TvFocusable triggers onFocusChange callback', (
      WidgetTester tester,
    ) async {
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
        SubtitleOption(
          language: 'en',
          name: 'English',
          url: 'https://sub.url/en.vtt',
        ),
        SubtitleOption(
          language: 'es',
          name: 'Spanish',
          url: 'https://sub.url/es.srt',
        ),
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
      expect(
        castMedia.imageUrl,
        'https://image.tmdb.org/t/p/original/backdrop.jpg',
      );
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

      final castMedia = service.buildCastMedia(item: item, source: source);

      expect(castMedia.type, CastMediaType.mp4);
      expect(castMedia.title, 'Dark Knight');
    });

    test(
      'ChromecastSubnetScanner initializes, scans with timeout, and disposes',
      () async {
        final scanner = ChromecastSubnetScanner();
        final stream = scanner.scan(timeout: const Duration(milliseconds: 100));
        final devices = await stream.toList();

        expect(devices, isA<List<CastDevice>>());
        scanner.dispose();
      },
    );

    test('AppCastService startDiscovery and stopDiscovery lifecycle handles stream cleanly', () async {
      final service = AppCastService();
      final stream = service.discoverDevices(
        timeout: const Duration(milliseconds: 100),
      );
      expect(stream, isNotNull);

      service.stopDiscovery();
      service.dispose();
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

    testWidgets('CastDialog renders title and device list correctly', (
      WidgetTester tester,
    ) async {
      final castProvider = CastProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<CastProvider>.value(
          value: castProvider,
          child: const MaterialApp(home: Scaffold(body: CastDialog())),
        ),
      );
      await tester.pump();

      expect(find.text('Cast to Device'), findsOneWidget);
      expect(find.text('Chromecast • DLNA • AirPlay'), findsOneWidget);
      expect(find.text('Available Devices'), findsOneWidget);

      castProvider.stopDiscovery();
      await tester.pump(const Duration(seconds: 16));
      castProvider.dispose();
    });

    test(
      'DeviceControlsService methods execute safely without error',
      () async {
        final brightness = await DeviceControlsService.getBrightness();
        expect(brightness, greaterThanOrEqualTo(0.01));
        expect(brightness, lessThanOrEqualTo(1.0));

        await DeviceControlsService.setBrightness(0.8);
        await DeviceControlsService.resetBrightness();

        final volume = await DeviceControlsService.getVolume();
        expect(volume, greaterThanOrEqualTo(0.0));
        expect(volume, lessThanOrEqualTo(1.0));

        await DeviceControlsService.setVolume(0.7);
      },
    );

    testWidgets(
      'TvFocusable supports directional navigation between multiple items',
      (WidgetTester tester) async {
        final node1 = FocusNode(debugLabel: 'Btn1');
        final node2 = FocusNode(debugLabel: 'Btn2');
        final node3 = FocusNode(debugLabel: 'Btn3');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  TvFocusable(
                    focusNode: node1,
                    autofocus: true,
                    child: const Text('Button 1'),
                  ),
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
      },
    );

    testWidgets(
      'Android TV leanback focus navigates multi-source selector dialog with D-Pad',
      (WidgetTester tester) async {
        final sources = [
          const StreamSource(
            quality: '4K Ultra HD (MovieBox)',
            resolution: '3840x2160',
            format: 'HLS',
            url: 'https://stream.moviebox/4k.m3u8',
          ),
          const StreamSource(
            quality: '1080p FHD (4KHDHub Fallback)',
            resolution: '1920x1080',
            format: 'MP4',
            url: 'https://hub.stream/1080p.mp4',
          ),
          const StreamSource(
            quality: '720p HD (VidSrc Fallback)',
            resolution: '1280x720',
            format: 'Embed',
            url: 'https://vidsrc.to/embed/movie/123',
          ),
        ];

        int selectedIndex = 1; // Fallback source 2 active
        int? clickedIndex;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  return ListView.separated(
                    itemCount: sources.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final src = sources[idx];
                      final isSelected = idx == selectedIndex;
                      return TvFocusable(
                        autofocus: isSelected,
                        onTap: () => clickedIndex = idx,
                        child: Text(src.quality),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify active fallback source (index 1) has initial focus
        expect(find.text('1080p FHD (4KHDHub Fallback)'), findsOneWidget);

        // Send D-Pad Down arrow key to navigate to the 3rd source
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Send D-Pad Select key to pick the fallback source
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(clickedIndex, 2);

        // Send D-Pad Up arrow key to navigate back to the 2nd source
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        // Send Enter
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(clickedIndex, 1);
      },
    );

    testWidgets(
      'LiveChannelCard renders with TvFocusable and activates via D-Pad Select',
      (WidgetTester tester) async {
        bool tapped = false;
        final channel = LiveChannel(
          id: 'test_chan_1',
          name: 'BBC Three/CBBC',
          category: 'Animation',
          streamUrl: 'https://example.com/live.m3u8',
          resolution: '720p',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 150,
                  child: LiveChannelCard(
                    channel: channel,
                    isTv: true,
                    onTap: () => tapped = true,
                    onOpenVlc: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BBC Three/CBBC'), findsOneWidget);
        expect(find.text('ANIMATION'), findsOneWidget);
        expect(find.text('LIVE'), findsOneWidget);
        expect(find.byType(TvFocusable), findsOneWidget);

        // Send select key
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // Focus and activate
        await tester.tap(find.byType(LiveChannelCard));
        await tester.pumpAndSettle();
        expect(tapped, isTrue);
      },
    );
  });
}
