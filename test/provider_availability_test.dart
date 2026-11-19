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
      }
    });

    test('the reason is reachable by id, case-insensitively', () {
      expect(
        VerifiedProviders.unavailableReason('MultiMovies'),
        contains('504'),
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
  });
}
