import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/ui/theme/app_themes.dart';

void main() {
  AppDesignTokens cutTokens() => AppThemes.netflixBlack.themeData
      .extension<AppDesignTokens>()!
      .copyWith(cornerStyle: CornerStyle.cut);

  test('Cut pills chamfer half the short side (eight-corner pill)', () {
    final tokens = cutTokens();
    final sentinel = tokens.getShapeBorder(radius: 999) as AdaptiveBevelBorder;
    expect(sentinel.fraction, 0.5);
    expect(sentinel.cutFor(const Size(120, 30)), 15);

    final pill = tokens.getShapePill() as AdaptiveBevelBorder;
    expect(pill.cutFor(const Size(120, 30)), 15);
  });

  test('Cut cards scale their chamfer with the box, not a fixed radius', () {
    final tokens = cutTokens();
    final card =
        tokens.getShapeBorder(radius: tokens.cardRadius) as AdaptiveBevelBorder;

    // 14% of the short side, clamped, so a chip and a card differ.
    expect(card.cutFor(const Size(400, 88)), closeTo(12.32, 0.01));
    expect(card.cutFor(const Size(120, 30)), closeTo(4.2, 0.01));
  });
}
