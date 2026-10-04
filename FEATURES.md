# 🌟 Exalere Feature Directory & Capabilities Guide

Exalere is a modern, high-performance, cross-platform media streaming and entertainment client built with Flutter, libmpv, and a modular plugin architecture. It delivers a cinematic experience across **Android Mobile & Tablet**, **Android TV / Fire TV**, and **Windows Desktop**.

Below is the comprehensive catalog of all features and capabilities built into Exalere.

---

## 🎬 1. Video Playback & Streaming Engine
1. **Multi-Source Streaming Engine**: Aggregates and resolves streams across MovieBox, 4KHDHub, Stremio addons, P2P/Torrentio, and community plugins.
2. **libmpv Hardware-Accelerated Playback**: Powered by `media_kit` utilizing native GPU hardware decoding (MediaCodec on Android, D3D11VA on Windows).
3. **External Player Handoff**: One-tap fallback to launch external video players (VLC, Just Player, MX Player, MPV) with intent forwarding.
4. **Adaptive Playback Buffer & Preload**: Configurable network demuxer cache (`Low-Latency`, `Balanced`, `High-Bandwidth / 4K Preload`) for buffering-free playback on slow Wi-Fi.
5. **Timeline Buffered Bar**: Dual-layer seek bar visually showing both current position and demuxer-cached ahead buffer.
6. **Variable Playback Speed & Pitch Correction**: Seamless playback speed control (`0.5x`, `0.75x`, `1.0x`, `1.25x`, `1.5x`, `2.0x`) with libmpv audio pitch compensation.
7. **Dialogue Clarity & Night Mode (DRC)**: Dynamic Range Compression boosting low whispers and dialogues while dampening deafening sound effects and explosions.
8. **Volume Boost (Up to 200%)**: Gain amplification above 100% for quiet movie releases and quiet TV hardware speakers.
9. **In-Player Sleep Timer**: Scheduled playback countdown timer (`15m`, `30m`, `45m`, `60m`, `90m`, or `End of Media`) with automatic pause.
10. **Aspect Ratio Switching**: Seamless aspect ratio toggle (Fit, Cover, Fill, 16:9, 4:3, 21:9 anamorphic stretch) directly within the overlay.
11. **Picture-in-Picture (PiP) & Background Playback**: Native Android PiP windowing and optional audio-only background continuation when exiting the app.
12. **Stats for Nerds (Tech Inspector HUD)**: Real-time semi-transparent stream HUD displaying active resolution, framerate, video/audio codecs, bitrate, dropped frames, cache depth, and hardware decoder status.

---

## 📺 2. 10-Foot Leanback Android TV & Ergonomic Navigation
13. **Strict D-Pad Spatial Navigation**: Every screen, card, dialog, chip, and slider is optimized for 5-way D-Pad remotes (Up, Down, Left, Right, Select/Enter, Back).
14. **TvFocusable Design Language**: Interactive scale animations (1.06x focus magnification), glowing focus rings, and sound feedback.
15. **Smart TV Sidebar Navigation**: Collapsible Leanback sidebar with focus restoration and quick section jumping.
16. **TvSpatialNavigation Multi-Directional Traversal**: Focus engine preventing dead-ends, trapping, and scale-animation clipping on horizontal rows.
17. **Smart Remote Back-Key Handling**: First back-press reveals or unwinds controls; second back-press prompts a sleek exit dialog without jarring app termination.
18. **TV Remote D-Pad Seek Acceleration**: Smart scrub increments (10s, 30s, 1m, 5m) on continuous remote arrow holds.

---

## 💬 3. Subtitles & Audio Architecture
19. **Real-Time Subtitle Style Customizer**: In-player customization of font size (`14px`–`32px`), color presets (`White`, `Yellow`, `Cyan`, `Green`), background opacity shield, and drop shadows.
20. **Synchronized MPV & Flutter Subtitles**: Dual-mode rendering with live MPV ASS option sync and high-contrast Flutter overlays.
21. **Subtitle Timing Offset Sync**: Manual delay calibration (`-10.0s` to `+10.0s` in 0.1s increments) to fix out-of-sync audio/subtitle tracks.
22. **Multi-Track Audio & Language Switcher**: Fast track selector between original tracks, regional dubs (Hindi, Tamil, Telugu, etc.), and multi-channel 5.1/7.1 audio.
23. **Community & External Subtitle Loader**: Automatic parsing and download of VTT and SRT subtitle tracks from stream providers.

