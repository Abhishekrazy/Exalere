# Changelog

All notable changes to the **Exalere** media streaming project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.0.1] - 2026-11-20

Patch release: the provider layer's badges become falsifiable. Every verified add-on
now has to prove that a *stream plays for this title*, not merely that a URL came
back, and a badge was taken away when the difference turned out to matter.

### Provider layer
- **Movies4U is verified** (24 sources). Its site moved to `movies4u.vet` (`.cr`
  redirects and the redirect breaks the listing parse), its posts hand over
  `mdrive.sbs/mdisk/<id>` instead of hubcloud anchors, and the shared archive rule
  now covers `/mdisk/` as well as `/archive/`. Finding that also exposed a branch of
  the link extractor that had been dead code since it was written — it required two
  URL schemes in one URL, so it could never match.
- **MovieBox is no longer verified**: the visitor API answers *every* subject with
  one 23-second advert (the same macdn file for Dune and One Piece, for episode 1 and
  episode 4). Sources reporting under 45 seconds are now skipped, and the add-on
  carries a dated Unavailable reason instead of a green badge.
- **A series opened from another add-on now resolves.** A subject that is not one of
  a site's own pages is resolved through the site's search, and the pick follows the
  request's shape — the kind is read from the path (`/series/`, `/movie/`) because a
  title rarely says. Cross-provider blindness fell from 10 of 17 to 0 of 19
  unexplained (GokuHD and ExtraFlix are catalogue-only by design).
- **4KHDHub** falls back to walking a season post itself when the season has no
  episode listing ("Complete All Episodes"), instead of returning nothing.

### Checks
- **Placeholder detection**: the self-test and the in-app diagnostics ask a second,
  differently titled subject and fail the stage when both return the same file.
- Three new live passes: `foreign_subject_live_test`, `episode_respect_live_test`
  (episode-keyed add-ons must answer per episode) and `coverage_live_test` (three
  popular titles must resolve from at least 8 of 19 add-ons).
- The cloud/local split is now explicit: a GitHub runner resolves 11 of 20 where a
  residential connection resolves all, so `ipSensitive` drives an "IP-sensitive —
  re-check from a residential connection" note instead of a red badge.
- **TV size**: the flask-icon self-test dialog is pinned at 1920×1080 — every stage
  row, the dated reason for an Unavailable add-on, and D-pad focus.

---

## [2.0.0] - 2026-11-20

Major release: the design system becomes one bevel scale with app-wide accents,
posters load through a serialised queue so TV hardware no longer hangs, and the
provider layer gains a Vega parity wave with two new stream resolvers.

### Design & Theme
- **One bevel scale everywhere**: `AdaptiveBevelBorder` derives the cut from the
  widget size (8 %, clamped 3–10 px) instead of fixed corner radii, so cards,
  dialogs, chips and pills share the same subtle chamfer in the Cut style.
- **Custom toggles** (`AppToggleTrack` / `AppToggle`) replace Material switches on
  TV: a pill track with a chamfered thumb that follows the corner style.
- **Accent colour picker**: the active accent can now be the primary, secondary,
  VIP or live colour, applied to the rail, buttons, chips, toggles and dialogs
  and persisted across restarts.
- **Uniform strokes**: `AppStroke.border` (1.0) for every card/row/chip border and
  `AppStroke.focus` (2.5) for focus rings, enforced by `scripts/normalize_border_widths.py`.
- New audits: `scripts/detect_shape_bypasses.py` and `scripts/detect_hardcoded_styles.py`
  keep widget styling on the token APIs.

### Home & TV
- Home cards use the smaller bevel, and Continue Watching play/watched/remove
  badges are shape-aware instead of circles or diamonds.
- Hero carousel: **LEFT now walks to the previous title** as well as RIGHT to the next.
- Full Details & Synopsis: close button removed (Back closes), the panel owns
  Up/Down scrolling, and it lists **grouped crew** (Director, Writer, Producer,
  Music, Cinematography, Editor) alongside the full cast.
- Provider selection: a compact **two-column grid**, no close (X) button, and
  merged provider/description/badge cards.

