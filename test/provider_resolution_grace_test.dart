import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/models/stream_source.dart';
import 'package:exalere/services/provider_registry.dart';

/// Playback must start on the first answer, not on the slowest provider.
///
/// `resolveStreams` returns as soon as one provider succeeds plus a short grace
/// window, with a hard cap above everything. These tests pin that behaviour with
/// deliberately slow and hanging fakes, because a regression here shows up as a
/// spinner on a detail page rather than as a failed assertion anywhere else.
class _Plugin extends MediaProviderPlugin {
  _Plugin({required this.id, this.delay = Duration.zero, this.hang = false});

  @override
  final String id;

  final Duration delay;
  final bool hang;

  @override
  String get name => id;

  @override
  bool get supportsStreams => true;

  @override
  bool get supportsMovies => true;

  @override
  bool get supportsSeries => true;

  @override
  bool get supportsSearch => true;

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
  }) async {
    if (hang) {
      await Future<void>.delayed(const Duration(minutes: 5));
    } else if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return [
      StreamSource(
        quality: '1080p',
        resolution: '1920x1080',
        format: 'MP4',
        url: 'https://cdn.example/$id.mkv',
        server: id,
        providerId: id,
        providerName: id,
      ),
    ];
  }
}

void main() {
  final registry = ProviderRegistry();

  tearDown(() {
    registry.clearAll();
    registry.defaultProviderId = null;
  });

  test('a fast provider is returned without waiting for a slow one', () async {
    registry.registerProvider(_Plugin(id: 'fast'));
    registry.registerProvider(
      _Plugin(id: 'slow', delay: const Duration(seconds: 6)),
    );

    final watch = Stopwatch()..start();
    final streams = await registry.resolveStreams(subjectId: 'x');
    watch.stop();

    expect(streams, isNotEmpty);
    expect(streams.first.effectiveProviderId, 'fast');
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 4)),
      reason: 'the slow provider must not hold the detail page',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a hanging provider does not prevent playback at all', () async {
    registry.registerProvider(_Plugin(id: 'fast'));
    registry.registerProvider(_Plugin(id: 'hung', hang: true));

    final watch = Stopwatch()..start();
    final streams = await registry.resolveStreams(subjectId: 'x');
    watch.stop();

    expect(streams, isNotEmpty);
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
  }, timeout: const Timeout(Duration(seconds: 40)));

  test('with nothing installed there is nothing to wait for', () async {
    final watch = Stopwatch()..start();
    final streams = await registry.resolveStreams(subjectId: 'x');
    watch.stop();

    expect(streams, isEmpty);
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });
}
