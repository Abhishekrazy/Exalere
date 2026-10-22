import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/details/details_related_section.dart';

MediaItem _item(String id, String title) => MediaItem(
  id: id,
  title: title,
  mediaType: MediaType.movie,
  year: '2021',
  posterUrl: 'https://image.tmdb.org/t/p/w500/$id.jpg',
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppThemes.netflixBlack.themeData,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('DetailsRelatedSection', () {
    testWidgets('renders nothing when there are no related titles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: const [],
            screenWidth: 400,
            onItemTap: (_) {},
          ),
        ),
      );

      expect(find.text('More Like This'), findsNothing);
    });

    testWidgets('lists related titles', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: [_item('a', 'Arrival'), _item('b', 'Sicario')],
            screenWidth: 400,
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('More Like This'), findsOneWidget);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text('Sicario'), findsOneWidget);
    });

    testWidgets('offers See All only when a destination is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: [_item('a', 'Arrival')],
            screenWidth: 400,
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('See All'), findsNothing);

      var explored = 0;
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: [_item('a', 'Arrival')],
            screenWidth: 400,
            onItemTap: (_) {},
            onExplore: () => explored++,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('See All'), findsOneWidget);
      await tester.tap(find.text('See All'));
      await tester.pump();
      expect(explored, 1);
    });

    testWidgets('reports taps on a related title', (tester) async {
      MediaItem? tapped;
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: [_item('a', 'Arrival')],
            screenWidth: 400,
            onItemTap: (item) => tapped = item,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Arrival'));
      await tester.pump();
      expect(tapped?.title, 'Arrival');
    });

    testWidgets('complies with the TV shelf rules', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DetailsRelatedSection(
            relatedItems: [for (var i = 0; i < 8; i++) _item('$i', 'Title $i')],
            screenWidth: 400,
            onItemTap: (_) {},
          ),
        ),
      );
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      // Without these the focus glow is clipped and D-Pad spatial navigation
      // cannot pre-render the next cards.
      expect(listView.clipBehavior, Clip.none);
      expect(listView.cacheExtent, 350.0);
    });
  });
}
