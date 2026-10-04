import 'dart:convert';
import 'package:flutter/material.dart';

/// User-customizable appearance preferences for subtitles.
class SubtitleStylePreferences {
  final double fontSize;
  final String colorPreset; // 'white', 'yellow', 'cyan', 'green'
  final double backgroundOpacity; // 0.0 to 1.0
  final String shadowStrength; // 'none', 'subtle', 'strong'

  const SubtitleStylePreferences({
    this.fontSize = 22.0,
    this.colorPreset = 'white',
    this.backgroundOpacity = 0.35,
    this.shadowStrength = 'subtle',
  });

  Color resolveTextColor(BuildContext context) {
    switch (colorPreset.toLowerCase()) {
      case 'yellow':
        return const Color(0xFFFFEB3B);
      case 'cyan':
        return const Color(0xFF00E5FF);
      case 'green':
        return const Color(0xFF69F0AE);
      case 'white':
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color resolveBackgroundColor() {
    if (backgroundOpacity <= 0.01) {
      return Colors.transparent;
    }
    return Color.fromRGBO(0, 0, 0, backgroundOpacity.clamp(0.0, 1.0));
  }

  List<Shadow>? resolveShadows(Color shadowColor) {
    switch (shadowStrength.toLowerCase()) {
      case 'none':
        return null;
      case 'strong':
        return [
          Shadow(
            color: shadowColor,
            blurRadius: 6.0,
            offset: const Offset(2, 2),
          ),
          Shadow(
            color: shadowColor,
            blurRadius: 10.0,
            offset: const Offset(3, 3),
          ),
        ];
      case 'subtle':
      default:
        return [
          Shadow(
            color: shadowColor,
            blurRadius: 4.0,
            offset: const Offset(1, 1),
          ),
          Shadow(
            color: shadowColor,
            blurRadius: 8.0,
            offset: const Offset(2, 2),
          ),
        ];
    }
  }

  /// Converts this style configuration to MPV property mappings.
  Map<String, String> toMpvProperties({bool isTv = false}) {
    final effectiveSize = (fontSize * (isTv ? 1.25 : 1.0)).round();

    // MPV hex format is #AARRGGBB or #RRGGBB
    String mpvColor;
    switch (colorPreset.toLowerCase()) {
      case 'yellow':
        mpvColor = '#FFFFEB3B';
        break;
      case 'cyan':
        mpvColor = '#FF00E5FF';
        break;
      case 'green':
        mpvColor = '#FF69F0AE';
        break;
      case 'white':
      default:
        mpvColor = '#FFFFFFFF';
        break;
    }

    final alphaHex = ((backgroundOpacity * 255).round().clamp(
      0,
      255,
    )).toRadixString(16).padLeft(2, '0');
    final mpvBackColor = '#${alphaHex}000000';

    final borderSize = shadowStrength == 'none'
        ? '0'
        : (shadowStrength == 'strong' ? '3' : '2');

    return {
      'sub-font-size': effectiveSize.toString(),
      'sub-color': mpvColor,
      'sub-back-color': mpvBackColor,
      'sub-border-size': borderSize,
    };
  }

  SubtitleStylePreferences copyWith({
    double? fontSize,
    String? colorPreset,
    double? backgroundOpacity,
    String? shadowStrength,
  }) {
    return SubtitleStylePreferences(
      fontSize: fontSize ?? this.fontSize,
      colorPreset: colorPreset ?? this.colorPreset,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      shadowStrength: shadowStrength ?? this.shadowStrength,
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'colorPreset': colorPreset,
    'backgroundOpacity': backgroundOpacity,
    'shadowStrength': shadowStrength,
  };

  factory SubtitleStylePreferences.fromJson(Map<String, dynamic> json) {
    return SubtitleStylePreferences(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 22.0,
      colorPreset: json['colorPreset'] as String? ?? 'white',
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.35,
      shadowStrength: json['shadowStrength'] as String? ?? 'subtle',
    );
  }

  String encode() => jsonEncode(toJson());

  static SubtitleStylePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SubtitleStylePreferences();
    }
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return SubtitleStylePreferences.fromJson(map);
      }
    } catch (_) {}
    return const SubtitleStylePreferences();
  }
}
