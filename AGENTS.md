# Exalere AI & Contributor Rules (AGENTS.md)

This file defines guidelines and architectural constraints for any AI coding agent (such as Google Antigravity, Gemini Code Assist, Cursor, Claude, Copilot) or human contributor working on the **Exalere** codebase.

---

## 🏛️ Project Architecture & Stack

- **Framework**: Flutter 3.13.2+ (Null-Safety)
- **Supported Targets**:
  - Android Mobile & Tablet
  - Android TV / Fire TV (Leanback / D-Pad driven)
  - Windows Desktop (64-bit)
- **State Management**: `Provider` (`ChangeNotifierProvider`, `Consumer`, `context.watch/read`)
- **Video Playback Engine**: `media_kit` + `media_kit_video` (libmpv), plus external player handoff (VLC / Just Player) via `url_launcher`
- **Data & APIs**:
  - TMDB API via `tmdb_service.dart`
  - Multi-provider video decoders & stream parsers (`fourkhdhub_provider.dart`, `moviebox_provider.dart`, `iptv_provider.dart`)
  - Local caching via `shared_preferences` and custom file caching

---

## 🚨 Critical Rules for Code Contributions

### 1. Android TV & D-Pad Compatibility
- **Never break TV navigation**: Every clickable, selectable, or interactive widget on TV-supported screens **MUST** be wrapped in `TvFocusable`. No bare `InkWell`, `ElevatedButton`, `TextButton`, `ListTile`, or `GestureDetector` as the root interactive widget on TV.
- Always support directional D-Pad keys (Up, Down, Left, Right, Select/Enter, Back) via `TvFocusable` + `TvSpatialNavigation`.
- Ensure focus order is logical and does not trap the user.
- **Horizontal shelves**: Every `ListView` with `scrollDirection: Axis.horizontal` containing focusable items MUST have `clipBehavior: Clip.none` AND `cacheExtent: 350.0`. The wrapping `SizedBox` height must be `≥ cardHeight + 20px` to prevent scale-animation clipping.
- **Dialogs**: Every dialog shown on TV must have exactly one `TvFocusable(autofocus: true)` on the primary/safe action button.
- **Competing row groups**: When a `Row` contains separate focusable groups (e.g., tabs + a far-right toggle), wrap each group in a `FocusTraversalGroup(policy: OrderedTraversalPolicy())` to prevent spatial nav from jumping to the wrong element.
- **Lazy ListView first card**: Expose a `firstCardFocusNode` parameter from every horizontal shelf widget so the parent screen can explicitly focus the first card on D-Pad Down from the row above.
- See full guardrail skill: [`.agents/skills/tv-dpad-navigation-guardian/SKILL.md`](.agents/skills/tv-dpad-navigation-guardian/SKILL.md)
- See quick-reference rule: [`.agents/rules/tv_dpad_navigation.md`](.agents/rules/tv_dpad_navigation.md)

### 2. State Management & Performance
- Keep state mutations inside appropriate `ChangeNotifier` classes (`AppProvider`, `LibraryProvider`, `CastProvider`).
- Avoid putting heavy synchronous parsing or decryption operations on the UI isolate. Utilize background isolates or microtasks where necessary.
- Clean up controllers, video listeners, and stream subscriptions in `dispose()`.

### 3. Video Playback & External Players
- Always handle stream loading states, timeouts, and player errors gracefully with user-friendly retry prompts.
- Ensure fallback to external players (VLC, MX Player) functions properly when hardware decoders fail.

### 4. Code Quality & Formatting
- **Zero Warnings**: Code must pass `flutter analyze` cleanly.
- Do not introduce arbitrary external dependencies without maintainer alignment.
- Adhere to effective Dart formatting standards (`flutter format .`).

### 5. Licensing & Non-Commercial Constraint
- All contributions are licensed under the **PolyForm Noncommercial License 1.0.0**.
- Do not include proprietary, closed-source, or commercial SDKs that contradict this license.

### 6. Zero Hardcoded Colors & Static Styling (Theme & Design Tokens)
- **Zero hardcoded colors in widgets**: NEVER use `Colors.black`, `Colors.white`, `Colors.amber`, `Color(0xFF...)`, or `Colors.white12/24/70` directly in UI widgets.
- **Always use theme tokens**:
  - Surfaces & Accents: `context.tokens.surfaceCard`, `context.tokens.surfaceElevated`, `context.tokens.primaryAccent`, `context.tokens.secondaryAccent`.
  - Text: `context.tokens.textPrimary`, `context.tokens.textSecondary`, `context.tokens.textMuted`, or `Theme.of(context).colorScheme.onPrimary` (on accent buttons).
  - Borders & Shadows: `context.tokens.borderSubtle`, `context.tokens.borderFocus`, `context.tokens.shadowColor`.
  - Gradients & Overlays: `context.tokens.scrimGradient`, `context.tokens.heroGradient`.
- **Pre-commit Audit**: Run `python scripts/detect_hardcoded_styles.py --path <modified_file>` before finalizing changes. Any hardcoded color violation will fail review.

### 7. Mandatory Code Formatting Before Commit
- **Format check**: Always format code using `dart format .` before staging and committing.
- Verify with `dart format --output=none --set-exit-if-changed .` to ensure exit code 0.
- CI will strictly reject any commits that contain unformatted Dart code.
