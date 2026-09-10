---
name: theme-and-tokens-enforcer
description: >-
  Enforces zero-hardcoded colors and strict design token compliance across Exalere Flutter UI components.
  Provides token replacement matrices, color scheme conventions, and runs the Python audit script
  (scripts/detect_hardcoded_styles.py) to guarantee all screens and widgets dynamically adapt to active themes.
---

# Theme & Design Tokens Enforcer

This skill guides AI agents and contributors to build, refactor, and review Exalere UI widgets using the centralized design system tokens instead of static/hardcoded values.

---

## 🎯 Primary Directives

1. **Zero Hardcoded Colors**: Under no circumstances should `Colors.black`, `Colors.white`, `Colors.amber`, or `Color(0xFF...)` be written in new or modified UI classes.
2. **Context Tokens First**: Always access visual properties via `context.tokens.<property>`.
3. **Theme ColorScheme for Semantic Elements**: Use `Theme.of(context).colorScheme.onPrimary` for text/icons on primary buttons, `Theme.of(context).colorScheme.primary` for primary interactive accents, and `Theme.of(context).colorScheme.surface` for semantic surfaces.
4. **Audit Before Finalizing**: Always run `python scripts/detect_hardcoded_styles.py --path <modified_file>` to verify 0 violations before declaring a task complete.

---

## 🎨 Token Reference & Replacement Cheat Sheet

### Colors & Surfaces
| Static Pattern | Correct Theme Token |
|---|---|
| `Colors.white` (text) | `context.tokens.textPrimary` |
| `Colors.white70` / `Colors.white60` | `context.tokens.textSecondary` |
| `Colors.white54` / `Colors.white38` | `context.tokens.textMuted` |
| `Colors.black` (text inside buttons) | `Theme.of(context).colorScheme.onPrimary` |
| `Colors.black` (text inside secondary pill)| `Theme.of(context).colorScheme.onSecondary` |
| `Colors.white10` / `Colors.white12` / `Colors.white24` (borders) | `context.tokens.borderSubtle` |
| `Colors.black.withValues(alpha: ...)` (shadows) | `context.tokens.shadowColor.withValues(alpha: ...)` |
| `Colors.black` (vignette/scrim) | `context.tokens.scrimGradient` |
| `Color(0xFF08090C)` (scaffolds) | `context.tokens.canvasBackground` |
| `Color(0xFF14171E)` (cards) | `context.tokens.surfaceCard` |
| `Color(0xFF1E232E)` (elevated modals) | `context.tokens.surfaceElevated` |
| `Colors.amber` (ratings / stars) | `context.tokens.vipColor` |
| `Colors.red` (errors / warnings) | `context.tokens.errorColor` |
| `Colors.green` (live streams) | `context.tokens.liveColor` |

### Radii & Corners
| Static Pattern | Correct Token |
|---|---|
| `BorderRadius.circular(4)` | `context.tokens.borderRadiusXs` or `AppRadius.borderXs` |
| `BorderRadius.circular(8)` | `context.tokens.borderRadiusSm` or `AppRadius.borderSm` |
| `BorderRadius.circular(12)` | `context.tokens.borderRadiusMd` or `AppRadius.borderMd` |
| `BorderRadius.circular(16)` | `context.tokens.borderRadiusLg` or `AppRadius.borderLg` |
| `BorderRadius.circular(999)` | `context.tokens.borderRadiusPill` or `AppRadius.borderPill` |

### Spacing
| Static Pattern | Correct Token |
|---|---|
| `SizedBox(width: 8, height: 8)` | `AppSpacing.gapSm` |
| `SizedBox(width: 12, height: 12)` | `AppSpacing.gapMd` |
| `SizedBox(width: 16, height: 16)` | `AppSpacing.gapLg` |
| `SizedBox(width: 24, height: 24)` | `AppSpacing.gapXl` |

---

## 🔍 Automated Verification Workflow

Whenever creating a new widget or modifying an existing one:

```bash
# 1. Audit the modified file
python scripts/detect_hardcoded_styles.py --path lib/ui/widgets/my_new_widget.dart

# 2. Check full UI directory
python scripts/detect_hardcoded_styles.py --path lib/ui/

# 3. Code format & static analysis
dart format .
flutter analyze
```

If the audit script flags any lines, replace them immediately according to the cheat sheet above until the script outputs:
`[SUCCESS] Zero hardcoded colors found! All components are using theme/tokens.`