### Media loading
- New `ImageLoadGate` + `QueuedCachedNetworkImage`: network posters decode **one
  at a time**, and the next starts only after the previous paints a frame. An 8 s
  watchdog and dispose handling prevent a skipped widget from stalling the queue,
  which previously left shelves blank or hung the TV.

### Providers
- **Seven Vega ports**: CineFreak, CinemaLuxe, EonMovies, TopMovies, ZeeFliz,
  ExtraFlix, MultiMovies — each with a built-in manifest, store entry, icon,
  Pages docs and parser tests.
- New resolvers: **Cineverse/Modiplay** embeds → HLS relay, zee-dl embed
  redirects, LinkHub mirror hops, and JSON search proxies
  (`hits[].document`), plus a page-one catalog template for sites without
  `/page/1/`.

### Settings & Diagnostics
- Diagnostics pairs the Logging row with View Captured Log; the Logging row shows
  the live level and count and stays D-Pad focusable.
- Features dialog: tab strip wraps instead of overflowing, search is reachable but
  does not steal focus, and it renders inside the TV popup scope.
- Stream URL was renamed to Stream in the sidebar, and Downloads left the rail.
## [1.0.2] - 2026-11-19

Patch release: profile and settings cleanup, scan-to-connect for the web
remote, and corner-geometry fixes across dialogs.

### Web Companion TV Remote
- **Scan-to-connect QR code** beside the remote URL, so a phone opens the
  companion without typing an IP. The QR is rendered in-app (no external
  service) and only appears while the server is running.

### Profiles
- **One Edit Profile action** replaces the duplicate Manage toggle, the footer
  Manage Profiles button and the TV close button; Back closes the dialog.
- Profile and Add Profile cards share the same size and are centred, and the
  cards are shorter now that Edit moved out of the card.
- The editor is a **two-column layout** on TV (name + avatar grid | accent,
  kids, PIN, actions) with no scrolling.
- Avatar rings, picker rings, accent swatches and badges stay round under the
  Cut (bevel) corner style instead of becoming diamonds.

### Settings
- **Value chips and chevrons are right-aligned** in every settings card; long
  values ellipsize instead of pulling the arrow inwards.
- Diagnostics: the **Logging** row now shows a chevron and its level updates
  live after the dialog closes, and the row is selectable on TV (verified on
  device: focus, open, change level, View Log).

### Theme
- New **corner-style audit** (`scripts/detect_shape_bypasses.py`) that reports
  UI bypassing the theme's rounded / sharp / cut geometry.
- The Web Companion TV Remote dialog now draws with the active corner style, so
  under Cut its frame, status card, QR panel, instructions and buttons are
  bevelled with complete borders.

---

## [1.0.0] - 2026-10-22

First major release: the app now ships its own network bypass, a real player
decoder choice, a proper downloads page, and installable native providers.

### Network (new)
- **Cloudflare WARP over WireGuard**: device registration, key generation, tunnel
  lifecycle and status, with the mandatory VPN consent prompt. Shipped in both
  flavours; needs a Play Console VPN declaration.
- **AntiDPI**: loopback HTTP proxy that fragments the TLS handshake to defeat
  deep packet inspection. Three fragmentation profiles. No VPN permission.
- **DNS over HTTPS**: RFC 8484 wire-format resolver (Cloudflare, Google, AdGuard,
  Custom, Off) with TTL-aware caching, used by the anti-DPI proxy.

### Playback
- **Selectable video decoder**: Auto / Hardware / Software, persisted and applied
  when the player is created.
- Player popups apply instantly; the Apply buttons are gone.
- Controls ease out and honour the system reduce-motion setting.

### Library & browsing
- **Downloads page** showing the show/movie, episode, quality and the actual file
  on disk, with progress, speed, ETA, and Watch / Pause / Cancel / Retry / Delete.
- **Floating bottom navigation bar** that scales labels instead of clipping them.
- **Detail page**: larger posters (w780 decode), heavier title treatment, and a
  See All for "More Like This".
- **Home shelves de-duplicate** titles across rows.

### Providers
- **Provider self-test**: staged Catalog / Search / Metadata / Streams checks with
  persisted verdicts and live progress.
- **Four native providers** (HDHub4u, MoviesMod, UHDMovies, MoviesDrive) on a
  shared extractor layer. Installable, never enabled by default, domains resolved
  dynamically.
