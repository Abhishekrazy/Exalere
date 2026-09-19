# Exalere Project Status & Migration Roadmap

**Mission**: Transition Exalere into a 100% Google Play Store compliant **"Personal Media Catalog & Universal Stream Player"** by adopting an external plugin architecture (Exalere Plugin Protocol), refreshing the UI/UX identity, and polishing TV Leanback navigation.

---

## 📌 Current Workstream & Active Branch

| Attribute | Value |
|---|---|
| **Active Branch** | `feat/plugin-stremio-community-catalog` |
| **Current Task** | Task 2.4: Stremio Addon Protocol Compatibility & 1-Click Community Catalog |
| **Status** | 🟢 Completed |
| **Base Branch** | `main` |

---

## 🗺️ Master Roadmap & Epics

```
┌────────────────────────────────────────────────────────┐
│  EPIC 1: TV Leanback & Player Interaction Polish       │  ◄── [COMPLETED]
├────────────────────────────────────────────────────────┤
│  EPIC 2: Decoupled Exalere Plugin Architecture         │  ◄── [ACTIVE]
├────────────────────────────────────────────────────────┤
│  EPIC 3: UI/UX Identity Overhaul (Catalog & Player)    │
├────────────────────────────────────────────────────────┤
│  EPIC 4: Play Store Compliance, Assets & Release Prep  │
└────────────────────────────────────────────────────────┘
```

---

### Epic 1: TV Leanback & Player Interaction Polish (Current)
*Refining TV remote ergonomics, seek mechanics, and player screen accessibility.*

- [x] **Task 1.1: TV Player Seeking & Restart Relocation** (`feat/tv-player-restart-continuous-seek`)
  - [x] Move Restart button above the TV Seekbar with clean pill styling.
  - [x] Implement seamless vertical D-Pad focus graph: `Back` ↕ `Restart` ↕ `Seekbar` ↕ `Action Buttons`.
  - [x] Remove Restart button from bottom action bar.
  - [x] Implement continuous seeking on D-Pad Left/Right hold (capturing `KeyRepeatEvent`).
  - [x] Update forward seek interval to **30 seconds** (backward remains **10 seconds**).
  - [x] Update desktop/TV keyboard shortcuts and touch gesture HUD to reflect 30s forward.
  - [x] Zero hardcoded color violations and pass all tests.

- [ ] **Task 1.2: TV Player Grid Layout & Remote Quick Actions**
  - [ ] Evaluate secondary quick-actions above the seekbar (Aspect Ratio, Audio track quick-toggle).
  - [ ] Ensure focus preservation when overlays/sheets are dismissed.

- [x] **Task 1.3: TV Category Discovery, Dedicated Search Screen & Voice Search** (`feat/tv-search-category-voice`)
  - [x] Eliminate TV focus trapping and software keyboard popups by removing inline TextField from default screen.
  - [x] Transform default SearchScreen into a keyboard-free Category Discovery screen with prominent Search and Voice triggers.
  - [x] Implement TV D-Pad optimized horizontal Category Shelf with `TvFocusable` chips and smooth bi-directional focus navigation.
  - [x] Create dedicated `ActiveSearchScreen` with isolated search bar, live results grid, and D-Pad clamp/navigation.
  - [x] Integrate `speech_to_text` and `VoiceSearchService` for remote microphone and voice search with animated listening indicator.
  - [x] Zero hardcoded color violations, 100% theme token compliance, and all unit/widget tests passing.

---

### Epic 2: Decoupled Exalere Plugin Architecture
*Extracting scrapers and video providers into external community plugins to guarantee 100% legal compliance for Google Play Store.*

- [x] **Task 2.1: Plugin Protocol Specification & Engine**
  - [x] Define Exalere Plugin Protocol client in Flutter.
  - [x] Support `/manifest.json` (plugin name, version, resources, types, catalogs).
  - [x] Support `/stream/{type}/{id}.json` (TMDB ID to direct streams and subtitles).
  - [x] Build `PluginService` and `PluginProvider` for local persistence in `SharedPreferences`.

- [x] **Task 2.2: Extract Built-in Providers to External Worker / Microservice**
  - [x] Create standalone open-source repository template (`plugins/exalere-stream-worker/`).
  - [x] Provide sample boilerplate for community developers to create custom plugins on Cloudflare Workers / Node.js.

- [x] **Task 2.3: In-App Plugin Manager UI**
  - [x] Add "Stream Plugins" section in Settings (Mobile & Desktop).
  - [x] Support manual URL entry (`https://.../manifest.json`).
  - [x] Add TV D-Pad focus compliant subpage in `TvSettingsView`.
  - [x] Add list of installed plugins with toggle (Enable/Disable), reload, and delete actions.

