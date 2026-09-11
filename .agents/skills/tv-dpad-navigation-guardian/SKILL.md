---
name: tv-dpad-navigation-guardian
description: >-
  The definitive D-Pad navigation guardrail skill for Exalere Android TV.
  Enforces focus architecture, widget selection rules, spatial navigation
  patterns, and pre-commit validation. MUST be activated whenever creating a
  new screen, adding interactive widgets to an existing screen, or reviewing
  any TV-facing UI change.
---

# Exalere TV D-Pad Navigation Guardian

## When to Activate This Skill
Activate this skill whenever you are:
- Creating **any new screen or dialog** (TV or mobile-shared)
- Adding **any interactive element** to an existing TV-visible screen (buttons, cards, list items, tabs, toggles, chips)
- Refactoring layout of **existing TV screens**
- Building **horizontal or vertical scrolling shelves**
- Implementing **dialogs, bottom sheets, overlays, or side panels**

---

## 🏗️ Core Architecture Rules

### Rule 1 — The Only Valid TV Interactive Widget: `TvFocusable`

**Every** tappable, pressable, or selectable widget on a TV screen **MUST** be wrapped in `TvFocusable`. No exceptions.

```dart
// ✅ CORRECT
TvFocusable(
  borderRadius: context.tokens.borderRadiusSm,
  onTap: () => doSomething(),
  child: MyWidget(),
)

// ❌ FORBIDDEN — no focus glow, no D-Pad Select, invisible on TV
InkWell(onTap: () => doSomething(), child: MyWidget())
ElevatedButton(onPressed: () => doSomething(), child: ...)
TextButton(onPressed: () => doSomething(), child: ...)
ListTile(onTap: () => doSomething(), ...)
GestureDetector(onTap: () => doSomething(), child: ...)

// ⚠️ EXCEPTION — raw Focus() with full TvSpatialNavigation + onKeyEvent is
// acceptable ONLY in existing cards (ContinueWatchingCard, TopTenCard, MediaCard)
// that predate TvFocusable. All new code MUST use TvFocusable.
```

**Why**: `TvFocusable` provides: (a) glow border + scale animation on focus, (b) `TvSpatialNavigation.handleKeyEvent` for D-Pad directions, (c) Select/Enter/OK activation, (d) `Scrollable.ensureVisible` on focus change. Raw widgets provide none of these.

---

### Rule 2 — `HomeSectionHeader` "Explore All" Button

The `HomeSectionHeader` "Explore All" button uses a bare `InkWell`. On TV this is **unreachable** via D-Pad. Either:
- Replace with `TvFocusable` + `isTv` guard, OR
- Hide on TV (`if (!isTv) InkWell(...)`)

```dart
// ✅ TV-safe section header Explore button
if (onExplore != null)
  isTv
    ? TvFocusable(
        borderRadius: context.tokens.borderRadiusPill,
        onTap: onExplore,
        child: _exploreChild(context),
      )
    : InkWell(onTap: onExplore, child: _exploreChild(context))
```

---

### Rule 3 — Horizontal ListView / PageView Clip Budget

Every `ListView` / `PageView` / `SingleChildScrollView` with `scrollDirection: Axis.horizontal` that contains focusable cards **MUST** have:

```dart
ListView.builder(
  scrollDirection: Axis.horizontal,
  clipBehavior: Clip.none,       // ← MANDATORY: lets focus glow bleed outside
  cacheExtent: 350.0,            // ← MANDATORY: pre-renders next cards for spatial nav
  ...
)
```

The wrapping `SizedBox` height must be **at least card height + 20px** to prevent the scale-up animation (1.06×) from clipping:

| Card type | Card height | Minimum SizedBox height |
|---|---|---|
| `MediaCard` TV | 158 + label ~30 | `220` |
| `TvEpisodeCard` | 200 | `220` |
| `ContinueWatchingCard` TV | 122 | `144` ✅ (already correct) |
| `TopTenCard` TV | 168 | `190` |
| `TvMoreLikeThisShelf` | 155+label | `270` ✅ (fixed) |

---

### Rule 4 — Lazy ListView First-Card Focus Delegation

