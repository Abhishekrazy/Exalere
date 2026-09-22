import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/dramachi_provider.dart';

void main() {
  group('DramachiProvider Tests', () {
    test('parseEpisodeNumber extracts episode numbers from title strings', () {
      expect(DramachiProvider.parseEpisodeNumber('Vincenzo S01E01'), equals(1));
      expect(
        DramachiProvider.parseEpisodeNumber('Vincenzo S01E20'),
        equals(20),
      );
      expect(DramachiProvider.parseEpisodeNumber('Drama Ep 05'), isNull);
      expect(DramachiProvider.parseEpisodeNumber('Show.e12.mkv'), equals(12));
    });

    test('parseSizeBytes parses MB, GB, KB accurately', () {
      expect(
        DramachiProvider.parseSizeBytes('174.8 MB'),
        equals((174.8 * 1024 * 1024).toInt()),
      );
      expect(
        DramachiProvider.parseSizeBytes('1.5 GB'),
        equals((1.5 * 1024 * 1024 * 1024).toInt()),
      );
      expect(
        DramachiProvider.parseSizeBytes('500 KB'),
        equals((500 * 1024).toInt()),
      );
      expect(DramachiProvider.parseSizeBytes('invalid'), isNull);
    });

    test('DramachiAdapter declares correct properties', () {
      final adapter = DramachiAdapter();
      expect(adapter.id, equals('dramachi'));
      expect(adapter.name, equals('Dramachi'));
      expect(adapter.supportsMovies, isTrue);
      expect(adapter.supportsSeries, isTrue);
      expect(adapter.supportsSearch, isTrue);
      expect(adapter.priority, equals(40));
    });
  });
}
