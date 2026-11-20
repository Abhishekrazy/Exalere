import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/provider_search_section.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/services/provider_cooldown.dart';
import 'package:exalere/services/provider_registry.dart';
import 'package:exalere/ui/screens/active_search_screen.dart';
import 'package:exalere/ui/widgets/provider_search_chip.dart';
import 'package:exalere/ui/widgets/search_media_card.dart';

/// A provider whose answers the test controls: results, delay, or failure.
class _FakeProvider extends MediaProviderPlugin {
  _FakeProvider({
    required this.id,
    required this.name,
    this.items,
    this.delay,
    this.fail = false,
    this.priority = 10,
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final int priority;

  /// Raw catalogue entries. The title is suffixed with the query by
  /// [_answerFor] so a test can tell which search an answer belongs to.
  final List<MediaItem>? items;

  /// How long the provider takes to answer.
  final Duration? delay;

  final bool fail;

  int searchCalls = 0;

  @override
  bool get supportsSearch => true;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsSeries => true;

  @override
  Future<List<MediaItem>> search(String query) async {
    searchCalls++;
    if (delay != null) await Future.delayed(delay!);
    if (fail) throw Exception('provider exploded');
    return _answerFor(query);
  }

  List<MediaItem> _answerFor(String query) {
    final source = items;
    if (source == null) return const [];
    return [
      for (final item in source)
        MediaItem(
          id: '${item.id}-$query',
          title: '${item.title} $query',
          mediaType: item.mediaType,
          provider: item.provider,
          providerId: id,
        ),
    ];
  }

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

void main() {
  setUp(() {
    // Drop anything a previous test registered, back to the built-in defaults.
    ProviderRegistry().clearAll();
  });

  group('ProviderRegistry.searchAllProviders', () {
    test('reports one section per provider with its own outcome', () async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
        priority: 20,
      );
      final beta = _FakeProvider(id: 'beta', name: 'Beta', items: const []);
      final broken = _FakeProvider(id: 'broken', name: 'Broken', fail: true);
      final registry = ProviderRegistry()
        ..registerProvider(alpha)
        ..registerProvider(beta)
        ..registerProvider(broken);

      final sections = <ProviderSearchSection>[];
      await registry.searchAllProviders(
        'dune',
        onSection: sections.add,
        perProviderTimeout: const Duration(seconds: 2),
      );

      expect(sections, hasLength(3));

      final alphaSection = sections.firstWhere((s) => s.providerId == 'alpha');
      expect(alphaSection.status, ProviderSearchStatus.loaded);
      expect(alphaSection.items.single.title, 'Dune dune');

      final betaSection = sections.firstWhere((s) => s.providerId == 'beta');
      expect(
        betaSection.status,
        ProviderSearchStatus.empty,
        reason: 'answering with nothing is success, not failure',
      );

      final brokenSection = sections.firstWhere(
        (s) => s.providerId == 'broken',
      );
      expect(brokenSection.status, ProviderSearchStatus.failed);
      expect(brokenSection.error, contains('provider exploded'));
    });

    test('a hanging provider times out without blocking the others', () async {
      final fast = _FakeProvider(
        id: 'fast',
        name: 'Fast',
        items: [_item('f1', 'Arrival')],
      );
      final hanging = _FakeProvider(
        id: 'hanging',
        name: 'Hanging',
        items: [_item('h1', 'Arrival')],
        delay: const Duration(seconds: 5),
      );
      final registry = ProviderRegistry()
        ..registerProvider(fast)
        ..registerProvider(hanging);

      final sections = <ProviderSearchSection>[];
      final stopwatch = Stopwatch()..start();
      await registry.searchAllProviders(
        'arrival',
        onSection: sections.add,
        perProviderTimeout: const Duration(milliseconds: 120),
      );
      stopwatch.stop();

      final hangingSection = sections.firstWhere(
        (s) => s.providerId == 'hanging',
      );
      expect(hangingSection.status, ProviderSearchStatus.failed);
      expect(hangingSection.error, contains('Timed out'));
      expect(
        sections.firstWhere((s) => s.providerId == 'fast').hasResults,
        isTrue,
      );
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 3)),
        reason: 'the timeout must bound the whole fan-out',
      );
    });

    test('an empty query never reaches a provider', () async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
      );
      ProviderRegistry().registerProvider(alpha);

      final sections = <ProviderSearchSection>[];
      await ProviderRegistry().searchAllProviders(
        '   ',
        onSection: sections.add,
      );

