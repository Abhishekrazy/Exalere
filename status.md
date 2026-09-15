# Exalere Project Status & Migration Roadmap

**Mission**: Transition Exalere into a 100% Google Play Store compliant **"Personal Media Catalog & Universal Stream Player"** by adopting an external add-on architecture (Stremio-compatible), refreshing the UI/UX identity, and polishing TV Leanback navigation.

---

## 📌 Current Workstream & Active Branch

| Attribute | Value |
|---|---|
| **Active Branch** | `feat/tv-player-restart-continuous-seek` |
| **Current Task** | TV Player Restart relocation above seekbar & Continuous Seeking (30s fwd / 10s rew) |
| **Status** | 🟢 Completed (Ready to merge) |
| **Base Branch** | `main` |

---

## 🗺️ Master Roadmap & Epics

```
┌────────────────────────────────────────────────────────┐
│  EPIC 1: TV Leanback & Player Interaction Polish       │  ◄── [ACTIVE]
├────────────────────────────────────────────────────────┤
│  EPIC 2: Decoupled Addon Architecture (Stremio-Compat) │
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

---

### Epic 2: Decoupled Addon Architecture (Stremio-Compatible)
*Extracting scrapers and video providers into external community add-ons to guarantee 100% legal compliance for Google Play Store.*

- [ ] **Task 2.1: Addon Protocol Specification & Engine**
  - [ ] Define Stremio Addon Protocol v1 compatible client in Flutter.
  - [ ] Support `/manifest.json` (addon name, version, resources, types, catalogs).
  - [ ] Support `/stream/{type}/{id}.json` (TMDB ID to direct streams and subtitles).
  - [ ] Build `AddonService` and `AddonProvider` for local persistence in `SharedPreferences`.

- [ ] **Task 2.2: Extract Built-in Providers to External Worker / Microservice**
  - [ ] Extract `fourkhdhub` scraper logic into a standalone open-source repository (Cloudflare Worker / Node.js).
  - [ ] Extract `moviebox` scraper logic into an addon endpoint.
  - [ ] Provide sample boilerplate for community developers to create custom addons.

- [ ] **Task 2.3: In-App Addon Manager UI**
  - [ ] Add "Stream Add-ons" section in Settings.
  - [ ] Support manual URL entry (`https://.../manifest.json`).
  - [ ] Add QR code scanner (using camera on mobile, or display QR code on TV to pair from phone).
  - [ ] Add list of installed addons with toggle (Enable/Disable), reload, and delete actions.

- [ ] **Task 2.4: Clean Core App Binary of Pirate Domains**
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

- [ ] **Task 4.1: Policy & Asset Verification**
  - [ ] Ensure Dynamic Code Loading (DCL) compliance (no remote binary/dex loading).
  - [ ] Prepare store screenshots showcasing TMDB discovery, trailers, and personal playlists.
  - [ ] Draft non-infringing Store Description, Privacy Policy, and Terms of Service.
- [ ] **Task 4.2: Release Build Pipeline**
  - [ ] Android App Bundle (`.aab`) configuration.
  - [ ] Android TV Leanback banner & launcher icon compliance.
  - [ ] Final `flutter analyze`, `flutter test`, and hardcoded style checks.

---

## 📜 Branch & Commit Changelog

| Branch | Date | Commit Hash | Summary |
|---|---|---|---|
| `feat(player/tv)` | 2026-09-15 | `faca5af` | Added initial D-Pad accessible Restart button in TV controls and resume toast |
| `feat/tv-player-restart-continuous-seek` | 2026-09-15 | `d271a41` | Moved Restart above seekbar, implemented continuous seek (30s fwd / 10s rew) |
