import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/provider_catalog_row.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/provider_cooldown.dart';
import 'package:exalere/services/provider_home_rows_service.dart';
import 'package:exalere/services/provider_registry.dart';

/// Installing an add-on has to change Home without a restart. The store calls
/// `loadHomeFeeds()`, which re-runs the provider-row service against whatever
/// the registry now holds; these tests prove that chain with a provider that
/// only appears after the first load.
class _ShelfProvider extends MediaProviderPlugin {
  @override
  String get id => 'fake-shelf';

  @override
  String get name => 'Fake Shelf';

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest on Fake'),
  ];

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async => [
    MediaItem(
      id: 'f1',
      title: 'Installed After Launch',
      mediaType: MediaType.movie,
      posterUrl: 'https://example.com/p.jpg',
    ),
  ];

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

void main() {
  group('a newly installed add-on reaches Home', () {
    tearDown(() => ProviderRegistry().unregisterProvider('fake-shelf'));

    test(
      'its shelf appears on the next row load, not after a restart',
      () async {
        final service = ProviderHomeRowsService(cooldown: ProviderCooldown());

        final before = await service.load(ProviderRegistry().streamProviders);
        expect(
          before.any((row) => row.providerId == 'fake-shelf'),
          isFalse,
          reason: 'nothing installed yet',
        );

        // What PluginService.installPlugin ends up doing.
        ProviderRegistry().registerProvider(_ShelfProvider());

        final after = await service.load(ProviderRegistry().streamProviders);
        final row = after.where((r) => r.providerId == 'fake-shelf').toList();

        expect(row, hasLength(1));
        expect(row.single.title, contains('Fake'));
        expect(row.single.items.map((i) => i.title), [
          'Installed After Launch',
        ]);
      },
    );

    test('uninstalling removes the shelf again', () async {
      final service = ProviderHomeRowsService(cooldown: ProviderCooldown());
      ProviderRegistry().registerProvider(_ShelfProvider());
      await service.load(ProviderRegistry().streamProviders);

      ProviderRegistry().unregisterProvider('fake-shelf');
      final rows = await service.load(ProviderRegistry().streamProviders);

      expect(rows.any((row) => row.providerId == 'fake-shelf'), isFalse);
    });
  });
}
