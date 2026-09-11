# Antigravity & AI Contributor Skills

This directory contains workspace skills and rules recognized by **Google Antigravity**, **Gemini Code Assist**, and compatible AI coding tools.

## Included Skills

- [`exalere-contributor`](skills/exalere-contributor/SKILL.md): Validation runbook, coding standards, TV focus requirements, and analysis steps for AI agents.
- [`tv-dpad-navigation-guardian`](skills/tv-dpad-navigation-guardian/SKILL.md): **ACTIVATE FOR ALL TV UI WORK.** The definitive D-Pad navigation guardrail — enforces `TvFocusable` usage, horizontal shelf rules, dialog autofocus, `FocusTraversalGroup` patterns, first-card focus delegation, and the pre-commit checklist. Activate whenever creating or modifying any TV-visible screen, dialog, or widget.
- [`theme-and-tokens-enforcer`](skills/theme-and-tokens-enforcer/SKILL.md): Enforces zero-hardcoded colors and strict design token compliance. Runs the Python audit script.
- [`ui-designer-director`](skills/ui-designer-director/SKILL.md): Executive visual design authority, color tokens, 10-foot Leanback TV styling, glassmorphism, micro-animations, and cinematic aesthetics.
- [`ux-designer-director`](skills/ux-designer-director/SKILL.md): Executive user experience director, D-Pad spatial navigation graph theory, zero-friction playback, touch gestures, error recovery, and ergonomics.

## Included Rules

- [`tv_dpad_navigation.md`](rules/tv_dpad_navigation.md): Quick-reference forbidden/required patterns for TV D-Pad navigation. Auto-applied to every AI session via this directory.
- [`theme_and_tokens.md`](rules/theme_and_tokens.md): Forbidden hardcoded color patterns and required token replacements.

## How to Use With Your Agent

If you are using Google Antigravity or Gemini:
- The agent automatically discovers customizations in `.agents/`.
- You can reference or copy any skill folder from `.agents/skills/` into your personal `~/.gemini/config/skills/` directory if you want it globally available across all repositories on your machine.