      expect(sections, isEmpty);
      expect(alpha.searchCalls, 0);
    });

    test('a cancelled query reports nothing', () async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
        delay: const Duration(milliseconds: 30),
      );
      ProviderRegistry().registerProvider(alpha);

      final sections = <ProviderSearchSection>[];
      await ProviderRegistry().searchAllProviders(
        'dune',
        onSection: sections.add,
        isCancelled: () => true,
      );

      expect(sections, isEmpty);
    });
  });

  group('AppProvider global search', () {
    test('keeps every provider\'s slice and filters by provider', () async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
        priority: 20,
      );
      final beta = _FakeProvider(
        id: 'beta',
        name: 'Beta',
        items: [_item('b1', 'Arrival')],
      );
      ProviderRegistry()
        ..registerProvider(alpha)
        ..registerProvider(beta);

      final app = AppProvider();
      await app.search('dune');

      expect(app.searchQuery, 'dune');
      expect(app.providerSearchSections, hasLength(2));
      expect(app.isSearching, isFalse);
      expect(app.searchProvidersAnswered, 2);
      expect(app.searchResults, hasLength(2));

      app.selectSearchProvider('beta');
      expect(app.selectedSearchProviderId, 'beta');
      expect(app.visibleSearchResults.single.title, contains('Arrival'));
      expect(app.visibleSearchResults.single.providerId, 'beta');

      app.selectSearchProvider(null);
      expect(app.visibleSearchResults, hasLength(2));
    });

    test('merged results stay stable in provider priority order', () async {
      // The slower provider has the higher priority; the merged list must still
      // put it first once it answers.
      final slowHigh = _FakeProvider(
        id: 'slowhigh',
        name: 'SlowHigh',
        items: [_item('s1', 'Dune')],
        delay: const Duration(milliseconds: 40),
        priority: 90,
      );
      final fastLow = _FakeProvider(
        id: 'fastlow',
        name: 'FastLow',
        items: [_item('f1', 'Dune Part Two')],
        priority: 5,
      );
      ProviderRegistry()
        ..registerProvider(slowHigh)
        ..registerProvider(fastLow);

      final app = AppProvider();
      await app.search('dune');

      expect(app.searchResults.first.providerId, 'slowhigh');
    });

    test('an answer for a replaced query is discarded', () async {
      final slow = _FakeProvider(
        id: 'slow',
        name: 'Slow',
        items: [_item('s1', 'Alpha')],
        delay: const Duration(milliseconds: 80),
      );
      final fast = _FakeProvider(
        id: 'fast',
        name: 'Fast',
        items: [_item('f1', 'Beta')],
        delay: const Duration(milliseconds: 10),
      );
      ProviderRegistry()
        ..registerProvider(slow)
        ..registerProvider(fast);

      final app = AppProvider();
      final first = app.search('alpha');
      await Future.delayed(const Duration(milliseconds: 5));
      await app.search('beta');
      await first;

      expect(app.searchQuery, 'beta');
      final titles = app.searchResults.map((i) => i.title).join(' | ');
      expect(
        titles.contains('alpha'),
        isFalse,
        reason: 'the stale alpha answer must not paint beta results',
      );
      expect(app.providerSearchSections.every((s) => !s.isSearching), isTrue);
    });

    test('failed providers are named instead of blanking the page', () async {
      final good = _FakeProvider(
        id: 'good',
        name: 'Good',
        items: [_item('g1', 'Dune')],
      );
      final broken = _FakeProvider(id: 'broken', name: 'Broken', fail: true);
      ProviderRegistry()
        ..registerProvider(good)
        ..registerProvider(broken);

      final app = AppProvider();
      await app.search('dune');

      expect(app.searchResults, hasLength(1));
      expect(app.failedSearchProviders.single.providerName, 'Broken');
      expect(app.matchingSearchProviders.single.providerName, 'Good');
    });

    test('clearSearch drops sections and the provider selection', () async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
      );
      ProviderRegistry().registerProvider(alpha);

      final app = AppProvider();
      await app.search('dune');
      app.selectSearchProvider('alpha');
      expect(app.visibleSearchResults, hasLength(1));

      app.clearSearch();

      expect(app.searchQuery, isEmpty);
      expect(app.providerSearchSections, isEmpty);
      expect(app.selectedSearchProviderId, isNull);
      expect(app.searchResults, isEmpty);
    });
  });

  group('ActiveSearchScreen provider chips', () {
    testWidgets('shows one chip per provider and filters the grid on tap', (
      tester,
    ) async {
      final alpha = _FakeProvider(
        id: 'alpha',
        name: 'Alpha',
        items: [_item('a1', 'Dune')],
        priority: 20,
      );
      final beta = _FakeProvider(
        id: 'beta',
        name: 'Beta',
        items: [_item('b1', 'Arrival')],
      );
      ProviderRegistry()
        ..registerProvider(alpha)
        ..registerProvider(beta);

      final appProvider = AppProvider();
      await appProvider.search('dune');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: const MaterialApp(home: ActiveSearchScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // All providers + one chip per provider.
      expect(find.byType(ProviderSearchChip), findsNWidgets(3));
      expect(find.text('All providers'), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
      expect(find.text('Beta'), findsWidgets);
      expect(find.byType(SearchMediaCard), findsNWidgets(2));
      // In the merged view each card names the provider it came from, so the
      // user can see where the title is available without opening it.
      expect(
        find.descendant(
          of: find.byType(SearchMediaCard),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Beta').first);
      await tester.pumpAndSettle();

      expect(appProvider.selectedSearchProviderId, 'beta');
      expect(find.byType(SearchMediaCard), findsOneWidget);
      expect(find.textContaining('Arrival'), findsWidgets);
      // A single-provider view no longer needs the badge.
      expect(
        find.descendant(
          of: find.byType(SearchMediaCard),
          matching: find.text('Beta'),
        ),
        findsNothing,
      );
    });
  });

  test('a cooling-down provider is reported, not asked', () async {
    final registry = ProviderRegistry();
    registry.registerProvider(
      _FakeProvider(id: 'flaky', name: 'Flaky', items: const []),
    );
    registry.registerProvider(
      _FakeProvider(id: 'steady', name: 'Steady', items: const []),
    );

    var now = DateTime(2026, 11, 20, 12);
    final cooldown = ProviderCooldown(clock: () => now);
    cooldown.recordFailure('flaky');

    final sections = <ProviderSearchSection>[];
    await registry.searchAllProviders(
      'dune',
      cooldown: cooldown,
      onSection: sections.add,
    );

    final flaky = sections.firstWhere((s) => s.providerId == 'flaky');
    expect(flaky.status, ProviderSearchStatus.coolingDown);
    expect(flaky.statusLabel, 'backing off');
    expect(flaky.hasFailed, isFalse);

    // The other provider was still asked and answered.
    expect(
      sections.firstWhere((s) => s.providerId == 'steady').status,
      isNot(ProviderSearchStatus.coolingDown),
    );
  });
}
