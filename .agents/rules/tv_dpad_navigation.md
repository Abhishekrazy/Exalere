# TV D-Pad Navigation Guardrail Rules

## Mandatory Rules for AI & Human Contributors

These rules apply to **every screen, dialog, widget, and shelf** that is visible on Android TV / Fire TV in Exalere.
Violation of any rule below will cause D-Pad navigation to break and will fail code review.

---

## 🚫 Forbidden Patterns on TV Screens

| ❌ Forbidden | ✅ Required Replacement | Why |
|---|---|---|
| `InkWell(onTap: ...)` | `TvFocusable(onTap: ...)` | No glow, no D-Pad Select |
| `ElevatedButton(onPressed: ...)` | `TvFocusable(onTap: ..., child: styled Container)` | No spatial navigation |
| `TextButton(onPressed: ...)` | `TvFocusable(onTap: ..., child: styled Container)` | No spatial navigation |
| `ListTile(onTap: ...)` | `TvFocusable(onTap: ..., child: custom Row)` | No glow, no D-Pad |
| `GestureDetector(onTap: ...)` (as root interactive) | `TvFocusable(onTap: ...)` | Not focusable by D-Pad |
| `IconButton(onPressed: ...)` | `TvFocusable(onTap: ..., child: Icon(...))` | Not focusable by D-Pad |
| `ListView.horizontal` without `clipBehavior: Clip.none` | Add `clipBehavior: Clip.none` | Focus glow gets clipped |
| `ListView.horizontal` without `cacheExtent: 350.0` | Add `cacheExtent: 350.0` | Spatial nav can't find off-screen cards |
| `SizedBox(height: H)` around horizontal shelf where H < cardHeight + 20 | Increase height | Scale animation clips |
| Dialog with no `TvFocusable(autofocus: true)` | Add autofocus to primary action button | User can't OK the dialog |
| Multiple `autofocus: true` in the same `FocusScope` | Only one per scope | Focus conflict / flicker |

---

## ✅ Mandatory Patterns

### 1. TvFocusable for All Interactive Elements
```dart
TvFocusable(
  borderRadius: context.tokens.borderRadiusSm,   // always use tokens
  scaleFactor: 1.06,                              // default; 1.08 for primary actions
  onTap: () => action(),
  child: Container(/* styled with tokens */),
)
```

### 2. Horizontal Shelf Template
```dart
SizedBox(
  height: cardHeight + 20,    // minimum: never clip the scale animation
  child: ListView.builder(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,   // mandatory
    cacheExtent: 350.0,        // mandatory
    itemBuilder: (context, index) => TvFocusable(
      focusNode: index == 0 ? firstCardFocusNode : null,  // expose first card
      onTap: () => onSelect(items[index]),
      child: MyCard(...),
    ),
  ),
)
```

### 3. Dialog Template
```dart
showDialog(
  context: context,
  barrierColor: context.tokens.shadowColor.withValues(alpha: 0.65),
  builder: (_) => Dialog(
    child: Column(children: [
      // ... title, content ...
      TvFocusable(
        autofocus: true,           // PRIMARY / SAFE action always gets autofocus
        onTap: () => Navigator.pop(context),
        child: Text('OK'),
      ),
      TvFocusable(
        autofocus: false,          // destructive or secondary actions: no autofocus
        onTap: () => dangerousAction(),
        child: Text('Delete'),
      ),
    ]),
  ),
);
```

### 4. Screen PopScope Template
```dart
PopScope(
  canPop: !isRootScreen,
  onPopInvokedWithResult: (didPop, _) {
    if (!didPop && isRootScreen) TvExitDialog.show(context);
  },
  child: Scaffold(...),
)
```

### 5. Competing Row Groups
```dart
// Any Row with multiple focusable groups separated by Spacer:
Row(children: [
  FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: /* left group: pills, tabs, etc. */,
  ),
  const Spacer(),
  FocusTraversalGroup(
    policy: OrderedTraversalPolicy(),
    child: /* right group: toggle, mark button, etc. */,
  ),
])
```

---

## 🧪 Required Pre-Commit Validation

Before finalizing any TV-visible change, run ALL of the following:

```bash
# Step 1: Analyze
flutter analyze --no-fatal-infos
# Must exit 0

# Step 2: Format
dart format --output=none --set-exit-if-changed .
# Must exit 0

# Step 3: Hardcoded colors
python scripts/detect_hardcoded_styles.py
# Must exit 0

# Step 4 (for modified files): spot-check InkWell/ElevatedButton
# If any appear in a TV-visible widget file, they need TvFocusable wrapping
```

---

## 📖 Full Documentation

See the complete skill with code patterns, focus graph, and architecture rationale at:
[`.agents/skills/tv-dpad-navigation-guardian/SKILL.md`](.agents/skills/tv-dpad-navigation-guardian/SKILL.md)
