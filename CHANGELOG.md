# Changelog

All notable changes to the **Exalere** media streaming project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