---

## 🍿 4. Binge-Watching & Smart Skipping
24. **Next Episode Countdown Card**: Floating interactive next-episode toast appearing in the final 30 seconds of an episode with 10-second auto-play countdown.
25. **Smart Episode Sequencer**: Auto-navigates across seasons (e.g. S01E10 ➔ S02E01) without returning to catalog screens.
26. **Auto Skip Intro & Outro**: Automatic skip interval detection and one-click Skip Intro button.
27. **Quick Season & Episode Selector Drawer**: In-player episode sheet to switch episodes without stopping current playback.

---

## 👤 5. Multi-Profile System & Local LAN Sync
28. **Multi-Profile Viewer Management**: Create personalized viewer profiles (Adults, Kids, Family) with distinct avatar icons and color themes.
29. **Isolated Watch History & Favorites**: Watch history, resume timestamps, and favorites are strictly isolated per profile.
30. **Parental PIN Lock**: 4-digit numeric PIN protection on sensitive profiles; exiting a Kids Profile requires PIN authorization.
31. **Age-Appropriate Content Filtering**: Automatic filtering and masking of adult (18+) content when in Kids Profile mode.
32. **Local Wi-Fi / LAN Sync**: Zero-cloud peer-to-peer library synchronization across devices on the same local network using UDP discovery and local HTTP server.

---

## 💾 6. Backup, Restore & Offline Data Migration
33. **Complete Offline Backup Bundles**: Generate encrypted/structured JSON backups containing all profiles, favorites, watch history, and app preferences.
34. **Local File Exporter & Scanner**: Save backups to `Downloads/Exalere/Backups` (Android) or `Documents/Exalere/Backups` (Windows) and auto-detect existing backups.
35. **Quick Clipboard Migration**: Copy and restore entire backup bundles instantly via the system clipboard.
36. **Smart Restore Strategies**: Choice between **Merge** (unions existing libraries with incoming backup) and **Replace** (complete clean-slate restoration).

---

## 📥 7. Direct Streams & Offline Download Hub
37. **Direct Stream / M3U8 / MP4 Link Player**: Play and stream arbitrary direct video URLs, HLS playlists, DASH streams, or magnet hashes.
38. **Multi-Task Download Queue**: Background file download engine with concurrent stream chunking, pause/resume, and speed indicators.
39. **Dedicated Offline Downloads Hub**: Manage and play downloaded media files directly with progress tracking without an active internet connection.

---

## 📡 8. Live TV & Custom IPTV Integration
40. **Multi-Playlist M3U Management**: Add and organize multiple IPTV playlist URLs or local files with custom names.
41. **Live TV Channel Favorites**: Pin favorite channels to the top of the Live TV grid for instantaneous access.
42. **Country & Language Filtering**: Explore thousands of free global channels filtered by country flags and languages.
43. **In-Player Quick Channel Zapper**: Seamless channel switcher drawer during live TV playback.

---

## 🎨 9. Theming, Design Tokens & Personalization
44. **Dynamic Theme Engine**: Netflix Black, Midnight Slate, Cyberpunk Neon, OLED True Black, and more.
45. **Customizable Corner Geometry**: Choose between Sharp, Rounded, or Pill-shaped card styling.
46. **Morphism Styling**: Standard, Glassmorphic frosted glass, and Flat UI surface modes.
47. **UI Scale Multiplier**: Granular interface scaling (0.8x to 1.3x) optimized for large 4K TVs or compact phones.
48. **Dynamic System Font Selector**: Switch system typography between default, Inter, Roboto, Outfit, and monospace fonts.

---

## 🧩 10. Modular Universal Plugin System
49. **Stremio Addon Compatibility**: Supports standard Stremio v3 HTTP protocol addon manifests (`/manifest.json`, `/stream/{type}/{id}.json`).
50. **Community Plugin Store & Auto-Updater**: Browse and install verified community addons with a single tap.
51. **Zero Proprietary SDKs**: Built 100% on open-source protocols under PolyForm Noncommercial License 1.0.0.

---

