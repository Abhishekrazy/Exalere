import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../dpad/dpad.dart';
import '../tv_focusable.dart';

/// A single add-on row, in the shape Vega's provider list uses: a leading icon,
/// the name and version/source, and one trailing action.
///
/// Rows replaced the old poster-style cards because cards wasted most of a TV
/// screen: a horizontal shelf of 260 px cards filled barely a third of a 1080p
/// width. A list lets two columns of names be read at a glance and gives every
/// plugin the same hit area, so the whole row is the install button instead of
/// a 20 px pill inside the card.
///
/// TV rules: the whole row is one [TvFocusable] (one focus stop per plugin),
/// with the trailing action drawn inside that same surface. An installed row
/// that owns several actions passes its buttons as [trailing] and drops
/// [onTap], so the buttons become the focus stops instead.
class PluginRow extends StatelessWidget {
  const PluginRow({
    super.key,
    required this.name,
    this.subtitle,
    this.meta,
    this.iconUrl,
    this.iconAsset,
    this.trailing,
    this.onTap,
    this.focusNode,
    this.onDirection,
    this.dimmed = false,
    this.autofocus = false,
  });

  final String name;

  /// Secondary line: author, URL, description… shown muted under the name.
  final String? subtitle;

  /// Small chips rendered next to the name (version, category, state…).
  final List<Widget>? meta;

  /// Optional remote icon. Without one, the row draws an initials tile, which
  /// is what Vega itself falls back to for providers that ship no artwork.
  final String? iconUrl;

  /// Optional bundled icon, preferred over [iconUrl]: first-party add-ons must
  /// keep their artwork offline and on a TV with a flaky CDN.
  final String? iconAsset;

  /// Trailing control: an Install pill, a spinner, or a row of actions.
  final Widget? trailing;

  /// Whole-row activation. Null means the row itself is not a focus stop.
  final VoidCallback? onTap;

  final FocusNode? focusNode;
  final DpadDirectionCallback? onDirection;
  final bool dimmed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dimmed
            ? tokens.surfaceCard.withValues(alpha: 0.55)
            : tokens.surfaceCard,
        borderRadius: tokens.borderRadiusMd,
        border: Border.all(color: tokens.borderSubtle, width: 1.0),
      ),
      child: Row(
        children: [
          _PluginIconTile(
            name: name,
            iconUrl: iconUrl,
            iconAsset: iconAsset,
            dimmed: dimmed,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: dimmed
                              ? tokens.textSecondary
                              : tokens.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    if (meta != null) ...[const SizedBox(width: 8), ...meta!],
                  ],
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;

    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: onTap,
      onDirection: onDirection,
      scaleFactor: 1.02,
      borderRadius: tokens.borderRadiusMd,
      child: content,
    );
  }
}

/// Leading square tile: remote artwork when the catalogue provides it, initials
/// otherwise (Vega does the same for icon-less providers).
class _PluginIconTile extends StatelessWidget {
  const _PluginIconTile({
    required this.name,
    this.iconUrl,
    this.iconAsset,
    this.dimmed = false,
  });

  final String name;
  final String? iconUrl;
  final String? iconAsset;
  final bool dimmed;

  /// Deterministic accent per plugin name, so the same plugin keeps its colour
  /// between visits and providers are distinguishable at a glance.
  Color _accent(BuildContext context) {
    final tokens = context.tokens;
    final palette = <Color>[
      tokens.primaryAccent,
      tokens.secondaryAccent,
      tokens.liveColor,
      tokens.vipColor,
    ];
    var hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }

  /// Short label for the tile: "4K HD Hub" -> "4K", "MovieBox Engine" -> "MB",
  /// "RogMovies" -> "RO".
  String get _initials {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ').trim();
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return '?';
    if (words.first.contains(RegExp(r'\d'))) {
      return words.first
          .substring(0, words.first.length.clamp(0, 2))
          .toUpperCase();
    }
    if (words.length == 1) {
      final word = words.first;
      return word.substring(0, word.length.clamp(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accent = dimmed ? tokens.textMuted : _accent(context);

    Widget fallback() => Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: 0.4,
        ),
      ),
    );

    final url = iconUrl;
    final hasIcon = url != null && url.trim().isNotEmpty;
    final asset = iconAsset;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: tokens.borderRadiusSm,
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: asset != null
          ? Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => hasIcon
                  ? CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      placeholder: (context, _) => fallback(),
                      errorWidget: (context, _, _) => fallback(),
                    )
                  : fallback(),
            )
          : hasIcon
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (context, _) => fallback(),
              errorWidget: (context, _, _) => fallback(),
            )
          : fallback(),
    );
  }
}
