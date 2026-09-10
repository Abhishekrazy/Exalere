import 'package:flutter_test/flutter_test.dart';
import 'package:exalere/services/external_player_service.dart';

void main() {
  group('ExternalPlayerService Tests', () {
    test('singleton instance returns identical instance', () {
      final service1 = ExternalPlayerService();
      final service2 = ExternalPlayerService();
      expect(identical(service1, service2), isTrue);
    });

    test('detectPlayers returns a valid list of supported players', () async {
      final service = ExternalPlayerService();
      final players = await service.detectPlayers();
      expect(players, isA<List<String>>());
      for (final p in players) {
        expect(['MPV', 'VLC', 'IINA'].contains(p), isTrue);
      }
    });
  });
}
