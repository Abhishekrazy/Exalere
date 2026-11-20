import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exalere/services/moviebox_provider.dart';

/// The endpoint returns a stream (verified by hand); this isolates the parsing
/// steps so the failure is named instead of guessed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  HttpOverrides.global = null;

  test('parse steps', () {
    for (final input in ['480,720,1080', '1080,720,480', '4K,1080']) {
      try {
        final parsed = MovieBoxProvider.parseResolutions(input);
        // ignore: avoid_print
        print(
          'parseResolutions("$input") -> top=${parsed.$1} res=${parsed.$2} q=${parsed.$3}',
        );
      } catch (error) {
        // ignore: avoid_print
        print('parseResolutions("$input") threw $error');
      }
    }
    // ignore: avoid_print
    print(
      'deprecation("macdn")=${MovieBoxProvider.isDeprecationNoticeUrl("https://macdn.aoneroom.com/other/2026/10/10/x.mp4")}',
    );
  });
}
