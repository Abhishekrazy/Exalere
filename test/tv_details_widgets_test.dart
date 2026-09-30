import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/tmdb_service.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/tv/tv_details_header.dart';
import 'package:exalere/ui/widgets/tv/tv_description_dialog.dart';
import 'package:exalere/ui/widgets/tv/tv_cast_shelf.dart';

void main() {
  const testMediaItem = MediaItem(
    id: '12345',
    title: 'Interstellar',
    year: '2014',
    posterUrl: 'https://image.tmdb.org/t/p/w500/test.jpg',
    mediaType: MediaType.movie,
    rating: 8.7,
  );

  const testCast = [
    TmdbCastMember(id: 1, name: 'Matthew McConaughey', character: 'Cooper'),
    TmdbCastMember(id: 2, name: 'Anne Hathaway', character: 'Brand'),
  ];

  group('TvDetailsHeader Widget Tests', () {
    testWidgets(
      'renders title, tagline, genres, runtime, overview, and cast info',
      (tester) async {
        bool fullDetailsOpened = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.darkTheme.themeData,
            home: Scaffold(
              body: TvDetailsHeader(
                title: 'Interstellar',
                year: '2014',
                ageCert: 'PG-13',
                rating: '8.7',
                isSeries: false,
                overview:
                    'A team of explorers travel through a wormhole in space.',
                tagline:
                    'Mankind was born on Earth. It was never meant to die here.',
                genres: const ['Adventure', 'Drama', 'Sci-Fi'],
                runtime: '2h 49m',
                director: 'Christopher Nolan',
                cast: const [
                  'Matthew McConaughey',
                  'Anne Hathaway',
                  'Jessica Chastain',
                ],
                onOpenFullDetails: () => fullDetailsOpened = true,
              ),
            ),
          ),
        );

        // Verify title & tagline
        expect(find.text('Interstellar'), findsOneWidget);
        expect(
          find.text(
            '“Mankind was born on Earth. It was never meant to die here.”',
          ),
          findsOneWidget,
        );

        // Verify metadata chips
        expect(find.text('2014'), findsOneWidget);
        expect(find.text('PG-13'), findsOneWidget);
        expect(find.text('8.7'), findsOneWidget);
        expect(find.text('MOVIE'), findsOneWidget);
        expect(find.text('2h 49m'), findsOneWidget);
        expect(find.text('Adventure'), findsOneWidget);
        expect(find.text('Drama'), findsOneWidget);
        expect(find.text('Sci-Fi'), findsOneWidget);

        // Verify overview
        expect(
          find.text('A team of explorers travel through a wormhole in space.'),
          findsOneWidget,
        );

        // Verify starring & director
        expect(
          find.textContaining('Matthew McConaughey', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Christopher Nolan', findRichText: true),
          findsOneWidget,
        );

        // Verify full details button
        expect(find.text('Full Details & Synopsis'), findsOneWidget);

        // Tap full details button
        await tester.tap(find.text('Full Details & Synopsis'));
        await tester.pump();
        expect(fullDetailsOpened, isTrue);
      },
    );
  });

  group('TvDescriptionDialog Widget Tests', () {
    testWidgets('renders full synopsis, metadata badges, director and cast', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.darkTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  TvDescriptionDialog.show(
                    context,
                    mediaItem: testMediaItem,
                    title: 'Interstellar',
                    year: '2014',
                    ageCert: 'PG-13',
                    rating: '8.7',
                    runtime: '2h 49m',
                    tagline: 'Mankind was born on Earth.',
                    overview:
                        'When Earth becomes uninhabitable in the future, a farmer and ex-NASA pilot is tasked with piloting a spacecraft along with a team of researchers to find a new planet for humans.',
                    genres: const ['Sci-Fi', 'Drama'],
                    director: 'Christopher Nolan',
                    cast: testCast,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('SYNOPSIS'), findsOneWidget);
      expect(
        find.textContaining('When Earth becomes uninhabitable'),
        findsOneWidget,
      );
      expect(find.text('Christopher Nolan'), findsOneWidget);
      expect(
        find.textContaining('Matthew McConaughey', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('as Cooper', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);

      // Tap Close
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('SYNOPSIS'), findsNothing);
    });
  });

  group('TvCastShelf Widget Tests', () {
    testWidgets('renders cast cards with actor and character names', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.darkTheme.themeData,
          home: const Scaffold(body: TvCastShelf(cast: testCast)),
        ),
      );

      expect(find.text('Cast & Crew'), findsOneWidget);
      expect(find.text('Matthew McConaughey'), findsOneWidget);
      expect(find.text('Cooper'), findsOneWidget);
      expect(find.text('Anne Hathaway'), findsOneWidget);
      expect(find.text('Brand'), findsOneWidget);
    });
  });
}
