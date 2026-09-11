/// D-pad navigation for Flutter TV apps — Android TV, Fire TV, Apple TV and
/// anything driven by a remote or game controller.
///
/// ## Quick start
///
/// 1. Install the root with `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: Dpad.wrap(),
///   home: const HomePage(),
/// )
/// ```
///
/// 2. Make widgets focusable:
///
/// ```dart
/// DpadFocusable(
///   autofocus: true,
///   onSelect: () => playMovie(movie),
///   child: PosterCard(movie),
/// )
/// ```
///
/// 3. Structure screens into regions:
///
/// ```dart
/// DpadRegion(            // a poster row that remembers its position
///   child: SizedBox(
///     height: 200,
///     child: ListView(scrollDirection: Axis.horizontal, children: cards),
///   ),
/// )
/// ```
///
/// ## Building blocks
///
/// * [Dpad] — the root: key handling, focus resilience, programmatic
///   control via [Dpad.of].
/// * [DpadFocusable] — a focus target with select / long-select, pressed
///   state and focus effects.
/// * [DpadRegion] — groups items with TV semantics: focus memory
///   ([DpadEnterBehavior]) and per-axis edge control ([DpadEdgeBehavior]).
/// * [DpadEffect] — composable focus visuals ([DpadScaleEffect],
///   [DpadGlowEffect], [DpadBorderEffect], ...), themable through
///   [DpadTheme].
/// * [DpadTraversalPolicy] — the TV-correct directional engine, installed
///   automatically by [Dpad] and [DpadRegion].
library;

export 'src/effects.dart';
export 'src/focusable.dart';
export 'src/key_set.dart';
export 'src/region.dart';
export 'src/root.dart';
export 'src/scroll.dart';
export 'src/theme.dart';
export 'src/traversal.dart';