- [x] **Task 2.4: Stremio Addon Protocol Compatibility & 1-Click Community Catalog** (`feat/plugin-stremio-community-catalog`)
  - [x] Support Stremio Addon Protocol v1 URL scheme normalization (`stremio://` and `exalere://` to `https://`).
  - [x] Auto-resolve IMDb ID (`tt...`) from TMDB metadata during stream queries so Stremio addons receive IMDb IDs.
  - [x] Build curated 1-Click Community Plugin Catalog (`Exalere Community Worker`, `Torrentio`, `SuperFlix`, `OpenSubtitles v3`).
  - [x] Create TV D-Pad compliant horizontal shelf in `TvSettingsView` (`_TvPluginsSubpage`) with zero-typing remote install.
  - [x] Add responsive Community Plugin Catalog cards to Mobile/Desktop `PluginsSettingsSection` with live install states.
  - [x] 100% theme tokens compliance, zero hardcoded colors, and all unit/integration tests passing.

- [ ] **Task 2.5: Clean Core App Binary of Pirate Domains**
  - [ ] Remove all hardcoded third-party scraper URLs, pirate domains, and decryption keys from the core repository.
  - [ ] Ensure binary analysis contains zero copyright-infringing strings.

---

### Epic 3: UI/UX Identity Overhaul ("Personal Media Catalog & Universal Stream Player")
*Rethinking the catalog and player UI to emphasize personal media management, metadata, and universal playback.*

- [ ] **Task 3.1: Catalog & Details Screen Redesign**
  - [ ] Reposition Media Details to emphasize TMDB metadata, high-res posters/backdrops, trailers, cast, and genres.
  - [ ] Make the primary hero action "Play Trailer" (YouTube) or "Watch via Addons" when streams are available.
  - [ ] Introduce a clean "Where to Watch / Stream Sources" bottom sheet listing installed addon streams with source tags.

- [ ] **Task 3.2: Universal Stream & Local Media Support**
  - [ ] Enhance IPTV / M3U playlist integration.
  - [ ] Add local file / network playback (SMB/DLNA/WebDAV/Direct URL entry).
  - [ ] Position Exalere as a powerhouse universal player (media_kit + libmpv).

---

### Epic 4: Google Play Store Compliance & Release Preparation
*Validating policies, store assets, automated verification, and production builds.*

- [x] **Task 4.1: Store Assets & Promotional Media Production** (`release_assets/`)
  - [x] High-res official store App Icon (`512x512 PNG`, 32-bit with alpha).
  - [x] Cinematic Play Store Feature Graphic (`1024x500 PNG`).
  - [x] Android TV Leanback Banner (`1280x720 PNG`) and updated app launcher resource.
  - [x] Play Store Landscape Promotional Video (`1920x1080`, 16:9, H.264 / AAC 320k) rendered via ComfyUI LTX-Video + Minimax Music + FFmpeg ducking.
  - [x] Instagram Vertical Promotional Video (`1080x1920`, 9:16, H.264 / AAC 320k) for Reels and Stories.
- [ ] **Task 4.2: Policy Verification & Metadata**
  - [ ] Ensure Dynamic Code Loading (DCL) compliance (no remote binary/dex loading).
  - [ ] Prepare store screenshots showcasing TMDB discovery, trailers, and personal playlists.
  - [ ] Draft non-infringing Store Description, Privacy Policy, and Terms of Service.
- [ ] **Task 4.3: Release Build Pipeline**
  - [ ] Android App Bundle (`.aab`) configuration.
  - [ ] Final `flutter analyze`, `flutter test`, and hardcoded style checks.

---

## 📜 Branch & Commit Changelog

| Branch | Date | Commit Hash | Summary |
|---|---|---|---|
| `feat(player/tv)` | 2026-09-15 | `faca5af` | Added initial D-Pad accessible Restart button in TV controls and resume toast |
| `feat/tv-player-restart-continuous-seek` | 2026-09-15 | `d271a41` | Moved Restart above seekbar, implemented continuous seek (30s fwd / 10s rew) |
| `feat/exalere-plugin-engine` | 2026-09-15 | `5ae4eac` | Exalere Plugin Protocol engine, PluginProvider, TV/Mobile Settings UI, and Worker template |
| `feat/exalere-plugin-engine` | 2026-09-16 | `21c6d30` | Generated Play Store graphics (Icon, Feature, TV Banner) and 2 promo video formats via ComfyUI |
| `feat/exalere-plugin-engine` | 2026-09-16 | `f10dbf3` | Updated store graphics and promo video pipeline with authentic Exalere geometric logo |
| `feat/tv-search-category-voice` | 2026-09-19 | `c365261` | Decouple category discovery, dedicated search screen, and voice search for TV |
