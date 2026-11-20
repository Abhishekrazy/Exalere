import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/plugin_service.dart';
import 'package:exalere/services/verified_providers.dart';

/// The store must never promise what it cannot deliver: a provider whose
/// mirrors answer nothing carries `Unavailable` (with a dated reason in
/// [VerifiedProviders.unavailable]) instead of the `Verified` badge.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unavailable providers', () {
    test('never overlap the verified set', () {
      final overlap = VerifiedProviders.unavailable.keys.where(
        VerifiedProviders.isVerified,
      );
      expect(
        overlap,
        isEmpty,
        reason: 'a provider cannot be both verified and unavailable',
      );
    });

    test('each store entry is tagged and keeps its date', () {
      final catalog = PluginService().getCommunityCatalog();
      for (final entry in VerifiedProviders.unavailable.entries) {
        final item = catalog.firstWhere(
          (candidate) => candidate.id == entry.key,
          orElse: () => throw StateError('${entry.key} missing from the store'),
        );
        expect(item.tags, contains('Unavailable'));
        expect(
          item.tags,
          isNot(contains('Verified')),
          reason: 'the badges must not contradict each other',
        );
        expect(
          entry.value,
          contains('2026'),
          reason: 'the reason should say when it was checked',
        );
        expect(
          item.description,
          startsWith('Currently unavailable'),
          reason: 'the detail sheet should explain the badge',
        );
        expect(item.description, contains(entry.value));
      }
    });

    test('the reason is reachable by id, case-insensitively', () {
      expect(
        VerifiedProviders.unavailableReason('ANIMESALT'),
        contains('No results found'),
      );
      expect(VerifiedProviders.unavailableReason('zeefliz'), isNull);
    });

    test('verified entries still carry exactly one badge', () {
      final catalog = PluginService().getCommunityCatalog();
      for (final id in VerifiedProviders.ids) {
        final item = catalog.firstWhere((candidate) => candidate.id == id);
        expect(item.tags.where((tag) => tag == 'Verified'), hasLength(1));
        expect(item.tags, isNot(contains('Unavailable')));
      }
    });

    test('the store opens on working add-ons', () {
      final catalog = PluginService().getCommunityCatalog();
      final ranks = [
        for (final item in catalog)
          VerifiedProviders.unavailableReason(item.id) != null
              ? 2
              : (VerifiedProviders.isVerified(item.id) ? 0 : 1),
      ];
      // Ranks never go backwards: verified, then the rest, then unavailable.
      for (var i = 1; i < ranks.length; i++) {
        expect(
          ranks[i] >= ranks[i - 1],
          isTrue,
          reason:
              '${catalog[i].name} (rank ${ranks[i]}) came after '
              '${catalog[i - 1].name} (rank ${ranks[i - 1]})',
        );
      }
      expect(ranks.first, 0, reason: 'a verified add-on should lead the store');
      expect(ranks.last, 2, reason: 'an unavailable add-on should sink');
    });

    test('add-ons without search say so', () {
      final catalog = PluginService().getCommunityCatalog();
      for (final id in ['gokuhd', 'animesub', 'torrentio']) {
        final item = catalog.firstWhere((candidate) => candidate.id == id);
        expect(
          item.tags,
          contains('Catalogue only'),
          reason: '$id cannot answer a search and should not pretend to',
        );
      }
      for (final id in ['zeefliz', 'kisskh']) {
        final item = catalog.firstWhere((candidate) => candidate.id == id);
        expect(item.tags, isNot(contains('Catalogue only')));
      }
    });
  });

  test('every built-in add-on is either verified or tagged Unavailable', () {
    // The porting rule, enforced at the store instead of in prose: an add-on
    // that claims streams and cannot resolve one must say so, and one that
    // resolves must carry the badge. A namespaced row (org.exalere.fourkhd) is
    // allowed when the engine behind it is verified, since it is a second door
    // to the same verified engine rather than an untested addition.
    final manifestIds = PluginService.builtInEngineManifests.keys.toSet();
    final offenders = <String>[];

    for (final id in manifestIds) {
      // Metadata-only add-ons (TMDB) never claim a stream, so the rule that a
      // play button must be honest does not apply to them.
      if (!PluginService.builtInEngineManifests[id]!.supportsStreams) continue;
      if (VerifiedProviders.isVerified(id)) continue;
      if (VerifiedProviders.unavailableReason(id) != null) continue;
      final engineKey = id.split('.').last;
      if (VerifiedProviders.isVerified(engineKey)) continue;
      offenders.add(id);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these ship an engine that claims streams but has neither badge: '
          '${offenders.join(', ')}',
    );
  });
}
