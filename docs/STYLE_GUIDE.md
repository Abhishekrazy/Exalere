# 🎨 Exalere Centralized Design System & Style Guide

Welcome to the **Exalere Centralized Design System**. This architecture guarantees that the entire visual appearance of Exalere (across Android Mobile, Android TV, and Windows Desktop) can be styled, themed, and rebranded from **one single place** (`lib/ui/theme/`), without ever needing to edit hundreds of individual widget files.

---

## 🏛️ System Architecture

The styling system is split into two complementary layers in `lib/ui/theme/`:

1. **`app_tokens.dart`**: Global, invariant design tokens (Spacing, Border Radii, Typography, Motion, Shadows, Elevation).
2. **`app_themes.dart`**: Dynamic color presets & `ThemeExtension<AppDesignTokens>` (Netflix Obsidian, Hotstar Midnight, TokyoNight, Catppuccin, Nord, Dracula, Midnight OLED).

```
lib/ui/theme/
├── app_tokens.dart        <-- Spacing, Radius, Motion, Typography & AppDesignTokens class
└── app_themes.dart        <-- Theme presets & ThemeData configurations with tokens attached
```

---

## 📦 Design Token Catalog

### 1. Spacing & Gaps (`AppSpacing`)
Instead of hardcoding `SizedBox(height: 16)` or `EdgeInsets.all(12)`:

| Token | Value | Helper Usage |
| :--- | :---: | :--- |
| `AppSpacing.xxs` | `2.0` | `AppSpacing.gapXxs` |
| `AppSpacing.xs` | `4.0` | `AppSpacing.gapXs`, `AppSpacing.paddingXs` |
| `AppSpacing.sm` | `8.0` | `AppSpacing.gapSm`, `AppSpacing.paddingSm` |
| `AppSpacing.md` | `12.0` | `AppSpacing.gapMd`, `AppSpacing.paddingMd` |
| `AppSpacing.lg` | `16.0` | `AppSpacing.gapLg`, `AppSpacing.paddingLg` |
| `AppSpacing.xl` | `24.0` | `AppSpacing.gapXl`, `AppSpacing.paddingXl` |
| `AppSpacing.xxl` | `32.0` | `AppSpacing.gapXxl`, `AppSpacing.paddingXxl` |
| `AppSpacing.screen(isTv)` | Dynamic | Automatically applies 40dp horizontal padding on TV vs 16dp on mobile |

---

### 2. Corner Radii (`AppRadius`)
Instead of writing `BorderRadius.circular(12)` in every card:

| Token | Value | Helper Usage |
| :--- | :---: | :--- |
| `AppRadius.xs` | `4.0` | `AppRadius.borderXs` |
| `AppRadius.sm` | `8.0` | `AppRadius.borderSm` (small chips, badges) |
| `AppRadius.md` | `12.0` | `AppRadius.borderMd` (standard movie/series cards) |
| `AppRadius.lg` | `16.0` | `AppRadius.borderLg` (dialogs, bottom sheets) |
| `AppRadius.xl` | `20.0` | `AppRadius.borderXl` (hero carousel banners) |
| `AppRadius.pill` | `999.0` | `AppRadius.borderPill` (stadium/pill buttons) |

> 💡 **Want square cards across the entire app?** Simply change `AppRadius.md = 4.0;` in `app_tokens.dart` and all cards update instantly.

---

### 3. Motion & Transitions (`AppMotion`)

| Token | Value | Purpose |
| :--- | :---: | :--- |
| `AppMotion.fast` | `150ms` | Button presses, micro-feedback |
| `AppMotion.normal` | `250ms` | TV remote D-Pad focus transitions, drawer opening |
| `AppMotion.slow` | `400ms` | Modal overlays, screen transitions |
| `AppMotion.tvFocusScale` | `1.06` | Android TV D-Pad active item zoom factor |
| `AppMotion.desktopHoverScale`| `1.02` | Desktop mouse pointer hover scale |
| `AppMotion.curveDefault` | `Curves.easeInOutCubic` | Smooth natural deceleration |

---

### 4. Dynamic Theme Colors (`context.tokens`)
Any widget in the tree can access the currently selected theme's color tokens with `context.tokens`:

