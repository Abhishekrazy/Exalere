import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/moviebox_client.dart';

/// What does play-info/v2 actually return for a known subject? Printing the raw
/// payload is the difference between fixing a parser and guessing at one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  HttpOverrides.global = null;

  test('raw play-info payload', () async {
    final client = MovieBoxClient();
    await client.init();

    const subjectId = '1511967966181605720'; // Dune
    for (final path in [
      '/wefeed-mobile-bff/subject-api/play-info/v2?subjectId=$subjectId',
      '/wefeed-mobile-bff/subject-api/resource?subjectId=$subjectId&page=1&perPage=10',
      '/wefeed-mobile-bff/subject-api/get?subjectId=$subjectId',
    ]) {
      try {
        final value = await client.get(path);
        final text = jsonEncode(value);
        // ignore: avoid_print
        print(
          '$path\n   ${text.length} chars: ${text.substring(0, text.length.clamp(0, 600))}',
        );
      } catch (error) {
        // ignore: avoid_print
        print('$path\n   failed: $error');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
