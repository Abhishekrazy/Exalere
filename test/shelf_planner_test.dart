import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_item.dart';
import 'package:exalere/services/shelf_planner.dart';

MediaItem _item(
  String id,
  String title, {
  String? year,
  ProviderType provider = ProviderType.movieBox,
}) {
  return MediaItem(
    id: id,
    title: title,
    mediaType: MediaType.movie,
    year: year,
    provider: provider,
  );
}

void main() {
  group('ShelfPlanner identity', () {
    test('treats the same film from two providers as one title', () {
      // Different ids, same film: without title+year matching this would be
      // shown twice on the same page.
      final a = _item('101', 'Dune', year: '2021');
      final b = _item(
        'zzz-99',
        'Dune',
        year: '2021',
        provider: ProviderType.plugins,
      );
      expect(ShelfPlanner.identityOf(a), ShelfPlanner.identityOf(b));
    });

    test('ignores case, punctuation and a trailing year in the title', () {
      final a = _item('1', 'Dune: Part Two', year: '2024');
      final b = _item('2', '  dune  part   two (2024) ', year: '2024');
      expect(ShelfPlanner.identityOf(a), ShelfPlanner.identityOf(b));
    });

    test('keeps different years apart', () {
      final a = _item('1', 'Dune', year: '1984');
      final b = _item('2', 'Dune', year: '2021');
      expect(
        ShelfPlanner.identityOf(a),
        isNot(ShelfPlanner.identityOf(b)),
        reason: 'these are genuinely different films',
      );
    });

    test('falls back to the id when a title is unusable', () {
      expect(ShelfPlanner.identityOf(_item('abc', '')), contains('abc'));
    });
  });

  group('ShelfPlanner.next', () {
    test('lets the first shelf claim a title and later shelves lose it', () {
      final planner = ShelfPlanner();
      final shared = _item('1', 'Dune', year: '2021');

      final first = planner.next([shared, _item('2', 'Arrival', year: '2016')]);
      final second = planner.next([
        shared,
        _item('3', 'Sicario', year: '2015'),
      ]);

      expect(first.map((i) => i.title), ['Dune', 'Arrival']);
      expect(second.map((i) => i.title), [
        'Sicario',
      ], reason: 'Dune already appeared in the row above');
    });

    test('preserves the original order within a shelf', () {
      final planner = ShelfPlanner();
      final result = planner.next([
        _item('1', 'A'),
        _item('2', 'B'),
        _item('3', 'C'),
      ]);
      expect(result.map((i) => i.title), ['A', 'B', 'C']);
    });

    test('caps the shelf size', () {
      final planner = ShelfPlanner(maxItemsPerShelf: 3);
      final result = planner.next([
        for (var i = 0; i < 10; i++) _item('$i', 'Title $i'),
      ]);
      expect(result.length, 3);
    });

    test('caps after filtering, so a duplicate never shortens the row', () {
      // Regression guard: capping first then filtering would return one item
      // here instead of a full row.
      final planner = ShelfPlanner(maxItemsPerShelf: 2);
      final claimed = _item('0', 'Claimed');
      planner.next([claimed]);

      final result = planner.next([
        claimed,
        _item('1', 'Fresh One'),
        _item('2', 'Fresh Two'),
        _item('3', 'Fresh Three'),
      ]);

      expect(result.map((i) => i.title), ['Fresh One', 'Fresh Two']);
    });

    test('returns empty when every title was already shown', () {
      final planner = ShelfPlanner();
      final items = [_item('1', 'Dune', year: '2021')];
      planner.next(items);
      expect(planner.next(items), isEmpty);
    });

    test('handles empty and missing-year input', () {
      final planner = ShelfPlanner();
      expect(planner.next(const []), isEmpty);
      final result = planner.next([
        _item('1', 'Yearless'),
        _item('2', 'Yearless'),
      ]);
      expect(
        result.length,
        1,
        reason: 'identical title with no year is one title',
      );
    });

    test('counts what it has claimed', () {
      final planner = ShelfPlanner();
      planner.next([_item('1', 'A'), _item('2', 'B'), _item('3', 'A')]);
      expect(planner.claimedCount, 2);
    });
  });

  group('ShelfPlanner.hasFreshTitles', () {
    test('reports without claiming', () {
      final planner = ShelfPlanner();
      final items = [_item('1', 'Dune', year: '2021')];

      expect(planner.hasFreshTitles(items), isTrue);
      expect(
        planner.claimedCount,
        0,
        reason: 'a check must not consume titles',
      );

      planner.next(items);
      expect(planner.hasFreshTitles(items), isFalse);
    });

    test('is true when only some titles are new', () {
      final planner = ShelfPlanner();
      planner.next([_item('1', 'Dune', year: '2021')]);
      expect(
        planner.hasFreshTitles([
          _item('1', 'Dune', year: '2021'),
          _item('2', 'New Title'),
        ]),
        isTrue,
      );
    });

    test('is false for an empty shelf', () {
      expect(ShelfPlanner().hasFreshTitles(const []), isFalse);
    });
  });

  group('a realistic home page', () {
    test('no title is repeated across any two rows', () {
      final dune = _item('1', 'Dune', year: '2021');
      final arrival = _item('2', 'Arrival', year: '2016');
      final sicario = _item('3', 'Sicario', year: '2015');
      final heat = _item('4', 'Heat', year: '1995');

      final planner = ShelfPlanner();
      final shelves = [
        planner.next([dune, arrival]),
        planner.next([arrival, sicario]),
        planner.next([dune, sicario, heat]),
        planner.next([heat]),
      ];

      final seen = <String>{};
      for (final shelf in shelves) {
        for (final item in shelf) {
          final key = ShelfPlanner.identityOf(item);
          expect(
            seen.add(key),
            isTrue,
            reason: '"${item.title}" appeared in more than one row',
          );
        }
      }
      // And the page still surfaces every distinct title somewhere.
      expect(seen.length, 4);
    });
  });
}