```dart
// Backgrounds
context.tokens.canvasBackground    // Deep cosmic background
context.tokens.surfaceCard          // Card & list item background
context.tokens.surfaceElevated      // Popups, modals, elevated surfaces
context.tokens.surfaceGlass         // Frosted glassmorphism background

// Borders & Accents
context.tokens.borderSubtle         // Hairline borders between elements
context.tokens.borderFocus          // Luminous focus ring on TV remote focus
context.tokens.primaryAccent        // Primary brand color (Netflix Red, Hotstar Cyan, etc.)
context.tokens.secondaryAccent      // Supporting secondary highlight color

// Gradients
context.tokens.heroGradient         // Banner/Button vibrant gradient
context.tokens.scrimGradient        // Smooth backdrop fade over posters

// Text & Status
context.tokens.textPrimary          // High-contrast primary text (White)
context.tokens.textSecondary        // Readable subtitle text
context.tokens.liveColor            // Live broadcast indicator green (#10B981)
context.tokens.vipColor             // Rating & star amber (#FFB800)
```

---

## 💻 Code Comparison (Before vs After)

### ❌ Old Way (Hardcoded values scattered everywhere):
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF14171E),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFF222836)),
  ),
  child: Text(
    'Watch Now',
    style: TextStyle(color: Colors.white, fontSize: 14),
  ),
);
```

### ✅ New Way (Using Centralized Tokens):
```dart
Container(
  padding: AppSpacing.paddingLg,
  decoration: BoxDecoration(
    color: context.tokens.surfaceCard,
    borderRadius: AppRadius.borderMd,
    border: Border.all(color: context.tokens.borderSubtle),
  ),
  child: Text(
    'Watch Now',
    style: AppTypography.button.copyWith(color: context.tokens.textPrimary),
  ),
);
```

---

## 🚀 How to Create an Entirely New Theme in 5 Minutes

Want to add a brand new theme (for example, **Cyberpunk Neon** or **Emerald Forest**)? You only modify `lib/ui/theme/app_themes.dart`:

1. Define your new tokens:
```dart
static final AppDesignTokens cyberpunkTokens = const AppDesignTokens(
  canvasBackground: Color(0xFF0D0221),
  surfaceCard: Color(0xFF1E0E3E),
  surfaceElevated: Color(0xFF2E175C),
  surfaceGlass: Color(0x991E0E3E),
  borderSubtle: Color(0xFF432082),
  borderFocus: Color(0xFF00F0FF),
  primaryAccent: Color(0xFF00F0FF),
  secondaryAccent: Color(0xFFFF007F),
  textPrimary: Colors.white,
  textSecondary: Color(0xFFD6C7FF),
  textMuted: Color(0xFF8B6BCE),
  liveColor: Color(0xFF00FF66),
  vipColor: Color(0xFFFFE600),
  errorColor: Color(0xFFFF0055),
  heroGradient: LinearGradient(
    colors: [Color(0xFF00F0FF), Color(0xFFFF007F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  scrimGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC0D0221), Color(0xFF0D0221)],
  ),
);
```

2. Wrap it into an `AppThemeOption`:
```dart
static final AppThemeOption cyberpunk = AppThemeOption(
  name: 'Cyberpunk Neon',
  primaryColor: const Color(0xFF00F0FF),
  backgroundColor: const Color(0xFF0D0221),
  cardColor: const Color(0xFF1E0E3E),
  tokens: cyberpunkTokens,
  themeData: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0221),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00F0FF),
      secondary: Color(0xFFFF007F),
      surface: Color(0xFF1E0E3E),
      error: Color(0xFFFF0055),
    ),
    extensions: [cyberpunkTokens],
  ),
);
```

3. Add it to `allThemes`:
```dart
static final List<AppThemeOption> allThemes = [
  netflixBlack,
  jioHotstar,
  tokyoNight,
  catppuccin,
  nord,
  dracula,
  midnightOled,
  cyberpunk, // <-- Added here!
];
```

That's it! Every screen, dialog, card, focus glow, and button will adapt dynamically to the new theme immediately!
