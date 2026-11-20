import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/exalere_plugin.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/provider_catalog_row.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/media_provider_plugin.dart';
import 'package:exalere/services/provider_registry.dart';

/// Disabling an add-on has to take it out of every surface it had joined: Home
/// shelves, global search and stream resolution. The store's toggle does this by
/// unregistering the engine (`PluginService.togglePlugin`), so these tests pin
/// exactly what the registry derives from that.
class _Toggleable extends MediaProviderPlugin {
  _Toggleable({required this.id, required this.name, this.enabled = true});

  @override
  final String id;

  @override
  final String name;

  final bool enabled;

  @override
  bool get isEnabled => enabled;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsCatalogFeeds => true;

  @override
  List<ProviderCatalogRow> get catalogs => const [
    ProviderCatalogRow(id: 'latest', title: 'Latest'),
  ];

  @override
  Future<List<MediaItem>> getCatalogFeed({
    String? category,
    int page = 1,
  }) async => [
    MediaItem(id: '$id-1', title: 'A Title', mediaType: MediaType.movie),
  ];

  @override
  Future<List<MediaItem>> search(String query) async => [
    MediaItem(id: '$id-1', title: 'A Title', mediaType: MediaType.movie),
  ];

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
  tearDown(() {
    ProviderRegistry().unregisterProvider('toggle-fake');
    ProviderRegistry().unregisterProvider('stays-fake');
  });

  test('a disabled engine is in none of the registry lists', () {
    final registry = ProviderRegistry();
    registry.registerProvider(
      _Toggleable(id: 'toggle-fake', name: 'Disabled', enabled: false),
    );

    expect(registry.streamProviders, isEmpty);
    expect(registry.searchProviders, isEmpty);
    expect(registry.catalogProviders, isEmpty);
    expect(registry.hasStreamProviders, isFalse);
  });

  test('unregistering removes every trace of an enabled engine', () async {
    final registry = ProviderRegistry();
    registry.registerProvider(_Toggleable(id: 'toggle-fake', name: 'Enabled'));
    expect(registry.hasStreamProviders, isTrue);

    final sections = <String>[];
    await registry.searchAllProviders(
      'a title',
      onSection: (section) => sections.add(section.providerId),
    );
    expect(sections, contains('toggle-fake'));

    // What PluginService.togglePlugin(id, false) does.
    registry.unregisterProvider('toggle-fake');

    expect(registry.hasStreamProviders, isFalse);
    expect(registry.resolveProvider('toggle-fake'), isNull);

    final after = <String>[];
    await registry.searchAllProviders(
      'a title',
      onSection: (section) => after.add(section.providerId),
    );
    expect(after, isNot(contains('toggle-fake')));
  });

  test('disabling one add-on leaves the others alone', () async {
    final registry = ProviderRegistry();
    registry.registerProvider(_Toggleable(id: 'toggle-fake', name: 'One'));
    registry.registerProvider(_Toggleable(id: 'stays-fake', name: 'Two'));

    registry.unregisterProvider('toggle-fake');

    expect(registry.streamProviders.map((p) => p.id), ['stays-fake']);
  });
}
