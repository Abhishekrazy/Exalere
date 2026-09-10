---
name: exalere-contributor
description: >-
  Essential instructions and validation runbook for AI coding agents contributing
  to the Exalere Flutter media streaming application. Activate when developing,
  refactoring, fixing bugs, or adding TV navigation features to Exalere.
---

# Exalere Contributor Runbook

This skill provides step-by-step procedures for AI agents modifying or adding features to Exalere.

## Core Procedures

### 1. Pre-Modification Inspection
- Review relevant widgets in `lib/ui/` and services in `lib/services/`.
- Check whether the screen is accessed in TV Mode:
  - Check `app.isTvMode` or responsive layout thresholds.
  - Verify if `TvFocusable` or focus trees are used.

### 2. Making Code Changes
- **TV Focus Rule**: When adding interactive elements (buttons, cards, tiles), make sure TV D-Pad focus is supported.
- **Provider Pattern**: Read models via `context.read<T>()` in callbacks; watch via `context.watch<T>()` or `Consumer<T>` in `build()`.
- **Null Safety**: Always handle possible null media backdrops, poster URLs, and stream sources.

### 3. Verification & Validation Steps
Always run these checks before finishing your task:

```bash
# 1. Static Analysis
flutter analyze

# 2. Format verification
dart format --output=none --set-exit-if-changed .
```

### 4. Testing ADB / Android TV Remote
If testing against an Android TV emulator:
- Launch `tv_remote.ps1` to test D-Pad keys (Up/Down/Left/Right/Enter/Back).
