import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/models/user_profile.dart';
import 'package:exalere/ui/theme/app_themes.dart';
import 'package:exalere/ui/widgets/profile_avatar.dart';

UserProfile _profile(String name) =>
    UserProfile(id: 'test', name: name, createdAt: 0, lastActiveAt: 0);

void main() {
  group('UserProfile.initials', () {
    test('uses the first letter of the first two words', () {
      expect(_profile('Abhishek Razy').initials, 'AR');
      expect(_profile('Kids Room').initials, 'KR');
      expect(_profile('  abhishek   razy  ').initials, 'AR');
    });

    test('single-word names keep two letters', () {
      expect(_profile('Kids').initials, 'KI');
      expect(_profile('A').initials, 'A');
    });

    test('empty names never crash the rail', () {
      expect(_profile('   ').initials, '?');
    });

    test('initials are bounded even with many words', () {
      expect(_profile('Abhishek Kumar Razy').initials.length, 2);
    });
  });

  group('ProfileAvatar', () {
    testWidgets('unknown avatar id falls back to the profile icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.netflixBlack.themeData,
          home: const Scaffold(
            body: ProfileAvatar(avatarId: 'does-not-exist', size: 40),
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
    });

    test('every shipped avatar option has a bundled asset path', () {
      for (final option in UserProfile.availableAvatars) {
        expect(option.asset, contains('assets/images/profiles/'));
        expect(option.asset, endsWith('.png'));
      }
    });
  });
}