When a **lazy `ListView.builder`** (horizontal shelf) sits below another focusable row, the spatial nav engine may fail to find cards that haven't rendered yet. You **MUST** expose a `firstCardFocusNode` and let the row above explicitly focus it on D-Pad Down.

```dart
// Pattern for any horizontal shelf widget:
class MyHorizontalShelf extends StatelessWidget {
  final FocusNode? firstCardFocusNode; // ← expose this
  ...
  itemBuilder: (context, index) {
    return MyCard(
      focusNode: index == 0 ? firstCardFocusNode : null, // ← only first card
      ...
    );
  }
}

// In the parent screen:
final FocusNode _firstCardNode = FocusNode(debugLabel: 'FirstCard');

// In the row above's onKeyEvent or onDownFocus callback:
bool _handleDownFocus() {
  if (_firstCardNode.canRequestFocus) {
    _firstCardNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _firstCardNode.context != null) {
        Scrollable.ensureVisible(_firstCardNode.context!,
            alignment: 0.5, duration: const Duration(milliseconds: 250));
      }
    });
    return true;
  }
  return false;
}
```

---

### Rule 5 — Dialogs MUST Autofocus Their Primary Action

Every dialog opened on TV (via `showDialog`) **MUST** have exactly **one** `TvFocusable(autofocus: true)` as the primary / safe action button. All other buttons use `autofocus: false` (default).

```dart
// ✅ CORRECT
showDialog(context: context, builder: (_) => AlertDialog(
  actions: [
    TvFocusable(autofocus: true, onTap: () => Navigator.pop(context),
      child: Text('OK')),
    TvFocusable(autofocus: false, onTap: () => dangerousAction(),
      child: Text('Delete')),
  ],
));

// ❌ WRONG — focus lands on system chrome, user can't OK the dialog
showDialog(context: context, builder: (_) => AlertDialog(
  actions: [
    ElevatedButton(onPressed: ..., child: Text('OK')),
  ],
));
```

---

### Rule 6 — Focus Traversal Groups for Competing Row Elements

When a `Row` contains **multiple independent groups** of focusable items (e.g., season pills + a far-right toggle), wrap each group in its own `FocusTraversalGroup`:

```dart
Row(children: [
  FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: Row(children: [seasonPills...]),   // D-Pad Right stays within pills
  ),
  Spacer(),
  FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: TvFocusable(child: markSeasonButton),  // separate group
  ),
])
```

Without this, `TvSpatialNavigation`'s distance scoring may pick the far-right button over the next pill.

---

### Rule 7 — Back Button Handling

Every TV screen **MUST** handle the Back key (`LogicalKeyboardKey.goBack` / `LogicalKeyboardKey.escape`). Use `PopScope`:

```dart
PopScope(
  canPop: true,     // true for leaf screens, false for root screens
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) {
      // Optional: restore focus to the item that opened this screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previousFocusNode?.requestFocus();
      });
    }
  },
  child: Scaffold(...),
)
```

Root screens (main nav) must intercept Back and show an exit confirmation dialog (`TvExitDialog`) rather than exiting the app silently.

---

### Rule 8 — Focus Restoration After Route Pop

When pushing to `PlayerScreen` or `TvDetailsScreen`, store the previously focused node and restore it on return:

```dart
await Navigator.of(context).push(route);
if (mounted) {
  FocusScope.of(context).requestFocus(_playButtonFocusNode);
}
```

---

### Rule 9 — `SingleChildScrollView` (vertical) on TV Screens

The main content area of TV screens uses a vertical `SingleChildScrollView`. Ensure:
1. `TvFocusable._handleFocusChange` calls `Scrollable.ensureVisible(context, alignment: 0.5)` — this is built in and works automatically.
2. Never use `NeverScrollableScrollPhysics` on the outer scroll view — it breaks `ensureVisible`.
3. If embedding a `ListView` inside the vertical `SingleChildScrollView`, set the `ListView` to `shrinkWrap: true` only for very short lists. Long lists must be horizontal shelves.

---

### Rule 10 — `MediaCard`, `TopTenCard`, `ContinueWatchingCard` on TV

