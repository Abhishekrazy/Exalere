import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/provider_catalog_row.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/provider_cooldown.dart';
import 'package:exalere/services/provider_home_rows_service.dart';

/// A provider with one row and a scripted feed.
class _Provider extends MediaProviderPlugin {
  _Provider({required this.id, this.items = const [], this.fail = false});

  @override
  final String id;

  @override
  String get name => 'Provider $id';

  final List<MediaItem> items;
  final bool fail;
  int calls = 0;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest'),
  ];

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async {
    calls++;
    if (fail) throw Exception('feed exploded');
    return items;
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

MediaItem _item(String id) =>
    MediaItem(id: id, title: id, mediaType: MediaType.movie);

void main() {
  group('provider cooldown', () {
    late DateTime now;
    ProviderCooldown build() => ProviderCooldown(
      base: const Duration(minutes: 2),
      max: const Duration(minutes: 20),
      clock: () => now,
    );

    setUp(() => now = DateTime(2026, 11, 20, 12));

    test('a failure cools the provider, and the window expires', () {
      final cooldown = build();
      expect(cooldown.isCooling('a'), isFalse);

      cooldown.recordFailure('a');
      expect(cooldown.isCooling('a'), isTrue);
      expect(cooldown.remaining('a'), const Duration(minutes: 2));

      now = now.add(const Duration(minutes: 2));
      expect(cooldown.isCooling('a'), isFalse);
    });

    test('repeated failures back off further, up to the ceiling', () {
      final cooldown = build();
      for (var i = 0; i < 6; i++) {
        cooldown.recordFailure('a');
      }
      expect(cooldown.failures['a'], 6);
      expect(cooldown.remaining('a'), const Duration(minutes: 20));
      expect(cooldown.remaining('a'), lessThanOrEqualTo(cooldown.max));
    });

    test('a success clears the window', () {
      final cooldown = build();
      cooldown.recordFailure('a');
      cooldown.recordSuccess('a');
      expect(cooldown.isCooling('a'), isFalse);
      expect(cooldown.failures.containsKey('a'), isFalse);
    });

    test('Home skips a provider that is cooling down', () async {
      final cooldown = build();
      final broken = _Provider(id: 'broken', fail: true);
      final good = _Provider(id: 'good', items: [_item('g1')]);

      final service = ProviderHomeRowsService(
        cooldown: cooldown,
        maxRowsPerProvider: 1,
      );

      final first = await service.load([broken, good]);
      expect(first.map((row) => row.providerId), ['good']);
      expect(cooldown.isCooling('broken'), isTrue);

      // Second load must not call the broken provider at all.
      final callsBefore = broken.calls;
      final second = await service.load([broken, good]);
      expect(broken.calls, callsBefore);
      expect(second.map((row) => row.providerId), ['good']);
    });

    test('a provider that answers is never put on cooldown', () async {
      final cooldown = build();
      final healthy = _Provider(id: 'healthy', items: [_item('h1')]);

      await ProviderHomeRowsService(
        cooldown: cooldown,
        maxRowsPerProvider: 1,
      ).load([healthy]);

      expect(cooldown.isCooling('healthy'), isFalse);
    });
  });
}
