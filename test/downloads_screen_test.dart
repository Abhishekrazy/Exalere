import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/services/direct_stream_service.dart';
import 'package:exalere/ui/screens/downloads_screen.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/downloads/download_task_card.dart';

VideoDownloadTask _task({
  DownloadTaskStatus status = DownloadTaskStatus.downloading,
  double progress = 0.42,
  String fileName = 'Dune.2021.1080p.mkv',
  String? mediaTitle = 'Dune',
  int? season,
  int? episode,
  String? quality = '1080p',
  double speed = 2 * 1024 * 1024,
  String? error,
}) {
  return VideoDownloadTask(
    id: 't1',
    url: 'https://cdn.example/dune.mkv',
    title: 'Dune.2021.1080p.mkv',
    fileName: fileName,
    filePath: '/downloads/$fileName',
    totalBytes: 1000 * 1024 * 1024,
    receivedBytes: (1000 * 1024 * 1024 * progress).round(),
    progress: progress,
    speedBytesPerSec: speed,
    status: status,
    errorMessage: error,
    startedAt: DateTime(2026, 1, 1),
    mediaTitle: mediaTitle,
    season: season,
    episode: episode,
    quality: quality,
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppThemes.netflixBlack.themeData,
    home: Scaffold(body: child),
  );
}

void main() {
  group('DownloadTaskCard', () {
    testWidgets('names the show/movie, the episode, and the actual file', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(DownloadTaskCard(task: _task(season: 2, episode: 4))),
      );

      // The show/movie name, not the raw file name, is the heading.
      expect(find.text('Dune'), findsOneWidget);
      // Episode + quality line.
      expect(find.text('S2E4 · 1080p'), findsOneWidget);
      // The playable file on disk must be visible.
      expect(find.text('Dune.2021.1080p.mkv'), findsOneWidget);
    });

    testWidgets('shows progress, size, speed and a status chip', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(DownloadTaskCard(task: _task())));

      expect(find.text('Downloading'), findsOneWidget);
      // Percentage, total size, speed, and an ETA, joined into one line.
      expect(find.textContaining('42.0%'), findsOneWidget);
      expect(find.textContaining('2.0 MB/s'), findsOneWidget);
      expect(find.textContaining('left'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('a downloading row offers Pause and Cancel', (tester) async {
      await tester.pumpWidget(_wrap(DownloadTaskCard(task: _task())));

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // No Watch while the file is incomplete: a partial file is not playable.
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('a paused row offers Resume', (tester) async {
      await tester.pumpWidget(
        _wrap(DownloadTaskCard(task: _task(status: DownloadTaskStatus.paused))),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('a failed row offers Retry and surfaces the error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTaskCard(
            task: _task(
              status: DownloadTaskStatus.failed,
              error: 'HTTP 403 from the server',
            ),
          ),
        ),
      );

      expect(find.text('Failed'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text('HTTP 403 from the server'), findsOneWidget);
    });

    testWidgets('a completed row offers Watch for the finished file', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTaskCard(
            task: _task(status: DownloadTaskStatus.completed, progress: 1.0),
            onWatch: () {},
            onDeleteFile: () {},
          ),
        ),
      );

      expect(find.text('Downloaded'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      // A finished download has no progress bar to show.
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('falls back to the file name when no media title is known', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DownloadTaskCard(task: _task(mediaTitle: null, fileName: 'clip.mp4')),
        ),
      );

      expect(find.textContaining('clip.mp4'), findsWidgets);
    });
  });

  group('DownloadsScreen', () {
    testWidgets('shows an empty state when nothing is downloading or saved', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppProvider(),
          child: _wrap(DownloadsScreen(fileLoader: () async => [])),
        ),
      );
      // DirectStreamService emits periodic speed updates, so the screen never
      // goes fully idle; pump a bounded number of frames instead of settling.
      await tester.pump();
      // The disk scan is async and the service also emits periodic updates, so
      // pump a bounded number of frames instead of waiting to settle.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('No downloads yet'), findsOneWidget);
    });

    testWidgets('lists a file found on disk with a way to play it', (
      tester,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppProvider(),
          child: _wrap(
            DownloadsScreen(
              fileLoader: () async => [
                DownloadedVideoFile(
                  path: '/storage/downloads/Movie.2024.mkv',
                  fileName: 'Movie.2024.mkv',
                  sizeBytes: 100 * 1024 * 1024,
                  modifiedAt: DateTime(2026, 1, 1),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Movie.2024.mkv'), findsOneWidget);
      expect(find.textContaining('100.0 MB'), findsOneWidget);
      // The row must offer playback of the local file.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders a heading with the file count', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppProvider(),
          child: _wrap(DownloadsScreen(fileLoader: () async => [])),
        ),
      );
      await tester.pump();
      // The disk scan is async and the service also emits periodic updates, so
      // pump a bounded number of frames instead of waiting to settle.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      // Count comes from the real service in this environment, which has no
      // files, so it must read 0 rather than crash or spin forever.
      expect(find.textContaining('on device'), findsOneWidget);
    });
  });
}