These three cards use raw `Focus` (not `TvFocusable`) for historical reasons. They implement `TvSpatialNavigation` manually. They are **approved exceptions**. Do NOT convert them to `TvFocusable` without a full regression test — the raw `Focus` approach works correctly for these specific widgets.

However, when wrapping them in **a new shelf** (like `TvMoreLikeThisShelf` previously broken), wrap them in `TvFocusable` at the shelf level so the glow/scale is applied by the parent.

---

## 📋 Pre-Commit Checklist

Before finalizing any PR or AI-generated change touching TV screens:

```
TV D-Pad Navigation Checklist
==============================
[ ] All new interactive widgets use TvFocusable (not InkWell/ElevatedButton/ListTile)
[ ] Every dialog has exactly one TvFocusable(autofocus: true) on the safe/primary action
[ ] All horizontal ListView.builders have clipBehavior: Clip.none AND cacheExtent: 350.0
[ ] SizedBox wrapping horizontal lists has height ≥ card_height + 20px
[ ] Any new horizontal shelf exposes firstCardFocusNode for D-Pad Down entry from above
[ ] Competing row elements (e.g., pills + far-right button) are in separate FocusTraversalGroups
[ ] PopScope is present on every new screen with canPop set correctly
[ ] Focus is restored after Navigator.pop() on every TV route push
[ ] No autofocus: true appears more than once in the same Focus scope
[ ] flutter analyze → 0 issues
[ ] dart format --output=none --set-exit-if-changed . → exit 0
[ ] python scripts/detect_hardcoded_styles.py → 0 violations
```

---

## 🔧 Verification Commands

```bash
# 1. Static analysis
flutter analyze --no-fatal-infos

# 2. Format check
dart format --output=none --set-exit-if-changed .

# 3. Hardcoded color audit
python scripts/detect_hardcoded_styles.py

# 4. Scan for bare InkWell/ElevatedButton/TextButton not inside tv_focusable.dart
# (These are candidates that need review on TV screens)
grep -rn "InkWell\|ElevatedButton\|TextButton\|ListTile" lib/ui/ \
  --include="*.dart" \
  | grep -v "tv_focusable\|media_card\|continue_watching_card\|top_ten_card\|canRequestFocus: false"

# 5. Scan for horizontal ListViews missing Clip.none
grep -rn "scrollDirection: Axis.horizontal" lib/ui/ --include="*.dart" -l \
  | xargs grep -L "clipBehavior: Clip.none"

# 6. D-Pad manual test via TV remote script
powershell -File tv_remote.ps1
```

---

## 🗺️ Focus Graph Reference (TV Details Screen — after fixes)

```
[TV Sidebar] ←Back only→ [Main Content]

Main Content vertical flow (D-Pad Down):
  [Play Button] → [My List] → [Trailer]
        ↓ (explicit firstCardFocusNode)
  [S1 pill] → [S2 pill] → [S3 pill]    [Mark Season ← separate FocusTraversalGroup]
        ↓ (explicit firstCardFocusNode)
  [Ep1] → [Ep2] → [Ep3] → [Ep4] ...
        ↓ (spatial nav)
  [More Like This: Card1] → [Card2] → [Card3] ...
```

---

## ⚠️ Known Remaining Issues (Backlog)

| File | Issue | Severity |
|---|---|---|
| `home_section_header.dart` | "Explore All" uses bare `InkWell` — unreachable on TV | Major |
| `continue_watching_card.dart` | Uses raw `Focus` (pre-TvFocusable) — no glow border on TV | Minor (functional, but visual inconsistency) |
| `top_ten_card.dart` | Uses raw `Focus` (pre-TvFocusable) — no glow border on TV | Minor |
| `media_card.dart` | Uses raw `Focus` (pre-TvFocusable) — no glow border on TV | Minor |
| `details_hero_view.dart` | `ElevatedButton` for Play/Trailer — used on mobile `details_screen.dart` only, not on TV | N/A (mobile only) |
| `details_screen.dart` | Many `InkWell`s — this is the mobile detail screen, not shown on TV | N/A (mobile only) |
| `player_screen.dart` | Mix of `InkWell` and `TvFocusable` in player controls — player has its own focus system | Needs separate audit |
