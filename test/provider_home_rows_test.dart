import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/provider_catalog_row.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/hdhub4u_provider.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/movies4u_provider.dart';
import 'package:exalere/services/moviesdrive_provider.dart';
import 'package:exalere/services/moviesmod_provider.dart';
import 'package:exalere/services/provider_home_rows_service.dart';
import 'package:exalere/services/uhdmovies_provider.dart';

/// A provider with declared rows and a scripted feed per row.
class _RowProvider extends MediaProviderPlugin {
  _RowProvider({
    required this.id,
    required this.name,
    required this.declaredRows,
    this.feeds = const {},
    this.delay,
    this.failEverything = false,
  });

  @override
  final String id;

  @override
  final String name;

  final List<ProviderCatalogRow> declaredRows;

  /// Feed contents keyed by `category`, `'default'` for a null category.
  final Map<String, List<MediaItem>> feeds;

  final Duration? delay;
  final bool failEverything;

  int feedCalls = 0;

  @override
  List<ProviderCatalogRow> get catalogs => declaredRows;

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    feedCalls++;
    if (delay != null) await Future.delayed(delay!);
    if (failEverything) throw Exception('feed exploded');
    return feeds[category ?? 'default'] ?? const [];
  }

  @override
  Future<List<MediaItem>> search(String query) async => const [];

  @override
  Future<MediaDetails?> getDetails(String id) async => null;

  @override
  Future<List<StreamSource>> getStreams({
    required String subjectId,
    String? title,
    String? year,
    String? imdbId,
    int? season,
    int? episode,
    String? originProviderId,
    bool? isSeries,
  }) async => const [];
}

MediaItem _item(String id, String title) => MediaItem(
  id: id,
  title: title,
  mediaType: MediaType.movie,
  provider: ProviderType.plugins,
);

ProviderCatalogRow _row(String id, [String? category]) =>
    ProviderCatalogRow(id: id, title: 'Row $id', category: category);

void main() {
  group('ProviderHomeRowsService', () {
    test('one row per declared catalog, attributed to its provider', () async {
      final provider = _RowProvider(
        id: 'alpha',
        name: 'Alpha',
        declaredRows: [_row('trending'), _row('series', 'series')],
        feeds: {
          'default': [_item('a1', 'Dune')],
          'series': [_item('a2', 'Severance')],
        },
      );

      final rows = await const ProviderHomeRowsService().load([provider]);

      expect(rows, hasLength(2));
      expect(rows[0].providerId, 'alpha');
      expect(rows[0].providerName, 'Alpha');
      expect(rows[0].rowId, 'trending');
      expect(rows[0].items.single.title, 'Dune');
      expect(rows[1].rowId, 'series');
      expect(rows[1].displayTitle, 'Row series · Alpha');
    });

    test('a failing row is dropped while the others survive', () async {
      final broken = _RowProvider(
        id: 'broken',
        name: 'Broken',
        declaredRows: [_row('latest')],
        failEverything: true,
      );
      final good = _RowProvider(
        id: 'good',
        name: 'Good',
        declaredRows: [_row('latest')],
        feeds: {
          'default': [_item('g1', 'Arrival')],
        },
      );

      final rows = await const ProviderHomeRowsService().load([broken, good]);

      expect(rows, hasLength(1));
      expect(rows.single.providerName, 'Good');
    });

    test('an empty feed contributes no row', () async {
      final provider = _RowProvider(
        id: 'empty',
        name: 'Empty',
        declaredRows: [_row('latest')],
      );

      expect(
        await const ProviderHomeRowsService().load([provider]),
        isEmpty,
        reason: 'an empty shelf is a gap, not a row',
      );
    });

    test('a hanging provider does not hold the screen', () async {
      final hanging = _RowProvider(
        id: 'hanging',
        name: 'Hanging',
        declaredRows: [_row('latest')],
        feeds: {
          'default': [_item('h1', 'Dune')],
        },
        delay: const Duration(seconds: 5),
      );

      final stopwatch = Stopwatch()..start();
      final rows = await const ProviderHomeRowsService(
        timeout: Duration(milliseconds: 120),
      ).load([hanging]);
      stopwatch.stop();

      expect(rows, isEmpty);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('honours the per-provider and total row caps', () async {
      final busy = _RowProvider(
        id: 'busy',
        name: 'Busy',
        declaredRows: [_row('a'), _row('b'), _row('c'), _row('d')],
        feeds: {
          'default': [_item('b1', 'Dune')],
        },
      );
      final second = _RowProvider(
        id: 'second',
        name: 'Second',
        declaredRows: [_row('a'), _row('b'), _row('c')],
        feeds: {
          'default': [_item('s1', 'Arrival')],
        },
      );

      final rows = await const ProviderHomeRowsService(
        maxRows: 3,
        maxRowsPerProvider: 2,
      ).load([busy, second]);

      expect(rows, hasLength(3));
      expect(
        busy.feedCalls,
        2,
        reason: 'only the declared budget is requested',
      );
      expect(rows.where((r) => r.providerId == 'busy'), hasLength(2));
      expect(rows.where((r) => r.providerId == 'second'), hasLength(1));
    });

    test(
      'drops titles the caller rejects, and the row if none remain',
      () async {
        final provider = _RowProvider(
          id: 'alpha',
          name: 'Alpha',
          declaredRows: [_row('mixed', 'mixed'), _row('blocked', 'blocked')],
          feeds: {
            'mixed': [_item('ok', 'Dune'), _item('adult', 'Adult Title')],
            'blocked': [_item('adult2', 'Another Adult Title')],
          },
        );

        final rows = await const ProviderHomeRowsService().load([
          provider,
        ], isAllowed: (item) => !item.title.toLowerCase().contains('adult'));

        expect(rows, hasLength(1));
        expect(rows.single.items.single.title, 'Dune');
      },
    );

    test('duplicate ids inside one row are collapsed', () async {
      final provider = _RowProvider(
        id: 'alpha',
        name: 'Alpha',
        declaredRows: [_row('latest')],
        feeds: {
          'default': [_item('same', 'Dune'), _item('same', 'Dune 4K')],
        },
      );

      final rows = await const ProviderHomeRowsService().load([provider]);
      expect(rows.single.items, hasLength(1));
    });
  });

  group('built-in providers declare home rows', () {
    test('every HubCloud scraper offers at least one row', () {
      final providers = <MediaProviderPlugin>[
        HDHub4uPlugin(),
        MoviesDrivePlugin(),
        MoviesModPlugin(),
        UhdMoviesPlugin(),
        Movies4UPlugin(),
      ];

      for (final provider in providers) {
        expect(
          provider.catalogs,
          isNotEmpty,
          reason: '${provider.name} should contribute a Home row',
        );
        expect(provider.catalogs.first.category, isNull);
      }
    });

    test('catalog feeds stay opt-in: declaring rows does not claim the '
        'browse-catalogue role', () {
      for (final provider in <MediaProviderPlugin>[
        HDHub4uPlugin(),
        MoviesDrivePlugin(),
        MoviesModPlugin(),
        UhdMoviesPlugin(),
        Movies4UPlugin(),
      ]) {
        expect(
          provider.supportsCatalogFeeds,
          isFalse,
          reason:
              '${provider.name} serves a latest-additions grid, not a category '
              'catalogue; the self-test must keep reporting that',
        );
      }
    });
  });
}
