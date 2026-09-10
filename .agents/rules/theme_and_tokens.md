# Theme & Design Tokens Enforcement Rule

## Mandatory Rule for AI & Human Contributors
All UI components, screens, dialogs, sheets, and widgets in Exalere **MUST** derive their colors, typography, borders, shadows, and radii from the centralized design token system (`context.tokens` and `Theme.of(context).colorScheme`).

**Hardcoding colors or static styles in UI components is strictly prohibited.**

---

## 🚫 Prohibited Code Patterns
The following patterns will fail automated checks:
- ❌ `Colors.black` / `Colors.white` / `Colors.amber` / `Colors.red` / `Colors.blue` / `Colors.grey` / etc.
- ❌ `Colors.white.withValues(alpha: ...)` or `Colors.black.withValues(alpha: ...)`
- ❌ `Color(0xFF...)` or `const Color(0x...)` inside widgets
- ❌ `Colors.white10`, `Colors.white12`, `Colors.white24`, `Colors.white54`, `Colors.white70`

*(Note: `Colors.transparent` is permitted when zero alpha is required).*

---

## ✅ Approved Design Token Equivalents

| Hardcoded Pattern | Required Replacement | Purpose |
|---|---|---|
| `Colors.white` (text) | `context.tokens.textPrimary` | Primary headings & high-emphasis text |
| `Colors.white70` / `white60` | `context.tokens.textSecondary` | Subtitles, captions, metadata |
| `Colors.white38` / `white24` | `context.tokens.textMuted` | Disabled, placeholder, or muted hints |
| `Colors.black` (text on primary button) | `Theme.of(context).colorScheme.onPrimary` | Dynamic contrast against accent buttons |
| `Colors.black` (text on secondary button)| `Theme.of(context).colorScheme.onSecondary` | Dynamic contrast against secondary badges |
| `Colors.white10` / `white12` (borders) | `context.tokens.borderSubtle` | Standard card and dialog borders |
| `Colors.black` (shadows / scrims) | `context.tokens.shadowColor` / `context.tokens.scrimGradient` | Elevation shadows and bottom card gradients |
| `Color(0xFF14171E)` (cards) | `context.tokens.surfaceCard` | Card backgrounds |
| `Color(0xFF1E232E)` (surfaces) | `context.tokens.surfaceElevated` | Elevated modals, badges, inputs |
| `Color(0xFF08090C)` (scaffolds) | `context.tokens.canvasBackground` | Screen canvas background |
| `Colors.amber` / gold badges | `context.tokens.vipColor` | VIP, IMDb rating stars, badges |
| `Colors.red` / error | `context.tokens.errorColor` | Error states and warnings |
| `Colors.green` / online | `context.tokens.liveColor` | Live streams, online indicators |

---

## 🛠️ Verification Tool
Before submitting code, contributors and agents **must** run:
```bash
python scripts/detect_hardcoded_styles.py
```
Or for a specific file:
```bash
python scripts/detect_hardcoded_styles.py --path lib/ui/screens/my_screen.dart
```
The audit must exit with **code 0** and zero violations.