## 🚀 11. Discovery, Playlists, Fine-Tuning & Voice
52. **Audio & Subtitle Sync Delay Fine-Tuning (Micro-Offset)**: Micro-delay offset steppers (±100ms, ±500ms, Reset) in player audio & subtitles sheet to eliminate lipsync drift and audio-lag over Bluetooth.
53. **Video Aspect Ratio & Zoom Fit (Letterbox Remover)**: 4-mode aspect ratio cycling (Original Fit, Zoom & Crop to eliminate letterbox black bars, 16:9 Stretch Fill, and Fit Width) with instant HUD toast feedback.
54. **Franchise Universes & Movie Collections Hub**: Chronologically ordered franchise collections (e.g., Marvel Cinematic Universe, Harry Potter, Star Wars) on Movie Details with instant streaming.
55. **Cast & Crew Filmography Deep-Dive (Actor Profiles)**: Interactive actor and director profile pages with biographical details, birth info, headshots, and categorized filmography shelves.
56. **Custom User Playlists & Curated Lists**: Profile-scoped custom watchlists and playlists with seamless add/remove dialogs, rename, delete, and direct playback.
57. **Voice Search for TV & Mobile (Speech-to-Text)**: Hands-free voice recognition with live speech-to-text transcription, pulsing microphone waveform, and D-Pad remote focus integration.

---

## 🌟 12. Advanced Video Tuning, Web Companion Remote & Smart Multitasking
58. **In-Player Video Picture Tuner (Brightness, Contrast, Saturation, Gamma)**: Real-time hardware video picture calibration directly inside playback via native libmpv properties, with quick presets (Standard, Cinema Warm, Vivid OLED, Shadow Boost for dark scenes, High Contrast) and precision stepper tuning (-5, Reset, +5).
59. **Web Companion TV Remote (Zero-Install Mobile Remote)**: Turn any smartphone into a responsive TV remote over local Wi-Fi with D-Pad trackpad, media controls, and direct phone keyboard typing into TV via embedded HTTP server and QR code / local link.
60. **Deep Catalog Discovery & Multi-Filter Engine**: Multi-criteria catalog exploration across media types (Movies, TV Shows), release eras/decades (Classics to 2020s), multi-genre selections, minimum TMDB ratings, and customizable sort orders in an adaptive TV grid.
61. **Rotten Tomatoes, Metacritic & Community Reviews Hub**: Multi-source score aggregation with Tomatometer and Metascore estimates, content certification advisories, and readable community reviews on Movie & TV details screens.
62. **Quick Switcher (Media Multitasker Overlay for TV & Desktop)**: Slide-out multitasking overlay providing instant Continue Watching resumption with progress indicators and one-tap teleports to Live TV, Discovery, Web Remote, and Settings.
63. **Storage Hygiene & Stream Cache Cleaner**: Storage breakdown in Settings with one-tap purge actions for stream buffer fragments, poster image caches, and watch history to maintain optimal performance on storage-constrained TV and mobile devices.

---

## 🎧 13. Acoustic Engineering, Watch Party, Ambient Audio & Streaming Insights
64. **Smart Voice Search & Dictation Overlay**: Interactive global modal with animated multi-ring audio sound level waveform, real-time transcription chips, quick curated suggestions, and fallback text dictation.
65. **Smart Intro & Outro ("Skip Intro") Auto-Detector**: Intelligent heuristic intro/credits detector with floating D-Pad focusable Skip pill, auto-skip intro preference, and seamless episode binge progression.
66. **Watch Together / Virtual Watch Party (LAN Sync)**: Synchronized playback across multiple devices on local Wi-Fi with host conductor controls, client drift compensation, and 4-digit PIN pairing.
67. **Audio Equalizer & Volume Normalizer (Dialog Boost & Night Mode)**: Hardware audio DSP with Dynamic Normalizer (`dynaudnorm`) for explosive dynamic range suppression, vocal dialog frequency enhancement (`equalizer=2.5kHz`), bass boost, and pre-amp volume scaling (100% to 200%).
68. **Background Audio-Only Mode & Ambient Screen Saver**: Stream concerts, podcasts, and music in low-power audio-only mode, turning off GPU video surfaces and rendering a dimmed cinematic ambient artwork carousel with breathing animation.
69. **Viewing Habits, Statistics & "Year in Review" Insights**: Private, offline-first personal streaming stats dashboard featuring total watch time, movies vs series breakdown, top genres distribution, and peak viewing habits.