- P2P engine gated to the `github` flavour for Play policy compliance.

### Settings
- Logging levels with a viewer and copy-all, backed by intercepting `debugPrint`.
- Erase all local data with honest partial-failure reporting.
- Full preferences list; network bypass restored at startup.

---
## [0.10.0] - 2026-10-04

### 🎙️ Search & Voice
- **Smart Voice Search & Speech-to-Text Dictation**: Triple-ring animated pulsing waveform overlay with real-time speech input (`speech_to_text`), quick keyword chips, manual search fallback, and full Android TV D-Pad remote accessibility (`VoiceSearchDialog`).

### 🎬 Playback & Cinematic Experience
- **Smart Intro & Outro ("Skip Intro") Auto-Detector**: Intelligent fallback heuristic intro interval detector (15s–90s) for TV episodes without provider skip markers. Smooth floating focusable skip overlay with smooth fade animations.
- **Audio Equalizer & Dynamic Volume Normalizer**: 5 hardware-accelerated MPV audio filtering profiles (`dynaudnorm`, Dialog Clarity Boost at 2.5 kHz, Bass Boost, Late Night Whisper, Flat/Neutral) and dynamic 100%–200% volume pre-amplification.
- **Background Audio-Only Mode & Ambient Screen Saver**: Energy and bandwidth-saving audio-only playback mode with dimmed breathing poster artwork and 1-click / D-Pad "Restore Video" button.
- **Picture Quality Tuner**: Real-time hardware MPV video tuning for Brightness, Contrast, Saturation, Gamma, and Hue with one-click reset.
- **Sleep Timer & Auto-Shutdown**: Configurable sleep timers (15m, 30m, 45m, 60m, End of Episode) with real-time countdown badge.
- **Binge Mode Auto-Play & Next Episode Card**: Interactive countdown card for effortless sequential episode streaming.

### 🌐 Social & Multi-Device Sync
- **Watch Together (Virtual Watch Party / LAN Sync)**: UDP broadcast sync engine (port 8769) allowing local devices to synchronize playback states, play/pause commands, and seeks within $\pm 1500\text{ ms}$ drift tolerance with 4-digit PIN security.
- **Multi-Device LAN Library Sync**: Real-time cross-device LAN synchronization of watch history, bookmarks, and custom playlists without external cloud dependencies.
- **Local Web Remote Control**: Embedded lightweight HTTP server on port 8088 rendering an interactive TV remote web app for smartphones connected to the local Wi-Fi.

### 📊 Insights & Discovery
- **Viewing Habits & Streaming Analytics**: Offline-first private streaming stats calculating total watch time, completed titles, viewing streaks, hourly/daily activity heatmaps, and genre distribution progress bars.
- **Deep Discover & Recommendation Engine**: Interactive mood, tempo, decade, and multi-genre discovery filters for surfacing hidden gems across streaming providers.
- **Movie Collections & Franchises**: Dedicated franchise shelves grouping cinematic universes (MCU, Harry Potter, etc.) with release order sorting and aggregate progress tracking.
- **Actor & Director Filmography Explorer**: Comprehensive biography, birth/death info, awards, and complete filmography carousels (`PersonDetailsScreen`).

### 👥 Profiles, Subtitles & Storage
- **Multi-User Profiles**: Custom avatars, kids-safe parental mode, independent watch history, and pin-protected user profiles.
- **Advanced Subtitle Styling**: Real-time customizable font size, text colors, background opacity, outline/stroke width, and subtitle vertical positioning.
- **Storage & Cache Management Dashboard**: Dedicated analyzer for cached video chunks, poster thumbnails, and temporary stream segments with selective cache clearance.
- **Comprehensive Backup & Restore**: Full JSON snapshot backup and restore of watch history, bookmarks, and app settings.

---

## [0.9.1] - 2026-09-24
- Added download server selection.
- Fixed thumbnail self-healing and image caching fallbacks.
- UI refinements and TV D-Pad focus stability.

## [0.9.0] - 2026-09-23
- Queued download manager with background isolate streaming.
- Fuzzy title search engine with typo tolerance.
- Community dynamic provider architecture (VidSrc & IPTV support).
- Google Play Store compliance hardening & pre-play stream selection modal.
